import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'session_service.dart';
import 'app_notification_service.dart';
import 'local_notification_service.dart';
import '../main.dart';

/// Watches for two things on the currently signed-in device, for as long
/// as the app process is alive:
///   1. Was THIS device's own session revoked from elsewhere? -> forced
///      logout.
///   2. Did a NEW device just log into this account? -> show a local
///      "Was this you?" alert — but only where it actually belongs.
///
/// BUG THIS FILE FIXES (previously): the "new login" alert used to pop
/// up on every open of the app, on every device signed into the
/// account — including on the brand-new device that had just logged in
/// itself. Two separate causes, both fixed below:
///
///   a) SELF-ALERT: `new_login` notifications are written once, addressed
///      to the *account* (`recipientId: uid`), not to a specific device.
///      Every device's stream listener saw the same doc — including the
///      new device the alert was actually ABOUT. Fixed by comparing the
///      notification's `relatedId` (the new session's id) against this
///      device's OWN local session id and skipping it if they match —
///      a device never alerts itself about its own login.
///
///   b) REPEATS ON RESTART: the old per-alert dedup (`_shownAlertIds`)
///      was an in-memory Set, wiped on every app restart. Since the
///      Firestore doc stays `read: false` until a button is actually
///      tapped, simply dismissing/ignoring the OS notification meant it
///      came back again next time the app was opened — on every other
///      already-logged-in ("trusted") device too. Fixed by persisting
///      shown-alert ids to SharedPreferences, so a device that already
///      showed a given login alert once never shows that exact one
///      again, restart or not — independent of whether the person ever
///      tapped Confirm/Block.
///
/// Everything here works on the free Spark plan — no Blaze, no Cloud
/// Functions, no paid extension needed.
class SessionGuardService {
  static final SessionGuardService _instance = SessionGuardService._internal();
  factory SessionGuardService() => _instance;
  SessionGuardService._internal();

  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();
  final AppNotificationService _notificationService = AppNotificationService();

  static const String _shownAlertsPrefsKey = 'shown_login_alert_ids';
  static const int _maxPersistedShownIds = 200;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<bool>? _revokeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _alertSub;

  final Set<String> _shownAlertIds = {};
  bool _loadedPersistedShown = false;

  void start() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(
          _onAuthChanged,
        );
  }

  Future<void> _loadPersistedShownIds() async {
    if (_loadedPersistedShown) return;
    _loadedPersistedShown = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_shownAlertsPrefsKey) ?? const [];
      _shownAlertIds.addAll(saved);
    } catch (e) {
      debugPrint('SessionGuardService: loading persisted alert ids failed: $e');
    }
  }

  Future<void> _persistShownIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var list = _shownAlertIds.toList();
      if (list.length > _maxPersistedShownIds) {
        list = list.sublist(list.length - _maxPersistedShownIds);
      }
      await prefs.setStringList(_shownAlertsPrefsKey, list);
    } catch (e) {
      debugPrint('SessionGuardService: persisting alert ids failed: $e');
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    await _revokeSub?.cancel();
    await _alertSub?.cancel();
    _revokeSub = null;
    _alertSub = null;

    if (user == null) return;

    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      unawaited(LocalNotificationService().checkAndRequestPermission(ctx));
    } else {
      debugPrint(
        'SessionGuardService: no navigator context yet, skipping permission check for this auth event',
      );
    }

    await _loadPersistedShownIds();

    // This device's OWN session id — used below to make sure a device
    // never shows itself the "new login" alert about its own login.
    final mySessionId = await _sessionService.getLocalSessionId();

    if (mySessionId != null) {
      _revokeSub = _sessionService
          .watchSessionRevoked(user.uid, mySessionId)
          .listen((revoked) async {
        if (!revoked) return;
        await _handleForcedLogout();
      });
    }

    _alertSub = _notificationService.streamMyNotifications().listen(
      (snap) {
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['type'] != 'new_login') continue;
          if (data['read'] == true) continue;

          final newDeviceSessionId = data['relatedId'] as String?;

          // Fix (a): don't let a device alert itself about its own login.
          if (mySessionId != null && newDeviceSessionId == mySessionId) {
            continue;
          }

          // Fix (b): persisted dedup — never re-show an alert this device
          // has already shown once, restart or not.
          if (_shownAlertIds.contains(doc.id)) continue;
          _shownAlertIds.add(doc.id);
          unawaited(_persistShownIds());

          LocalNotificationService().show(
            title: data['title'] ?? 'New login detected',
            body: data['body'] ??
                'Was this you? Tap "Yes, it was me" to confirm, or '
                    '"No, block it" to secure your account.',
            payload: jsonEncode({
              'type': 'new_login',
              'notificationId': doc.id,
              'sessionId': newDeviceSessionId,
            }),
            actions: const [
              AndroidNotificationAction(
                LocalNotificationService.actionConfirmLogin,
                'Yes, it was me',
                showsUserInterface: false,
              ),
              AndroidNotificationAction(
                LocalNotificationService.actionBlockLogin,
                "No, block it",
                showsUserInterface: false,
              ),
            ],
          );
        }
      },
      onError: (e) {
        debugPrint('SessionGuardService: alert stream error: $e');
      },
    );
  }

  Future<void> _handleForcedLogout() async {
    try {
      await _sessionService.clearLocalSessionId();
      await _authService.logout();
    } catch (e) {
      debugPrint('SessionGuardService: forced logout failed: $e');
    }
    final navState = navigatorKey.currentState;
    if (navState == null) return;
    navState.pushNamedAndRemoveUntil('/login', (route) => false);
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text(
          'You were signed out on this device for security reasons.',
        ),
      ),
    );
  }
}
