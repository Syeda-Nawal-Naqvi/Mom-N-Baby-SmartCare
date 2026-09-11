import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'app_notification_service.dart';
import 'local_notification_service.dart';
import 'notification_sound_service.dart';

/// Mixin: add `with NotificationWatcherMixin` to any State (HomeScreen,
/// AdminDashboardScreen) to react to new notifications while that screen
/// is alive. Call `startWatchingNotifications()` in initState and
/// `stopWatchingNotifications()` in dispose.
///
/// On every newly-added UNREAD notification (not ones that were already
/// sitting there before this screen opened) it:
///   1. Plays the in-app pop sound (if enabled).
///   2. Shows a real OS notification-tray entry (if BOTH the app-level
///      preference AND the OS-level runtime permission are on — see the
///      note below).
/// It also runs the retention cleanup (`enforceRetention`) once at start
/// and again after every batch of new arrivals, so the list never grows
/// past the 10-read / 20-total policy.
///
/// TWO SEPARATE "notifications enabled" CONCEPTS — do not confuse them:
///   - App-level preference (`AppNotificationService.isNotificationsEnabled`)
///     is a Firestore field the user toggles from the in-app Settings
///     screen. It has nothing to do with the OS.
///   - OS-level runtime permission (`LocalNotificationService
///     .isPermissionGranted`) is the actual Android/iOS system
///     permission granted via the native Allow/Deny dialog.
/// Previously only the app-level flag was checked here, so a user could
/// have the in-app toggle ON while the OS permission was denied — the
/// tray call would then silently fail deep inside
/// `LocalNotificationService.show()` with only a debugPrint to show for
/// it. Checking both here means we simply skip the tray call (and can
/// optionally re-prompt) instead of attempting a call we already know
/// will fail.
mixin NotificationWatcherMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  final Set<String> _seenIds = {};
  bool _isFirstSnapshot = true;

  void startWatchingNotifications() {
    final service = AppNotificationService();
    service.enforceRetention();

    _notifSub = service.streamMyNotifications().listen((snapshot) async {
      // The first snapshot is the existing backlog (notifications that
      // were already there before this screen opened). We don't want a
      // full run of individual "new item" alerts for old items — but
      // per product request, if there's ANY unread notification
      // waiting the moment the app opens, we DO want a single pop sound
      // so the person notices the unread badge instead of only relying
      // on them spotting the bell icon. (No OS tray notification for
      // the backlog case — a tray popup for something that happened in
      // the past, possibly while the app was closed, would be
      // confusing; the tray is reserved for genuinely new arrivals
      // below.)
      if (_isFirstSnapshot) {
        _isFirstSnapshot = false;
        var hasUnreadBacklog = false;
        for (final doc in snapshot.docs) {
          _seenIds.add(doc.id);
          if (doc.data()['read'] != true) hasUnreadBacklog = true;
        }
        if (hasUnreadBacklog) {
          NotificationSoundService().playPopIfEnabled();
        }
        return;
      }

      // Collect the genuinely-new unread docs first, then alert on them
      // one at a time (awaited, in order) instead of firing sound/tray
      // calls concurrently for every doc in the batch. Firing them
      // concurrently on the SAME shared AudioPlayer instance let a
      // later `stop()`/`play()` cut off an earlier one mid-sound when
      // several notifications landed in the same snapshot (e.g. an
      // admin broadcast to many users, or several feedback replies
      // arriving close together) — this was a real, if subtle, cause
      // of "sound didn't play" reports.
      final newUnread = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        if (_seenIds.contains(doc.id)) continue;
        _seenIds.add(doc.id);
        final data = doc.data();
        if (data['read'] == true) continue; // nothing to alert about
        newUnread.add(data);
      }

      if (newUnread.isEmpty) return;

      // Both flags must be true for a tray notification to have any
      // real chance of showing. See the class-level doc comment above
      // for why these are two genuinely different things.
      final appPrefEnabled = await service.isNotificationsEnabled();
      final osPermissionGranted =
          await LocalNotificationService().isPermissionGranted();
      final canShowTray = appPrefEnabled && osPermissionGranted;

      if (!appPrefEnabled) {
        debugPrint(
            'NotificationWatcherMixin: OS tray notification skipped — app-level notificationsEnabled preference is off');
      } else if (!osPermissionGranted) {
        debugPrint(
            'NotificationWatcherMixin: OS tray notification skipped — OS runtime permission not granted (see SessionGuardService for the re-prompt flow)');
      }

      for (final data in newUnread) {
        await NotificationSoundService().playPopIfEnabled();
        if (canShowTray) {
          await LocalNotificationService().show(
            title: (data['title'] as String?) ?? 'New notification',
            body: (data['body'] as String?) ?? '',
          );
        }
      }

      service.enforceRetention();
    });
  }

  void stopWatchingNotifications() {
    _notifSub?.cancel();
  }
}
