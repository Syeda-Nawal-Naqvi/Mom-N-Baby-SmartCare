import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_notification_service.dart';
import 'local_notification_service.dart';
import 'notification_sound_service.dart';

/// Admin-only, self-contained "new feedback" notifier.
///
/// WHY THIS EXISTS (read before touching it):
/// The old path was: a user submits feedback -> FeedbackService calls
/// AppNotificationService.sendToAdmins() -> that fans a `notifications`
/// doc out to every uid listed in the `admin_uids` directory, written
/// from the SUBMITTING USER'S device. That path only works if ALL of
/// the following are true at the exact moment feedback is submitted:
///   1. The Firestore rules for `admin_uids` (read) and `notifications`
///      (create) are actually PUBLISHED — edited in a local rules file
///      is not the same as clicking Publish in the Firebase Console (or
///      running `firebase deploy --only firestore:rules`).
///   2. The `admin_uids` collection already contains the admin's uid
///      (only written when an admin previously opened the dashboard
///      while their `users/{uid}.role` field was already exactly
///      'admin').
///   3. The submitting user's device gets a working, non-stale read of
///      that directory at that exact moment (Firestore's offline cache
///      can serve empty/stale results).
/// Any one of those being off anywhere makes admins silently never get
/// notified, while feedback still saves fine — which is exactly the
/// confusing "feedback shows up but no notification ever comes" bug
/// this app kept hitting, even after fixing each individual cause,
/// because there were multiple independent ways for the chain to break.
///
/// This mixin removes that entire dependency chain for the one thing
/// admins actually need reliably. Instead of trusting a write made by
/// someone else's device through a fragile multi-step path, the ADMIN'S
/// OWN app directly watches the `feedback` collection it already has
/// guaranteed read access to (Feedback Management proves this access
/// works), and creates its own notification + sound + tray entries
/// locally. It cannot be broken by `admin_uids` contents or by rules
/// publish timing, because it depends on neither.
///
/// Add `with AdminFeedbackWatcherMixin` to AdminDashboardScreen's State,
/// call `startWatchingFeedback()` in initState and
/// `stopWatchingFeedback()` in dispose — same pattern as the existing
/// NotificationWatcherMixin (which still handles feedback-reply and
/// admin-broadcast notifications; this mixin only covers "new feedback
/// arrived").
mixin AdminFeedbackWatcherMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _feedbackSub;
  bool _isFirstFeedbackSnapshot = true;

  void startWatchingFeedback() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _watchFrom(uid);
  }

  Future<void> _watchFrom(String uid) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // Resume from wherever this admin last left off (stored on their
    // own profile doc, which they can always read/write). Defaults to
    // the epoch so the very first time this runs, it catches up on
    // EVERY pending feedback that already exists (e.g. the 9 pending
    // items sitting unnotified from before this fix) — those are
    // treated as "backlog" (see _isFirstFeedbackSnapshot below): a
    // notification entry is created for each so they show up in Admin
    // Notifications, but sound/tray only fires for items that arrive
    // AFTER that first catch-up, so opening the dashboard doesn't set
    // off nine pop sounds at once.
    Timestamp since = Timestamp.fromMillisecondsSinceEpoch(0);
    try {
      final userDoc = await userDocRef.get();
      final stored = userDoc.data()?['lastFeedbackSyncAt'];
      if (stored is Timestamp) since = stored;
    } catch (e) {
      debugPrint(
          'AdminFeedbackWatcherMixin: could not read lastFeedbackSyncAt: $e');
    }

    // Single-field range + orderBy on the SAME field (createdAt) needs
    // no composite index — this is what avoids the "Could not load
    // feedback" / missing-index failure that a status+orderBy query
    // would hit.
    _feedbackSub = FirebaseFirestore.instance
        .collection('feedback')
        .where('createdAt', isGreaterThan: since)
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      final isBacklog = _isFirstFeedbackSnapshot;
      _isFirstFeedbackSnapshot = false;

      Timestamp? latest;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        if (createdAt is Timestamp &&
            (latest == null || createdAt.compareTo(latest) > 0)) {
          latest = createdAt;
        }
        await _ensureNotification(
          adminUid: uid,
          feedbackId: doc.id,
          data: data,
          alert: !isBacklog,
        );
      }

      if (latest != null) {
        try {
          await userDocRef
              .set({'lastFeedbackSyncAt': latest}, SetOptions(merge: true));
        } catch (e) {
          debugPrint(
              'AdminFeedbackWatcherMixin: could not save lastFeedbackSyncAt: $e');
        }
      }
    }, onError: (e) {
      debugPrint('AdminFeedbackWatcherMixin: feedback watch error: $e');
    });
  }

  /// Deterministic doc ID (`fb_<feedbackId>_<adminUid>`) so re-running
  /// this (e.g. two admins, or the same admin on two devices) never
  /// creates a duplicate notification for the same feedback item — a
  /// second `.set()` on an existing ID just re-writes the same doc.
  Future<void> _ensureNotification({
    required String adminUid,
    required String feedbackId,
    required Map<String, dynamic> data,
    required bool alert,
  }) async {
    final notifRef = FirebaseFirestore.instance
        .collection('notifications')
        .doc('fb_${feedbackId}_$adminUid');

    final message = (data['message'] ?? '').toString();
    final senderName =
        (data['userName'] ?? data['userEmail'] ?? 'A user').toString();
    // The uid of the user who submitted this feedback (if it's a normal,
    // signed-in submission — locked-out/anonymous help requests won't
    // have one). Recorded so this notification can be found and deleted
    // if that user's account is later removed (see NotificationModel's
    // `senderId` doc comment / AccountCleanupService.wipeAllUserData).
    final senderId = data['userId'] as String?;

    try {
      final existing = await notifRef.get();
      if (existing.exists) return; // already notified for this one
      await notifRef.set({
        'recipientId': adminUid,
        'title': '📝 New feedback received',
        'body': message,
        'type': 'feedback_submitted',
        'relatedId': feedbackId,
        'senderName': senderName,
        if (senderId != null) 'senderId': senderId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint(
          'AdminFeedbackWatcherMixin: could not write notification for $feedbackId: $e');
      return;
    }

    if (alert) {
      await NotificationSoundService().playPopIfEnabled();
      if (await AppNotificationService().isNotificationsEnabled()) {
        await LocalNotificationService().show(
          title: '📝 New feedback received',
          body: message,
        );
      }
    }
  }

  void stopWatchingFeedback() {
    _feedbackSub?.cancel();
  }
}
