import 'package:cloud_firestore/cloud_firestore.dart';

/// Backing model for `users/{uid}/babies/{docId}`.
///
/// Field names verified against the actual write site:
/// `lib/screens/Babyhealthtracker/baby_list_screen.dart` (`_saveBaby`).
class BabyProfileModel {
  String? id;
  String name;
  String gender; // Male | Female | Transgender
  String bloodGroup;
  DateTime dob;
  Timestamp? createdAt;

  BabyProfileModel({
    this.id,
    required this.name,
    required this.gender,
    required this.bloodGroup,
    required this.dob,
    this.createdAt,
  });

  factory BabyProfileModel.fromMap(Map<String, dynamic> map, String id) {
    return BabyProfileModel(
      id: id,
      name: map['name'] ?? '',
      gender: map['gender'] ?? 'Male',
      bloodGroup: map['bloodGroup'] ?? 'Unknown',
      dob: DateTime.tryParse(map['dob']?.toString() ?? '') ?? DateTime.now(),
      createdAt: map['createdAt'],
    );
  }

  factory BabyProfileModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BabyProfileModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'dob': dob.toIso8601String(),
    };
  }
}
