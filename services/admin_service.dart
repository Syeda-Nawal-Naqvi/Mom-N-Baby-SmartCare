import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'account_cleanup_service.dart';
import 'app_notification_service.dart';

/// Everything the admin panel needs for user management and analytics.
///
/// IMPORTANT REAL-WORLD LIMITATION (not a bug — a Firebase platform rule):
/// the client-side Firebase SDK can only delete the *currently signed-in*
/// user's own Auth account (`FirebaseAuth.instance.currentUser.delete()`).
/// There is no client-side API for an admin to delete *another* user's
/// Firebase Auth account — that requires the Firebase Admin SDK running in
/// a trusted backend (e.g. a Cloud Function). So "Delete Account" in the
/// admin's User Management screen removes the user's Firestore profile and
/// permanently blocks their login (`blocked: true`, which your existing
/// AuthService.login() already checks and rejects) — functionally a full
/// account removal from the user's perspective — but does not delete the
/// underlying Auth record. If you later add a Cloud Function for this,
/// call it from `deleteUserAccount` below instead of just blocking.
///
/// IMPORTANT DATA-MODEL NOTE: baby profiles and mother profiles are stored
/// under `users/{uid}/{collectionName}` (see `FirestoreService.collection()`),
/// NOT in a top-level `babies`/`mother_profile` collection. So every
/// admin-side read of those record types uses `collectionGroup()`, which
/// searches that subcollection name across every user, instead of
/// `collection()`, which would only ever look at a top-level collection
/// nobody actually writes to.
///
/// NOTE ON COUNTS ("wrong count" / "doesn't update on refresh"): every
/// analytics read below explicitly requests `GetOptions(source: Source.server)`.
/// Without that, `.get()` can silently answer from Firestore's local
/// offline cache (this app enables unlimited offline persistence in
/// firebase_service.dart), which is what made counts look frozen/stale
/// after pull-to-refresh even though the data on the server had changed.
/// If the device is actually offline, the server read throws and we
/// transparently fall back to the cache so the screen still shows
/// *something* instead of crashing.
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppNotificationService _notifications = AppNotificationService();

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _adminUidsCol =>
      _firestore.collection('admin_uids');

  // Subcollection names as actually written by FirestoreService callers:
  //   - BabyListScreen       -> FirestoreService.stream/add('babies')
  //   - MotherProfileService -> FirestoreService.collection('mother_profile')
  // Change these two constants if your app ever renames a collection.
  static const String _babiesSubcollection = 'babies';
  static const String _motherProfileSubcollection = 'mother_profile';

  // Recognised app roles. Anything else in the `role` field is bucketed
  // under "other" so a stray/typo'd value never silently disappears from
  // the totals.
  static const List<String> knownRoles = [
    'mother',
    'father',
    'caretaker',
    'admin',
  ];

  String? get currentUid => _auth.currentUser?.uid;

  /// Canonicalises a raw `role` field value. Handles the one known legacy
  /// value written by an older, buggy build of `profile_screen.dart`
  /// (`'father/husband'`, when every other part of the app — registration,
  /// this admin panel — always used bare `'father'`). Any already-affected
  /// accounts in the database still display and count correctly here,
  /// without needing a manual Firestore data migration.
  static String normalizeRole(dynamic rawRole) {
    final role = (rawRole ?? 'mother').toString();
    if (role == 'father/husband') return 'father';
    return role;
  }

  /// Always tries the server first (see class doc comment above); falls
  /// back to whatever's cached if the device is offline, instead of
  /// throwing and breaking the whole analytics screen.
  Future<QuerySnapshot<Map<String, dynamic>>> _freshGet(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query.get(const GetOptions(source: Source.server));
    } catch (_) {
      return await query.get(const GetOptions(source: Source.cache));
    }
  }

  // ── USER LIST / STREAMS ──────────────────────────────────────────────────
  //
  // IMPORTANT: neither of these queries uses Firestore's `.orderBy()`
  // anymore. `orderBy('createdAt')` doesn't just sort by that field — it
  // SILENTLY EXCLUDES any document that doesn't have the field set at all
  // (e.g. a doc added by hand in the Firebase console while testing, or
  // written by an old app build before `createdAt` existed). That was
  // exactly the "ghost account" bug: `getAnalytics()`/`_tally()` uses a
  // plain `.get()` with no ordering, so it correctly counted every
  // `users/{uid}` doc (e.g. showing "Mother Accounts: 1"), while this
  // "Manage Users" stream quietly dropped that same doc from the visible
  // list ("No users found" under the Mothers tab) — so the admin could see
  // a count but never actually find, inspect, or delete the account behind
  // it. Sorting is now done client-side in the UI (see
  // `admin_users_screen.dart`), which never drops a document.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllUsers() {
    return _usersCol.snapshots();
  }

  /// Live stream of users filtered to one role (mother/father/caretaker/
  /// admin) — powers the "who are my fathers/mothers/caretakers" list.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUsersByRole(String role) {
    return _usersCol.where('role', isEqualTo: role).snapshots();
  }

  // ── MOTHER / BABY PROFILES ───────────────────────────────────────────────
  //
  // Both use collectionGroup() so every user's babies/mother-profile show
  // up, not just documents sitting in a top-level collection that nothing
  // actually writes to.
  //
  // ORPHAN-SAFE: each emission is cross-checked against the live set of
  // `users/{uid}` doc ids and any record whose parent user no longer
  // exists is filtered out before reaching the UI. This is what makes
  // already-orphaned data (left behind by the old, non-cascading delete
  // flow) disappear from these lists and their counts immediately, even
  // before the one-time `cleanupOrphans()` sweep has been run to actually
  // delete those leftover documents from the database.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _orphanSafeCollectionGroupStream(String subcollection) {
    return _firestore
        .collectionGroup(subcollection)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) {
        return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      }
      Set<String> validUids;
      try {
        final usersSnap =
            await _usersCol.get(const GetOptions(source: Source.server));
        validUids = usersSnap.docs.map((d) => d.id).toSet();
      } catch (_) {
        // Offline / server unreachable — fall back to showing everything
        // rather than hiding real data because we couldn't verify it.
        return snap.docs;
      }
      return snap.docs.where((d) {
        final parentUid = d.reference.parent.parent?.id;
        return parentUid != null && validUids.contains(parentUid);
      }).toList();
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamAllMothers() =>
          _orphanSafeCollectionGroupStream(_motherProfileSubcollection);

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamAllBabies() =>
      _orphanSafeCollectionGroupStream(_babiesSubcollection);

  /// Deletes a mother-profile document. Pass the document's own
  /// [DocumentReference] (e.g. `doc.reference` from a collectionGroup
  /// snapshot) rather than a bare id — since the real document lives at
  /// `users/{uid}/mother_profile/{docId}`, a bare id alone isn't enough to
  /// locate it.
  Future<void> deleteMotherProfile(DocumentReference ref) async {
    await ref.delete();
  }

  /// Deletes a baby-profile document. Pass the document's own
  /// [DocumentReference] (e.g. `doc.reference` from a collectionGroup
  /// snapshot) rather than a bare id — the real document lives at
  /// `users/{uid}/babies/{docId}`, so a bare id alone isn't enough to
  /// locate it. Mirrors [deleteMotherProfile]. Firestore rules already
  /// allow this (`allow read, delete: if isKnownUserSubcollection(...)
  /// && isAdmin();`), so no rules change is needed — this was a
  /// product-decision gate on the Dart side only, now lifted per request:
  /// admin may delete any child (baby) profile, same as a mother profile.
  ///
  /// NOTE: this only removes the baby's own profile document. It does
  /// NOT touch that baby's related records (weight, vaccination,
  /// milestone, allergy, medical-history entries), which are stored
  /// separately and keyed by the PARENT user's uid, not the baby's doc
  /// id — this app's data model doesn't currently link those trackers to
  /// a specific baby id in a way that allows a targeted cascade delete
  /// from here. Deleting the parent's whole account (deleteUserAccount)
  /// remains the way to remove a family's data entirely.
  Future<void> deleteBabyProfile(DocumentReference ref) async {
    await ref.delete();
  }

  // ── ANALYTICS ────────────────────────────────────────────────────────────

  /// A value notifier that stays updated with live analytics.
  /// Listeners (admin dashboard) can use this to display live counts.
  /// Updates automatically whenever any relevant data changes.
  final ValueNotifier<Map<String, int>> liveAnalytics =
      ValueNotifier<Map<String, int>>({
    'totalUsers': 0,
    'admins': 0,
    'mothers': 0,
    'fathers': 0,
    'caretakers': 0,
    'blockedUsers': 0,
    'activeUsers': 0,
    'totalFeedback': 0,
    'pendingFeedback': 0,
    'totalMothers': 0,
    'totalBabies': 0,
    'unreadAdminNotifications': 0,
  });

  StreamSubscription? _usersSub;
  StreamSubscription? _feedbackSub;
  StreamSubscription? _mothersSub;
  StreamSubscription? _babiesSub;
  StreamSubscription? _adminNotifsSub;
  bool _analyticsStarted = false;
  Timer? _analyticsDebounce;

  /// Start streaming live analytics. Call once when admin dashboard loads.
  /// Every subscription below only triggers a recompute — it never reads
  /// snapshot data directly — so the actual numbers always come from the
  /// forced-fresh-from-server read in [_computeLiveAnalytics].
  void startLiveAnalytics() {
    if (_analyticsStarted) return;
    _analyticsStarted = true;

    void refresh() {
      _analyticsDebounce?.cancel();
      _analyticsDebounce = Timer(const Duration(milliseconds: 300), () {
        _computeLiveAnalytics();
      });
    }

    _usersSub = _usersCol.snapshots().listen((_) => refresh());
    _feedbackSub =
        _firestore.collection('feedback').snapshots().listen((_) => refresh());
    _mothersSub = _firestore
        .collectionGroup(_motherProfileSubcollection)
        .snapshots()
        .listen((_) => refresh());
    _babiesSub = _firestore
        .collectionGroup(_babiesSubcollection)
        .snapshots()
        .listen((_) => refresh());
    final myUid = currentUid;
    if (myUid != null) {
      _adminNotifsSub = _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: myUid)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((_) => refresh());
    }

    // Initial fetch
    _computeLiveAnalytics();
  }

  /// Stop live analytics streams. Call when admin dashboard is disposed.
  void stopLiveAnalytics() {
    _usersSub?.cancel();
    _feedbackSub?.cancel();
    _mothersSub?.cancel();
    _babiesSub?.cancel();
    _adminNotifsSub?.cancel();
    _analyticsDebounce?.cancel();
    _analyticsStarted = false;
  }

  Map<String, int> _tally(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> feedbackDocs,
    int mothersProfileCount,
    int babiesCount,
    int adminNotifCount,
  ) {
    int totalUsers = 0;
    int admins = 0;
    int mothers = 0;
    int fathers = 0;
    int caretakers = 0;
    int blocked = 0;

    for (final doc in userDocs) {
      final data = doc.data();
      totalUsers++;
      final role = normalizeRole(data['role']);
      switch (role) {
        case 'admin':
          admins++;
          break;
        case 'father':
          fathers++;
          break;
        case 'caretaker':
          caretakers++;
          break;
        default:
          // Anything unrecognised is still treated as a mother account
          // (this mirrors AuthService's own "default to mother" rule),
          // so totals always add up to totalUsers.
          mothers++;
      }
      if (data['blocked'] == true) blocked++;
    }

    int pendingFeedback = 0;
    for (final doc in feedbackDocs) {
      if (doc.data()['status'] == 'pending') pendingFeedback++;
    }

    return {
      'totalUsers': totalUsers,
      'admins': admins,
      'mothers': mothers,
      'fathers': fathers,
      'caretakers': caretakers,
      'blockedUsers': blocked,
      'activeUsers': totalUsers - blocked,
      'totalFeedback': feedbackDocs.length,
      'pendingFeedback': pendingFeedback,
      'totalMothers': mothersProfileCount,
      'totalBabies': babiesCount,
      'unreadAdminNotifications': adminNotifCount,
    };
  }

  /// Counts documents in a `collectionGroup(subcollection)` snapshot whose
  /// parent `users/{uid}` doc id is in [validUids] — i.e. excludes
  /// already-orphaned leftovers from a user deleted before the cascading
  /// delete fix existed, so dashboard counts match what the orphan-safe
  /// streams above actually display.
  int _orphanSafeCount(
    QuerySnapshot<Map<String, dynamic>> snap,
    Set<String> validUids,
  ) {
    return snap.docs.where((d) {
      final parentUid = d.reference.parent.parent?.id;
      return parentUid != null && validUids.contains(parentUid);
    }).length;
  }

  Future<void> _computeLiveAnalytics() async {
    try {
      final usersSnap = await _freshGet(_usersCol);
      final validUids = usersSnap.docs.map((d) => d.id).toSet();
      final feedbackSnap = await _freshGet(_firestore.collection('feedback'));
      final mothersSnap = await _freshGet(
          _firestore.collectionGroup(_motherProfileSubcollection));
      final babiesSnap =
          await _freshGet(_firestore.collectionGroup(_babiesSubcollection));
      final myUid = currentUid;
      final adminNotifsSnap = myUid == null
          ? null
          : await _freshGet(_firestore
              .collection('notifications')
              .where('recipientId', isEqualTo: myUid)
              .where('read', isEqualTo: false));

      liveAnalytics.value = _tally(
        usersSnap.docs,
        feedbackSnap.docs,
        _orphanSafeCount(mothersSnap, validUids),
        _orphanSafeCount(babiesSnap, validUids),
        adminNotifsSnap?.docs.length ?? 0,
      );
    } catch (e) {
      debugPrint('AdminService: live analytics error: $e');
    }
  }

  /// One-shot analytics snapshot for the admin dashboard cards — always
  /// forces a fresh server read (see class doc comment), which is what
  /// pull-to-refresh on the dashboard calls.
  Future<Map<String, int>> getAnalytics() async {
    final usersSnap = await _freshGet(_usersCol);
    final validUids = usersSnap.docs.map((d) => d.id).toSet();
    final feedbackSnap = await _freshGet(_firestore.collection('feedback'));
    final mothersSnap = await _freshGet(
        _firestore.collectionGroup(_motherProfileSubcollection));
    final babiesSnap =
        await _freshGet(_firestore.collectionGroup(_babiesSubcollection));

    return _tally(
      usersSnap.docs,
      feedbackSnap.docs,
      _orphanSafeCount(mothersSnap, validUids),
      _orphanSafeCount(babiesSnap, validUids),
      0,
    );
  }

  // ── BLOCK / UNBLOCK ──────────────────────────────────────────────────────

  /// Throws if [uid] is the currently signed-in admin — an admin can never
  /// block, demote, or remove their own account from this panel. (The UI
  /// already hides these actions for "yourself" as a first line of
  /// defence; this is the second line, in case a future screen forgets to
  /// check `isMe` before calling the service directly.)
  void _assertNotSelf(String uid, String action) {
    if (uid == currentUid) {
      throw StateError('You cannot $action your own admin account.');
    }
  }

  Future<void> setUserBlocked(String uid, bool blocked) async {
    if (blocked) _assertNotSelf(uid, 'block');
    await _usersCol.doc(uid).update({'blocked': blocked});
  }

  // ── ADMIN DIRECTORY (`admin_uids`) ───────────────────────────────────────
  //
  // A small, publicly-readable collection whose only purpose is "which
  // uids are admins" — no other user data lives here. Regular users are
  // allowed to READ it (so FeedbackService.sendToAdmins can find who to
  // notify without needing access to the full `users` collection, which
  // the Firestore rules correctly restrict to `isSelf() || isAdmin()`).
  // Only admins can WRITE to it.

  /// Self-healing: call this once when the admin dashboard loads so any
  /// admin account created before this directory existed — or whose entry
  /// was somehow lost — repairs itself automatically.
  Future<void> ensureAdminDirectoryEntry() async {
    final uid = currentUid;
    if (uid == null) return;
    try {
      await _adminUidsCol.doc(uid).set(
          {'addedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('AdminService: ensureAdminDirectoryEntry failed: $e');
    }
  }

  // ── PROMOTE TO ADMIN ─────────────────────────────────────────────────────

  /// Promotes [uid] to admin. Per app design: after promoting someone
  /// else, the current admin is immediately signed out for security (the
  /// caller — the UI — is responsible for showing the warning dialog and
  /// then calling AuthService().logout() + navigating to /login).
  Future<void> promoteToAdmin(String uid) async {
    await _usersCol.doc(uid).update({'role': 'admin'});
    await _adminUidsCol.doc(uid).set(
        {'addedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await _notifications.sendToUser(
      userId: uid,
      title: '🎉 You are now an admin',
      body: 'An administrator has granted you admin access.',
      type: 'admin_message',
      senderName: 'System',
    );
  }

  // ── DELETE (see class-level doc comment for the Auth-deletion caveat) ───

  /// Admin-initiated removal of another user's account. Cascades a full
  /// wipe of everything that belongs to them — baby profiles, mother
  /// profile, every health tracker, their notifications, their feedback,
  /// and finally the `users/{uid}` doc itself (see
  /// `AccountCleanupService.wipeAllUserData`) — then permanently blocks
  /// their login. Does NOT delete the Firebase Auth record (see class doc
  /// comment): the `blocked: true` write happens FIRST, before the wipe,
  /// so `AuthService.login()` rejects them immediately even if the wipe
  /// is interrupted partway through (e.g. the admin's device goes
  /// offline) — a user is never left in limbo, still able to log in, mid
  /// deletion.
  Future<void> deleteUserAccount(String uid) async {
    _assertNotSelf(uid, 'remove');
    await _usersCol.doc(uid).update({'blocked': true});
    try {
      await _adminUidsCol.doc(uid).delete();
    } catch (_) {
      // Fine if it never had an entry (non-admin account).
    }
    await AccountCleanupService.wipeAllUserData(uid);
  }

  /// Runs the one-time orphan-data sweep (see
  /// `AccountCleanupService.cleanupOrphans`) and returns how many leftover
  /// documents — from users deleted before the cascading-delete fix
  /// existed — were permanently removed. Safe to run more than once; a
  /// second run should return 0 once the database is clean.
  Future<int> cleanupOrphans() => AccountCleanupService.cleanupOrphans();

  /// Whether there is at least one OTHER active admin besides [excludeUid].
  /// Used to enforce "an admin must promote someone else before deleting
  /// their own account" / "cannot delete the last admin".
  Future<bool> hasAnotherActiveAdmin(String excludeUid) async {
    final snap = await _usersCol
        .where('role', isEqualTo: 'admin')
        .where('blocked', isEqualTo: false)
        .get();
    return snap.docs.any((doc) => doc.id != excludeUid);
  }

  // ── ROLE LOOKUP (used for post-login/register redirect) ─────────────────

  /// Reads the `role` field for [uid] from Firestore. Returns 'mother' if
  /// the field is missing (new/never-set) so callers can safely default
  /// to the normal user dashboard.
  Future<String> getUserRole(String uid) async {
    final doc = await _usersCol.doc(uid).get();
    if (!doc.exists) return 'mother';
    return normalizeRole(doc.data()?['role']);
  }
}
