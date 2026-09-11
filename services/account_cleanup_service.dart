import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Wipes every piece of Firestore data that belongs to one user.
///
/// WHY THIS EXISTS
/// ----------------
/// Firestore never cascade-deletes subcollections: deleting a parent
/// document (`users/{uid}`) leaves every document under
/// `users/{uid}/{subcollection}/...` sitting in the database forever,
/// orphaned. Both `AuthService.deleteAccount()` (self-delete) and
/// `AdminService.deleteUserAccount()` (admin-initiated removal) used to
/// delete only the top-level `users/{uid}` doc, which is exactly why
/// deleted users' baby profiles, mother profiles, and health records kept
/// showing up in admin lists/counts afterwards.
///
/// This service is the single place that knows every subcollection the
/// app actually writes to (see `FirestoreService.collection()` — every
/// per-user record lives under `users/{uid}/{name}`), so both delete
/// flows can call the same method and stay in sync if a new tracker
/// collection is ever added.
class AccountCleanupService {
  AccountCleanupService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Every subcollection written via `FirestoreService.collection(name)` /
  /// `.add()` / `.stream()` anywhere in the app. Keep this in sync with
  /// actual usage — grep for `FirestoreService.stream(` /
  /// `FirestoreService.collection(` / `FirestoreService.add(` if you add a
  /// new tracker and update this list.
  static const List<String> perUserSubcollections = [
    'babies',
    'mother_profile',
    'baby_medical_history',
    'baby_weight',
    'blood_pressure',
    'glucose',
    'medical_history',
    'milestones',
    'mother_weight',
    'allergies',
    'vaccinations',
  ];

  /// Firestore write batches are capped at 500 operations. Chunk deletes
  /// so a user with an unusually large history never overflows a batch.
  static const int _batchLimit = 400;

