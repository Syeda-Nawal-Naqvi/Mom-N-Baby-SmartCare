import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mother_and_baby_smartcare/models/mother_profile_model.dart';
import 'package:mother_and_baby_smartcare/services/firebase_service.dart';

class MotherProfileService {
  MotherProfileService._internal();
  static final MotherProfileService _instance =
      MotherProfileService._internal();
  factory MotherProfileService() => _instance;

  static const String _docId = 'profile';

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirestoreService.collection('mother_profile').doc(_docId);

  Stream<MotherProfileModel?> streamProfile() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists) return null;
      return MotherProfileModel.fromSnapshot(snap);
    });
  }

  Future<MotherProfileModel?> getProfile() async {
    final snap = await _doc.get();
    if (!snap.exists) return null;
    return MotherProfileModel.fromSnapshot(snap);
  }

  Future<void> saveProfile(MotherProfileModel profile) async {
    await _doc.set(profile.toMap());
  }
}
