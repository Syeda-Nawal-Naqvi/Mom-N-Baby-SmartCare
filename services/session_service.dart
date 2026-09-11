import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_notification_service.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _notifications = AppNotificationService();

  static const String _localSessionKey = 'current_session_id';

  CollectionReference<Map<String, dynamic>> _sessionsCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('sessions');

  String _deviceLabel() {
    if (kIsWeb) return 'Web browser';
    try {
      if (Platform.isAndroid) return 'Android device';
      if (Platform.isIOS) return 'iPhone / iPad';
      if (Platform.isWindows) return 'Windows PC';
      if (Platform.isMacOS) return 'Mac';
      if (Platform.isLinux) return 'Linux PC';
    } catch (_) {}
    return 'Unknown device';
  }

  String _generateSessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = (now * 31 + 17) % 1000000;
    return 's_${now}_$rand';
  }

  Future<String> registerSession(String uid) async {
    final sessionId = _generateSessionId();
    final deviceLabel = _deviceLabel();

    QuerySnapshot<Map<String, dynamic>> existing;
    try {
      existing =
          await _sessionsCol(uid).where('status', isEqualTo: 'active').get();
    } catch (e) {
      debugPrint('SessionService: reading existing sessions failed: $e');
      existing = await _sessionsCol(uid).get();
    }

    await _sessionsCol(uid).doc(sessionId).set({
      'deviceLabel': deviceLabel,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localSessionKey, sessionId);

    if (existing.docs.isNotEmpty) {
      try {
        await _notifications.sendToUser(
          userId: uid,
          title: 'New login detected',
          body: 'A new login was detected from $deviceLabel. Was this you?',
          type: 'new_login',
          relatedId: sessionId,
          senderName: 'Security',
        );
      } catch (e) {
        debugPrint('SessionService: sending new_login alert failed: $e');
      }
    }

    return sessionId;
  }

  Future<String?> getLocalSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localSessionKey);
  }

  Future<void> clearLocalSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localSessionKey);
  }

  Stream<bool> watchSessionRevoked(String uid, String sessionId) {
    return _sessionsCol(uid).doc(sessionId).snapshots().map((doc) {
      if (!doc.exists) return true;
      return doc.data()?['status'] == 'revoked';
    });
  }

  Future<void> confirmSession(String uid, String sessionId) async {
    await _sessionsCol(uid).doc(sessionId).set(
      {'status': 'active', 'confirmedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> revokeSession(String uid, String sessionId) async {
    await _sessionsCol(uid).doc(sessionId).set(
      {'status': 'revoked', 'revokedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> revokeCurrentSessionOnLogout(String uid) async {
    final sessionId = await getLocalSessionId();
    if (sessionId == null) return;
    try {
      await _sessionsCol(uid).doc(sessionId).delete();
    } catch (e) {
      debugPrint('SessionService: deleting session on logout failed: $e');
    }
    await clearLocalSessionId();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getActiveSessions(
      String uid) async {
    final snap =
        await _sessionsCol(uid).where('status', isEqualTo: 'active').get();
    return snap.docs;
  }

  /// Live version of [getActiveSessions], used by LoginActivityScreen so
  /// a device that gets confirmed/blocked from elsewhere updates the list
  /// in real time without a manual refresh.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamActiveSessions(String uid) {
    return _sessionsCol(uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs);
  }
}
