import 'package:cloud_firestore/cloud_firestore.dart';

/// `notifications/{docId}` — a top-level (not per-user) collection: one
/// doc per notification, tagged with `recipientId` so the Firestore
/// rules can restrict a regular user to notifications addressed to them
/// while admins see everything.
///
/// Field names verified against lib/services/app_notification_service.dart
/// (`sendToUser` / `sendToAdmins` / `sendToAllUsers`).
class NotificationModel {
  String? id;
  String recipientId;
  String title;
  String body;
  String type; // e.g. 'feedback_submitted' | 'feedback_reply' | 'admin_message'
  String? relatedId;
  String? senderName;

  /// uid of the person this notification is ABOUT/FROM, when that's a
  /// regular user (not the recipient) — e.g. for a `feedback_submitted`
  /// notification sent to an admin, this is the uid of the user who
  /// submitted the feedback. Null for notifications that don't
  /// originate from a specific user (admin broadcasts, system
  /// messages, feedback_reply notifications sent TO the user).
  ///
  /// WHY THIS EXISTS: when a user's account is deleted,
  /// AccountCleanupService.wipeAllUserData already deletes every
  /// notification addressed TO that user (`recipientId == uid`), but
  /// without this field there was no way to also find and delete the
  /// notifications that user's actions had created FOR ADMINS (e.g.
  /// "New feedback received" alerts) — those have `recipientId` equal
  /// to the ADMIN's uid, not the deleted user's, so they'd be silently
  /// left behind forever. Cleanup now also queries `senderId == uid`.
  String? senderId;

  bool read;
  Timestamp? createdAt;

  NotificationModel({
    this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    this.senderName,
    this.senderId,
    this.read = false,
    this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      recipientId: map['recipientId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      relatedId: map['relatedId'],
      senderName: map['senderName'],
      senderId: map['senderId'],
      read: map['read'] ?? false,
      createdAt: map['createdAt'],
    );
  }

  factory NotificationModel.fromSnapshot(DocumentSnapshot doc) =>
      NotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'read': read,
    };
    if (senderName != null) map['senderName'] = senderName;
    if (senderId != null) map['senderId'] = senderId;
    return map;
  }
}
