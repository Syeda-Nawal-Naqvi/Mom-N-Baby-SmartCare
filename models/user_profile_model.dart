import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}` — the root profile doc AuthService reads/writes.
/// This is the ONE collection every other per-user collection sits
/// under (`users/{uid}/{trackerName}`), and the one whose `role` field
/// drives which dashboard (user/admin) a person lands on after login.
///
/// Field names verified against lib/services/auth_service.dart and
/// lib/services/app_notification_service.dart.
class UserProfileModel {
  String uid;
  String name;
  String? email;
  String role; // mother | father | caretaker | admin
  bool blocked;
  bool notificationsEnabled;
  bool accountVerified;
  String country;
  Timestamp? createdAt;

  UserProfileModel({
    required this.uid,
    required this.name,
    this.email,
    required this.role,
    this.blocked = false,
    this.notificationsEnabled = true,
    this.accountVerified = false,
    this.country = '',
    this.createdAt,
  });

  /// Mirrors AdminService.normalizeRole — the one known legacy value
  /// ('father/husband') is folded into 'father' here too, so this model
  /// stays consistent with the admin panel's own normalization.
  static String _normalizeRole(dynamic rawRole) {
    final role = (rawRole ?? 'mother').toString();
    if (role == 'father/husband') return 'father';
    return role;
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfileModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'],
      role: _normalizeRole(map['role']),
      blocked: map['blocked'] ?? false,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      accountVerified: map['accountVerified'] ?? false,
      country: (map['country'] ?? '').toString(),
      createdAt: map['createdAt'],
    );
  }

  factory UserProfileModel.fromSnapshot(DocumentSnapshot doc) =>
      UserProfileModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role,
        'blocked': blocked,
        'notificationsEnabled': notificationsEnabled,
        'accountVerified': accountVerified,
        'country': country,
      };
}