  static Future<void> _deleteInChunks(
    List<DocumentReference> refs,
  ) async {
    for (var i = 0; i < refs.length; i += _batchLimit) {
      final chunk = refs.sublist(
        i,
        i + _batchLimit > refs.length ? refs.length : i + _batchLimit,
      );
      final batch = _db.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Deletes every document under `users/{uid}/{subcollection}` for every
  /// subcollection in [perUserSubcollections], every top-level
  /// `notifications` doc addressed to this user (`recipientId == uid`),
  /// every top-level `feedback` doc submitted by this user
  /// (`userId == uid`), and finally the `users/{uid}` doc itself.
  ///
  /// Safe to call more than once (e.g. if a previous attempt partially
  /// failed offline) — deleting an already-deleted document is a no-op.
  static Future<void> wipeAllUserData(String uid) async {
    // 1. Per-user subcollections: users/{uid}/{name}/*
    for (final name in perUserSubcollections) {
      try {
        final snap =
            await _db.collection('users').doc(uid).collection(name).get();
        if (snap.docs.isEmpty) continue;
        await _deleteInChunks(snap.docs.map((d) => d.reference).toList());
      } catch (e) {
        debugPrint(
            'AccountCleanupService: failed clearing "$name" for $uid: $e');
      }
    }

    // 2. Notifications addressed to this user (top-level collection).
    try {
      final notifSnap = await _db
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .get();
      if (notifSnap.docs.isNotEmpty) {
        await _deleteInChunks(notifSnap.docs.map((d) => d.reference).toList());
      }
    } catch (e) {
      debugPrint(
          'AccountCleanupService: failed clearing notifications for $uid: $e');
    }

    // 2b. Notifications this user CAUSED but that live on someone else's
    // inbox — e.g. the "📝 New feedback received" alert
    // AdminFeedbackWatcherMixin wrote to every admin (`recipientId` =
    // the admin's uid, not this user's), tagged with `senderId` = this
    // user's uid. Without this step, deleting a user's own feedback
    // (step 3 below) would NOT remove the notification admins already
    // received about it — it would sit in the admin's notification
    // list forever, pointing at a feedback doc that no longer exists.
    try {
      final senderNotifSnap = await _db
          .collection('notifications')
          .where('senderId', isEqualTo: uid)
          .get();
      if (senderNotifSnap.docs.isNotEmpty) {
        await _deleteInChunks(
            senderNotifSnap.docs.map((d) => d.reference).toList());
      }
    } catch (e) {
      debugPrint('AccountCleanupService: failed clearing sender-attributed '
          'notifications for $uid: $e');
    }

    // 3. Feedback submitted by this user (top-level collection).
    try {
      final feedbackSnap = await _db
          .collection('feedback')
          .where('userId', isEqualTo: uid)
          .get();
      if (feedbackSnap.docs.isNotEmpty) {
        await _deleteInChunks(
            feedbackSnap.docs.map((d) => d.reference).toList());
      }
    } catch (e) {
      debugPrint(
          'AccountCleanupService: failed clearing feedback for $uid: $e');
    }

    // 4. The user's own profile doc, last — once this is gone the orphan
    // filters elsewhere in the app immediately stop counting any records
    // that somehow failed to delete above.
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('AccountCleanupService: failed deleting users/$uid doc: $e');
      rethrow;
    }
  }

  /// One-time sweep across EVERY user: finds documents in each
  /// subcollection (via `collectionGroup`), plus `notifications` and
  /// `feedback`, whose parent `users/{uid}` doc no longer exists, and
  /// permanently deletes them.
  ///
  /// This is for data that was already orphaned BEFORE the cascade-delete
  /// fix above existed (i.e. from a user deleted by the old, buggy delete
  /// flow). New deletes going forward use [wipeAllUserData] and never
  /// create new orphans, so this only needs to be run once — but it's
  /// safe to run again any time as a sanity sweep.
  ///
  /// Returns the total number of documents deleted, so the admin UI can
  /// show a "Removed N orphaned records" confirmation.
  static Future<int> cleanupOrphans() async {
    final usersSnap = await _db.collection('users').get();
    final validUids = usersSnap.docs.map((d) => d.id).toSet();

    int deleted = 0;

    for (final name in perUserSubcollections) {
      try {
        final snap = await _db.collectionGroup(name).get();
        final orphanRefs = snap.docs
            .where((d) {
              final parentUid = d.reference.parent.parent?.id;
              return parentUid == null || !validUids.contains(parentUid);
            })
            .map((d) => d.reference)
            .toList();
        if (orphanRefs.isNotEmpty) {
          await _deleteInChunks(orphanRefs);
          deleted += orphanRefs.length;
        }
      } catch (e) {
        debugPrint('AccountCleanupService: orphan sweep failed for '
            '"$name": $e');
      }
    }

    // Orphaned notifications: either the recipient no longer exists, OR
    // (e.g. an admin's "new feedback" alert) the sender who caused it no
    // longer exists — both leave a stale notification pointing at
    // nothing, so both are swept here.
    try {
      final notifSnap = await _db.collection('notifications').get();
      final orphanRefs = notifSnap.docs
          .where((d) {
            final data = d.data();
            final recipientId = data['recipientId'] as String?;
            final senderId = data['senderId'] as String?;
            final recipientOrphaned =
                recipientId != null && !validUids.contains(recipientId);
            final senderOrphaned =
                senderId != null && !validUids.contains(senderId);
            return recipientOrphaned || senderOrphaned;
          })
          .map((d) => d.reference)
          .toList();
      if (orphanRefs.isNotEmpty) {
        await _deleteInChunks(orphanRefs);
        deleted += orphanRefs.length;
      }
    } catch (e) {
      debugPrint('AccountCleanupService: orphan sweep failed for '
          'notifications: $e');
    }

    // Orphaned feedback (author no longer exists).
    try {
      final feedbackSnap = await _db.collection('feedback').get();
      final orphanRefs = feedbackSnap.docs
          .where((d) {
            final userId = d.data()['userId'] as String?;
            return userId != null && !validUids.contains(userId);
          })
          .map((d) => d.reference)
          .toList();
      if (orphanRefs.isNotEmpty) {
        await _deleteInChunks(orphanRefs);
        deleted += orphanRefs.length;
      }
    } catch (e) {
      debugPrint('AccountCleanupService: orphan sweep failed for feedback: $e');
    }

    // Orphaned admin_uids directory entries (account no longer exists).
    try {
      final adminUidsSnap = await _db.collection('admin_uids').get();
      final orphanRefs = adminUidsSnap.docs
          .where((d) => !validUids.contains(d.id))
          .map((d) => d.reference)
          .toList();
      if (orphanRefs.isNotEmpty) {
        await _deleteInChunks(orphanRefs);
        deleted += orphanRefs.length;
      }
    } catch (e) {
      debugPrint(
          'AccountCleanupService: orphan sweep failed for admin_uids: $e');
    }

    return deleted;
  }
}
