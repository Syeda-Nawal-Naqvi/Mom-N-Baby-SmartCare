import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryRecord {
  String label;
  String date;

  DeliveryRecord({required this.label, required this.date});

  factory DeliveryRecord.fromMap(Map<String, dynamic> map) {
    return DeliveryRecord(
      label: map['label'] ?? '',
      date: map['date'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'date': date};
}

class MotherProfileModel {
  String? id;
  String name;
  int age;
  String bloodGroup;
  List<DeliveryRecord> deliveries;
  Timestamp? createdAt;
  Timestamp? updatedAt;

  MotherProfileModel({
    this.id,
    required this.name,
    required this.age,
    required this.bloodGroup,
    List<DeliveryRecord>? deliveries,
    this.createdAt,
    this.updatedAt,
  }) : deliveries = deliveries ?? [];

  factory MotherProfileModel.fromMap(Map<String, dynamic> map, String id) {
    final rawList = map['deliveries'] as List<dynamic>? ?? [];
    final list = rawList
        .map((e) => DeliveryRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return MotherProfileModel(
      id: id,
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      bloodGroup: map['bloodGroup'] ?? '',
      deliveries: list,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  factory MotherProfileModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MotherProfileModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'bloodGroup': bloodGroup,
      'deliveries': deliveries.map((d) => d.toMap()).toList(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
