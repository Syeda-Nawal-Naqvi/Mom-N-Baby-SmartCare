import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════
// All BABY-side tracker record models. One file to keep the four small,
// closely-related record types together (mirrors how baby_health_screen
// groups their screens). Each maps 1:1 to a Firestore doc under
// `users/{uid}/{collectionName}`.
//
// Field names verified against the actual write sites in
// lib/screens/Babyhealthtracker/*.dart.
// ═══════════════════════════════════════════════════════════════════

/// `users/{uid}/baby_weight/{docId}`
class BabyWeightModel {
  String? id;
  String babyId;
  double weight; // always stored in kg
  String enteredUnit; // 'kg' | 'lb' — the unit the user originally typed in
  DateTime date;
  Timestamp? createdAt;

  BabyWeightModel({
    this.id,
    required this.babyId,
    required this.weight,
    required this.enteredUnit,
    required this.date,
    this.createdAt,
  });

  factory BabyWeightModel.fromMap(Map<String, dynamic> map, String id) {
    return BabyWeightModel(
      id: id,
      babyId: map['babyId'] ?? '',
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      enteredUnit: map['enteredUnit'] ?? 'kg',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      createdAt: map['createdAt'],
    );
  }

  factory BabyWeightModel.fromSnapshot(DocumentSnapshot doc) =>
      BabyWeightModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  Map<String, dynamic> toMap() => {
        'babyId': babyId,
        'weight': weight,
        'enteredUnit': enteredUnit,
        'date': date.toIso8601String(),
      };
}

/// `users/{uid}/vaccinations/{docId}`
class VaccinationModel {
  String? id;
  String babyId;
  String vaccineName;
  DateTime vaccinationDate;
  String status; // e.g. 'Done' | 'Pending' | 'Missed'
  Timestamp? createdAt;

  VaccinationModel({
    this.id,
    required this.babyId,
    required this.vaccineName,
    required this.vaccinationDate,
    required this.status,
    this.createdAt,
  });

  factory VaccinationModel.fromMap(Map<String, dynamic> map, String id) {
    return VaccinationModel(
      id: id,
      babyId: map['babyId'] ?? '',
      vaccineName: map['vaccineName'] ?? '',
      vaccinationDate:
          DateTime.tryParse(map['vaccinationDate']?.toString() ?? '') ??
              DateTime.now(),
      status: map['status'] ?? 'Pending',
      createdAt: map['createdAt'],
    );
  }

  factory VaccinationModel.fromSnapshot(DocumentSnapshot doc) =>
      VaccinationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  Map<String, dynamic> toMap() => {
        'babyId': babyId,
        'vaccineName': vaccineName,
        'vaccinationDate': vaccinationDate.toIso8601String(),
        'status': status,
      };
}

/// `users/{uid}/allergies/{docId}`
class AllergyModel {
  String? id;
  String babyId;
  String allergyName;
  String reaction;
  String advice;
  Timestamp? createdAt;

  AllergyModel({
    this.id,
    required this.babyId,
    required this.allergyName,
    required this.reaction,
    required this.advice,
    this.createdAt,
  });

  factory AllergyModel.fromMap(Map<String, dynamic> map, String id) {
    return AllergyModel(
      id: id,
      babyId: map['babyId'] ?? '',
      allergyName: map['allergyName'] ?? '',
      reaction: map['reaction'] ?? '',
      advice: map['advice'] ?? '',
      createdAt: map['createdAt'],
    );
  }

  factory AllergyModel.fromSnapshot(DocumentSnapshot doc) =>
      AllergyModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  Map<String, dynamic> toMap() => {
        'babyId': babyId,
        'allergyName': allergyName,
        'reaction': reaction,
        'advice': advice,
      };
}

/// `users/{uid}/milestones/{docId}`
class MilestoneModel {
  String? id;
  String babyId;
  String title;
  DateTime milestoneDate;
  Timestamp? createdAt;

  MilestoneModel({
    this.id,
    required this.babyId,
    required this.title,
    required this.milestoneDate,
    this.createdAt,
  });

  factory MilestoneModel.fromMap(Map<String, dynamic> map, String id) {
    return MilestoneModel(
      id: id,
      babyId: map['babyId'] ?? '',
      title: map['title'] ?? '',
      milestoneDate:
          DateTime.tryParse(map['milestoneDate']?.toString() ?? '') ??
              DateTime.now(),
      createdAt: map['createdAt'],
    );
  }

  factory MilestoneModel.fromSnapshot(DocumentSnapshot doc) =>
      MilestoneModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  Map<String, dynamic> toMap() => {
        'babyId': babyId,
        'title': title,
        'milestoneDate': milestoneDate.toIso8601String(),
      };
}

/// `users/{uid}/baby_medical_history/{docId}`
class BabyMedicalHistoryModel {
  String? id;
  String babyId;
  String disease;
  String treatment;
  String notes;
  Timestamp? createdAt;

  BabyMedicalHistoryModel({
    this.id,
    required this.babyId,
    required this.disease,
    required this.treatment,
    required this.notes,
    this.createdAt,
  });

  factory BabyMedicalHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    return BabyMedicalHistoryModel(
      id: id,
      babyId: map['babyId'] ?? '',
      disease: map['disease'] ?? '',
      treatment: map['treatment'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'],
    );
  }

  factory BabyMedicalHistoryModel.fromSnapshot(DocumentSnapshot doc) =>
      BabyMedicalHistoryModel.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);

  Map<String, dynamic> toMap() => {
        'babyId': babyId,
        'disease': disease,
        'treatment': treatment,
        'notes': notes,
      };
}
