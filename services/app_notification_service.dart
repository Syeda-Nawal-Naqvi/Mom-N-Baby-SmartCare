import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

/// In-app notification center, backed by Firestore.
///
/// Drives the in-app "Notifications" screen/bell icon for both users and
/// admin:
///   - Feedback reply notifications (admin replied to a user's feedback)
///   - New-feedback notifications (a user submitted feedback -> all admins)
///   - Admin broadcast messages (to one specific user, or to everyone)
///
/// There is no "reminder"/"alarm" concept in this app anymore — every
/// notification here comes either from a user action (submitting
/// feedback) or from an admin action (replying, or sending a message).
///
/// Includes:
///   - Retention policy: keep at most 10 read notifications; if there is
///     at least one unread notification, the whole list (read + unread)
///     is capped at 20 total. Older items beyond those limits are
///     auto-deleted. See [enforceRetention].
///   - Offline queue for notifications sent while offline (Firestore's
///     own offline persistence, enabled in firebase_service.dart, is what
///     lets an already-loaded notification list keep showing correctly
///     even with no network — nothing here needs a separate local
///     database).
///   - Proper admin notification targeting via the `admin_uids` directory
///     (see [sendToAdmins]) instead of querying `users` by role, which
///     regular users are not allowed to do per the Firestore rules.
class AppNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _adminUidsCol =>
      _firestore.collection('admin_uids');

  String? get _uid => _auth.currentUser?.uid;

  // ═════════════════════════════════════════════════════════════════════
  // NOTIFICATION SOUND/POP PREFERENCE
  // ═════════════════════════════════════════════════════════════════════
  //
  // Lives on the signed-in user's own `users/{uid}` doc as
  // `notificationsEnabled`, instead of shared_preferences. Firestore's
  // offline persistence (unlimited cache, enabled in firebase_service.dart)
  // already gives reads/writes here the same "instant, works offline"
  // feel local storage had — a write applies to the local cache
  // immediately and syncs to the server in the background — with the
  // added benefit that the preference now follows the account across
  // devices instead of being stuck on one phone. Used by both
  // SettingsScreen/AdminSettingsScreen (to show/toggle it) and
  // NotificationSoundService (to decide whether to play the pop sound).
  Future<bool> isNotificationsEnabled() async {
    final uid = _uid;
    if (uid == null) return true;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return (doc.data()?['notificationsEnabled'] as bool?) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'notificationsEnabled': enabled}, SetOptions(merge: true));
  }

  // ═════════════════════════════════════════════════════════════════════
  // RETENTION POLICY
  // ═════════════════════════════════════════════════════════════════════
  //
  // Rules (applied per signed-in user — or per-admin, since admins are
  // just another `recipientId` — over their own notifications), two
  // INDEPENDENT caps:
  //   1. READ notifications: keep at most [_maxReadNotifications] (20).
  //      Once a user's read notifications reach that count, the oldest
  //      read ones are auto-deleted to make room.
  //   2. UNREAD notifications: keep at most [_maxUnreadNotifications]
  //      (30). Oldest unread ones beyond that are auto-deleted too, so
  //      an inbox nobody ever opens still can't grow without bound.
  // The two lists are trimmed independently — reading through unread
  // notifications never affects the read cap and vice versa.
  //
  // Call this whenever the notification list is viewed/updated (already
  // wired into NotificationWatcherMixin and the notification screens).
  static const int _maxReadNotifications = 20;
  static const int _maxUnreadNotifications = 30;

  /// Deletes whatever falls outside the retention window described above
  /// for the current signed-in user. Safe to call often — it's a no-op
  /// once the list is already within limits.
  Future<void> enforceRetention() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await _col.where('recipientId', isEqualTo: uid).get();
      if (snap.docs.isEmpty) return;

      DateTime resolve(dynamic value) =>
          value is Timestamp ? value.toDate() : DateTime.now();

      final docs = snap.docs.toList()
        ..sort((a, b) => resolve(b.data()['createdAt'])
            .compareTo(resolve(a.data()['createdAt']))); // newest first

      final unread = docs.where((d) => d.data()['read'] != true).toList();
      final read = docs.where((d) => d.data()['read'] == true).toList();

      final keepUnread = unread.length > _maxUnreadNotifications
          ? unread.sublist(0, _maxUnreadNotifications)
          : unread;
      final keepRead = read.length > _maxReadNotifications
          ? read.sublist(0, _maxReadNotifications)
          : read;

      final keepIds = <String>{
        ...keepUnread.map((d) => d.id),
        ...keepRead.map((d) => d.id),
      };
      final toDelete =
          docs.where((d) => !keepIds.contains(d.id)).map((d) => d.reference);

      if (toDelete.isEmpty) return;
      final batch = _firestore.batch();
      for (final ref in toDelete) {
        batch.delete(ref);
      }
      await batch.commit();
      debugPrint('AppNotificationService: retention cleanup applied');
    } catch (e) {
      debugPrint('AppNotificationService: enforceRetention error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // SEND
  // ═════════════════════════════════════════════════════════════════════

  /// Sends a notification to a single user.
  /// If offline, the notification will be created when connectivity returns
  /// (Firestore's built-in offline persistence handles this automatically).
  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    String? senderName,
  }) async {
    final data = <String, dynamic>{
      ...NotificationModel(
        recipientId: userId,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        senderName: senderName,
      ).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Check connectivity - if offline, save locally and queue
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    final online = !result.contains(ConnectivityResult.none);

    if (online) {
      try {
        await _col.add(data);
      } catch (e) {
        debugPrint('AppNotificationService: send failed: $e');
        await _queueOfflineNotification(data);
      }
    } else {
      await _queueOfflineNotification(data);
    }
  }

  /// Sends the same notification to every admin, discovered via the
  /// small, publicly-readable `admin_uids` directory (see
  /// `AdminService.ensureAdminDirectoryEntry`) rather than querying the
  /// `users` collection by role — regular users' Firestore rules don't
  /// allow reading other users' documents, so that query would always
  /// fail with permission-denied for a non-admin caller (e.g. a user
  /// submitting feedback).
  Future<void> sendToAdmins({
    required String title,
    required String body,
    required String type,
    String? relatedId,
    String? senderName,
  }) async {
    // NOTE: deliberately no try/catch here — feedback_service.dart's
    // submitFeedback() wraps this call and surfaces the real failure
    // reason to the person, instead of it being silently swallowed
    // (which is what made this bug invisible before: feedback saved
    // fine, but no one could tell admins were never notified, or why).
    //
    // FIX 1: read `admin_uids` straight from the SERVER, not the local
    // offline cache. This app enables unlimited Firestore offline
    // persistence (see firebase_service.dart) — a plain `.get()` can be
    // silently answered from a stale/empty local cache (e.g. right
    // after install, or if this device has never happened to sync that
    // small collection yet), which made `adminSnap.docs` come back
    // empty even though `admin_uids` genuinely has admins on the
    // server. If the device is truly offline, fall back to the cache
    // so this still degrades instead of crashing.
    QuerySnapshot<Map<String, dynamic>> adminSnap;
    try {
      adminSnap =
          await _adminUidsCol.get(const GetOptions(source: Source.server));
    } catch (e) {
      debugPrint(
          'AppNotificationService: server read of admin_uids failed ($e), falling back to cache');
      adminSnap = await _adminUidsCol.get();
    }

    if (adminSnap.docs.isEmpty) {
      // FIX 2: this used to just debugPrint and silently return, which
      // is exactly why the failure was invisible — feedback still
      // "succeeded", nothing on screen ever told anyone that zero
      // admins were notified. Throwing here lets the caller
      // (FeedbackService.submitFeedback) surface the real reason to
      // the person via a snackbar, so the actual root cause (an empty
      // `admin_uids` directory) is now visible instead of silently
      // swallowed.
      throw StateError(
          'admin_uids directory is empty — no admin account has been '
          'registered as a notification recipient yet. Open the Admin '
          'Panel once on the admin account (it self-heals this on load), '
          'then try again.');
    }
    final batch = _firestore.batch();
    for (final doc in adminSnap.docs) {
      final ref = _col.doc();
      final data = <String, dynamic>{
        ...NotificationModel(
          recipientId: doc.id,
          title: title,
          body: body,
          type: type,
          relatedId: relatedId,
          senderName: senderName,
        ).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      batch.set(ref, data);
    }
    await batch.commit();
  }

  /// Queue a notification to be sent when connectivity returns.
  Future<void> _queueOfflineNotification(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('_pending_notifications').add({
        ...data,
        '_queuedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AppNotificationService: failed to queue notification: $e');
    }
  }

  /// Flush queued notifications from offline period.
  /// Call this when connectivity returns.
  Future<void> flushPendingNotifications() async {
    try {
      final pendingSnap =
          await _firestore.collection('_pending_notifications').get();

      if (pendingSnap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in pendingSnap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data.remove('_queuedAt');
        final newRef = _col.doc();
        batch.set(newRef, data);
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('AppNotificationService: flush error: $e');
    }
  }

  /// Sends the same message to every non-blocked user (fan-out).
  Future<int> sendToAllUsers({
    required String title,
    required String body,
    String? senderName,
  }) async {
    final usersSnap = await _firestore
        .collection('users')
        .where('blocked', isEqualTo: false)
        .get();

    if (usersSnap.docs.isEmpty) return 0;

    const chunkSize = 450;
    int sent = 0;
    for (var i = 0; i < usersSnap.docs.length; i += chunkSize) {
      final chunk = usersSnap.docs.skip(i).take(chunkSize);
      final batch = _firestore.batch();
      for (final userDoc in chunk) {
        final ref = _col.doc();
        batch.set(ref, {
          ...NotificationModel(
            recipientId: userDoc.id,
            title: title,
            body: body,
            type: 'admin_message',
            senderName: senderName ?? 'Admin',
          ).toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        sent++;
      }
      await batch.commit();
    }
    return sent;
  }

  // ═════════════════════════════════════════════════════════════════════
  // READ (for the current signed-in user)
  // ═════════════════════════════════════════════════════════════════════

  /// Streams every notification addressed to the current user.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyNotifications() {
    if (_uid == null) return const Stream.empty();
    return _col.where('recipientId', isEqualTo: _uid).snapshots();
  }

  Stream<int> streamUnreadCount() {
    if (_uid == null) return Stream.value(0);
    return _col
        .where('recipientId', isEqualTo: _uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    await _col.doc(notificationId).update({'read': true});
  }

  /// One-shot check (NOT a stream): does the signed-in user currently
  /// have at least one unread notification? Used right after
  /// login/auto-login (splash_screen.dart, login_screen.dart,
  /// register_screen.dart) to play a single "you have something
  /// waiting" pop sound — deliberately independent of
  /// NotificationWatcherMixin's stream-based first-snapshot logic,
  /// which depends on a screen having already mounted and subscribed;
  /// this runs once, synchronously with the login flow, so it can't be
  /// missed by a timing race between navigation and mixin setup.
  /// Reads from the server when possible so a just-arrived notification
  /// (e.g. one AdminFeedbackWatcherMixin wrote a moment ago) isn't
  /// missed by a stale offline cache; falls back to cache if offline.
  Future<bool> hasUnreadNotifications() async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final snap = await _col
          .where('recipientId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint(
          'AppNotificationService: hasUnreadNotifications server read failed ($e), falling back to cache');
      try {
        final snap = await _col
            .where('recipientId', isEqualTo: uid)
            .where('read', isEqualTo: false)
            .limit(1)
            .get();
        return snap.docs.isNotEmpty;
      } catch (e2) {
        debugPrint(
            'AppNotificationService: hasUnreadNotifications failed: $e2');
        return false;
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (_uid == null) return;
    final snap = await _col
        .where('recipientId', isEqualTo: _uid)
        .where('read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _col.doc(notificationId).delete();
  }
}
