import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_service.dart';
import 'app_notification_service.dart';
import 'auth_service.dart';
import '../main.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _notifId = 0;

  static const String _channelId = 'mother_baby_smartcare_notifications';
  static const String _channelName = 'App notifications';
  static const String _channelDescription =
      'Feedback replies and messages from the admin team.';

  static const String actionConfirmLogin = 'confirm_login';
  static const String actionBlockLogin = 'block_login';

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      _initialized = true;
    } catch (e) {
      debugPrint('LocalNotificationService: init failed: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse details) {
    final payload = details.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] != 'new_login') return;

      final sessionId = data['sessionId'] as String?;
      final notificationId = data['notificationId'] as String?;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (details.actionId == actionConfirmLogin) {
        if (uid != null && sessionId != null) {
          SessionService().confirmSession(uid, sessionId);
        }
        if (notificationId != null) {
          AppNotificationService().markAsRead(notificationId);
        }
        return;
      }

      if (details.actionId == actionBlockLogin) {
        if (uid != null && sessionId != null) {
          SessionService().revokeSession(uid, sessionId);
        }
        if (notificationId != null) {
          AppNotificationService().markAsRead(notificationId);
        }
        final email = FirebaseAuth.instance.currentUser?.email;
        if (email != null) {
          AuthService().sendPasswordResetEmail(email);
        }
        return;
      }

      navigatorKey.currentState?.pushNamed('/security_alert', arguments: {
        'sessionId': sessionId,
        'notificationId': notificationId,
      });
    } catch (e) {
      debugPrint('LocalNotificationService: payload parse failed: $e');
    }
  }

  Future<bool> checkAndRequestPermission(BuildContext context) async {
    final status = await Permission.notification.status;
    if (!context.mounted) return status.isGranted;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await _showGoToSettingsDialog(context);
      return false;
    }

    final result = await Permission.notification.request();
    if (!context.mounted) return result.isGranted;

    if (result.isPermanentlyDenied) {
      await _showGoToSettingsDialog(context);
      return false;
    }

    return result.isGranted;
  }

  Future<void> _showGoToSettingsDialog(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Notifications Off'),
        content: const Text(
          'Feedback replies aur admin messages ke liye notifications zaroori '
          'hain. Enable karne ke liye Settings mein jayein.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Baad Mein'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<bool> requestPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('LocalNotificationService: permission request failed: $e');
      return false;
    }
  }

  Future<bool> isPermissionGranted() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> show({
    required String title,
    required String body,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) {
      debugPrint(
          'LocalNotificationService: show() skipped, plugin never initialized');
      return;
    }
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: actions,
    );
    final details = NotificationDetails(android: androidDetails);
    try {
      await _plugin.show(_notifId, title, body, details, payload: payload);
      _notifId = (_notifId + 1) % 100000;
    } catch (e) {
      debugPrint('LocalNotificationService: show failed: $e');
    }
  }
}
