import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_notification_service.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppNotificationService _notifications = AppNotificationService();

  CollectionReference get _col => _firestore.collection('feedback');

  // ── USER SIDE ────────────────────────────────────────────────────────────

  Future<String?> submitFeedback(String message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in.';

      // Look up the user's name from their own profile doc (users/{uid}).
      // Falls back to Firebase Auth's displayName, then to null (admin UI
      // shows "Unknown" in that case) — this never blocks the feedback
      // from being submitted even if the profile read fails.
      String? userName;
      try {
        final profileDoc =
            await _firestore.collection('users').doc(user.uid).get();
        userName = (profileDoc.data()?['name'] as String?)?.trim();
        if (userName == null || userName.isEmpty) userName = null;
      } catch (_) {
        // Ignore — fall back below.
      }
      userName ??= user.displayName;

      await _col.add({
        ...FeedbackModel(
          userId: user.uid,
          userEmail: user.email,
          userName: userName,
          message: message.trim(),
        ).toMap(),
        // FeedbackModel.toMap() deliberately omits these — see its own
        // doc comment — because they're set here via serverTimestamp()
        // (create) vs. in replyToFeedback() (update), not by the model.
        'createdAt': FieldValue.serverTimestamp(),
        'repliedAt': null,
      });

      // NOTE: we deliberately do NOT try to notify admins from here
      // anymore. That used to go through
      // AppNotificationService.sendToAdmins(), which fans a
      // notification out via the `admin_uids` directory — a path with
      // several independent ways to silently fail (rules not
      // published, directory not yet populated, a stale offline read),
      // all while this feedback save still succeeds, which made the
      // failure invisible and very hard to track down.
      //
      // Admins are now notified by AdminFeedbackWatcherMixin (see
      // lib/services/admin_feedback_watcher_mixin.dart), which runs on
      // the ADMIN's own device and watches this `feedback` collection
      // directly — the same read access Feedback Management already
      // relies on and is known to work — instead of depending on a
      // write made by the submitting user's device. This is simpler
      // and cannot be broken by admin_uids/rules-deploy timing.
      return null;
    } catch (e) {
      return 'Failed to send feedback. Please try again.';
    }
  }

  /// A user's own feedback history (so they can see what they've sent and
  /// whether it's been replied to).
  Stream<QuerySnapshot> getMyFeedback() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── ADMIN SIDE ───────────────────────────────────────────────────────────

  /// All feedback, newest first. Admin views everything regardless of
  /// status.
  Stream<List<QueryDocumentSnapshot>> getAllFeedback() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs);
  }

  /// Pending feedback only.
  ///
  /// FIX: this used to be `.where('status', isEqualTo: 'pending')
  /// .orderBy('createdAt', descending: true)` — a composite (status +
  /// createdAt) query, which Firestore refuses to run without a
  /// matching composite index being created in the console first. Since
  /// that index was never created, this query threw
  /// `failed-precondition` every time, which is exactly why the
  /// "Pending only" tab showed "Could not load feedback." while "All"
  /// worked fine (that one only filters/sorts on a single field).
  ///
  /// Filtering on a single field (`status`) needs no composite index,
  /// so this now does the status filter in Firestore and the
  /// newest-first sort on the client, over what is normally a small
  /// result set (pending feedback for one app) — no index required,
  /// same UI result.
  Stream<List<QueryDocumentSnapshot>> getPendingFeedback() {
    return _col.where('status', isEqualTo: 'pending').snapshots().map((snap) {
      DateTime resolve(dynamic value) =>
          value is Timestamp ? value.toDate() : DateTime.now();
      final docs = snap.docs.toList()
        ..sort((a, b) =>
            resolve((b.data() as Map<String, dynamic>)['createdAt']).compareTo(
                resolve((a.data() as Map<String, dynamic>)['createdAt'])));
      return docs;
    });
  }

  /// Admin replies to a feedback item. This updates the feedback doc AND
  /// sends the user an in-app notification with the reply.
  Future<String?> replyToFeedback({
    required String feedbackId,
    required String userId,
    required String originalMessage,
    required String reply,
  }) async {
    try {
      await _col.doc(feedbackId).update({
        'status': 'replied',
        'adminReply': reply.trim(),
        'repliedAt': FieldValue.serverTimestamp(),
      });
      await _notifications.sendToUser(
        userId: userId,
        title: '💬 Admin replied to your feedback',
        body: reply.trim(),
        type: 'feedback_reply',
        relatedId: feedbackId,
        senderName: 'Admin',
      );
      return null;
    } catch (e) {
      return 'Failed to send reply. Please try again.';
    }
  }

  Future<void> deleteFeedback(String feedbackId) async {
    await _col.doc(feedbackId).delete();
  }
}
