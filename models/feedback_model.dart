import 'package:cloud_firestore/cloud_firestore.dart';

/// `feedback/{docId}` — a top-level (not per-user) collection: one doc
/// per feedback message, tagged with the sender's `userId` so the
/// Firestore rules can restrict a regular user to their own entries
/// while admins see everything.
///
/// Field names verified against lib/services/feedback_service.dart
/// (`submitFeedback` / `replyToFeedback`).
class FeedbackModel {
  String? id;
  String userId;
  String? userEmail;
  String? userName;
  String message;
  String status; // 'pending' | 'replied'
  String? adminReply;
  Timestamp? createdAt;
  Timestamp? repliedAt;

  FeedbackModel({
    this.id,
    required this.userId,
    this.userEmail,
    this.userName,
    required this.message,
    this.status = 'pending',
    this.adminReply,
    this.createdAt,
    this.repliedAt,
  });

  factory FeedbackModel.fromMap(Map<String, dynamic> map, String id) {
    return FeedbackModel(
      id: id,
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'],
      userName: map['userName'],
      message: map['message'] ?? '',
      status: map['status'] ?? 'pending',
      adminReply: map['adminReply'],
      createdAt: map['createdAt'],
      repliedAt: map['repliedAt'],
    );
  }

  factory FeedbackModel.fromSnapshot(DocumentSnapshot doc) =>
      FeedbackModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  /// NOTE: FeedbackService writes `createdAt`/`repliedAt` itself via
  /// FieldValue.serverTimestamp() at the specific call site (create vs.
  /// reply), so toMap() intentionally omits them — a caller building a
  /// full write payload from this model should add those fields itself
  /// depending on whether it's a create or an update.
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'message': message,
        'status': status,
        'adminReply': adminReply,
      };
}
