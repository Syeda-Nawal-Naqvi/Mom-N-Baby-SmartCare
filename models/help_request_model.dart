import 'package:cloud_firestore/cloud_firestore.dart';

/// `help_requests/{docId}` — a top-level, PUBLIC-WRITE collection used by
/// users who are locked out of their account (forgot password AND lost
/// access to their recovery email, blocked account, etc.) and therefore
/// cannot use the normal in-app Feedback screen, which requires being
/// signed in.
///
/// Submitted from [NeedHelpScreen] with NO Firebase Auth session at all
/// — see firestore_rules.txt's `match /help_requests/{id}` block, which
/// allows `create` from anyone (validated, not admin-gated) but restricts
/// `read`/`update`/`delete` to admins only.
///
/// The admin does NOT reply through the app's own in-app
/// notification system (there is no signed-in account to notify) —
/// instead [AdminHelpRequestsScreen] opens the device's native email
/// app, addressed to `email`, via flutter_email_sender.
class HelpRequestModel {
  String? id;
  String name;
  String email;
  String message;
  String status; // 'pending' | 'resolved'
  Timestamp? createdAt;
  Timestamp? resolvedAt;

  HelpRequestModel({
    this.id,
    required this.name,
    required this.email,
    required this.message,
    this.status = 'pending',
    this.createdAt,
    this.resolvedAt,
  });

  factory HelpRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return HelpRequestModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'],
      resolvedAt: map['resolvedAt'],
    );
  }

  factory HelpRequestModel.fromSnapshot(DocumentSnapshot doc) =>
      HelpRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  /// Used only by the submit path (create). `createdAt` is set separately
  /// via FieldValue.serverTimestamp() at the call site, same convention
  /// as FeedbackModel.toMap().
  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'message': message,
        'status': status,
      };
}
