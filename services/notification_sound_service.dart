import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'app_notification_service.dart';

/// In-app "pop" sound for AppNotificationService events (feedback reply,
/// admin message, new feedback received). Deliberately separate from
/// any scheduled-alarm concept — this just plays a short pop when a new
/// Firestore notification doc shows up while the user/admin is using
/// the app.
///
/// Mute logic: reads the SAME Firestore-backed `notificationsEnabled`
/// flag that SettingsScreen/AdminSettingsScreen read and write via
/// AppNotificationService (see that class for why this moved off
/// shared_preferences). Muting only silences the pop — notifications
/// themselves always still get created and shown in the bell/list, per
/// spec.
///
/// RELIABILITY FIXES vs the previous version:
///   1. `PlayerMode.lowLatency` — the default `PlayerMode.mediaPlayer`
///      on Android routes through ExoPlayer/MediaSession, which is
///      built for long-form audio and can silently fail or lag for a
///      short one-shot SFX like this. `lowLatency` uses SoundPool
///      instead, which is the mode actually meant for short UI sounds
///      and is far more reliable for this use case.
///   2. The asset is pre-loaded once (`setSourceAsset` inside `init`)
///      instead of re-resolving `AssetSource(...)` from scratch on
///      every single call — this removes a repeated async asset-lookup
///      that was a source of intermittent "first tap makes no sound"
///      failures.
///   3. Errors are now logged via `debugPrint` instead of being fully
///      swallowed by an empty `catch (_) {}` — sound is still
///      best-effort and never blocks the UI, but failures are now
///      visible in `adb logcat` / the debug console instead of vanishing
///      without a trace, which made this bug impossible to diagnose
///      before.
class NotificationSoundService {
  static final NotificationSoundService _instance =
      NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  static const String _assetPath = 'sounds/notification_pop.mp3';

  final AudioPlayer _player = AudioPlayer(playerId: 'notification_pop');
  final AppNotificationService _notificationService = AppNotificationService();

  bool _initialized = false;
  Future<void>? _initFuture;

  Future<bool> isSoundEnabled() =>
      _notificationService.isNotificationsEnabled();

  /// One-time setup: low-latency mode + preload the asset bytes so the
  /// very first `playPopIfEnabled()` call doesn't have to resolve the
  /// asset from scratch. Safe to call multiple times (idempotent).
  Future<void> _ensureInit() {
    if (_initialized) return Future.value();
    // Guard against concurrent callers all kicking off init at once.
    return _initFuture ??= () async {
      try {
        await _player.setPlayerMode(PlayerMode.lowLatency);
        await _player.setReleaseMode(ReleaseMode.stop);
        await _player.setSourceAsset(_assetPath);
        _initialized = true;
      } catch (e) {
        debugPrint('NotificationSoundService: init failed: $e');
        // Leave _initialized false so the next call retries init.
        _initFuture = null;
      }
    }();
  }

  Future<void> playPopIfEnabled() async {
    try {
      if (!await isSoundEnabled()) {
        // Not a bug/failure — the user (or admin) has explicitly turned
        // off notifications in Settings, which mutes both this pop
        // sound AND the OS tray notification (see
        // AppNotificationService.isNotificationsEnabled — same single
        // flag drives both). Logged so "no sound" reports can be told
        // apart at a glance from a genuine playback failure below.
        debugPrint(
            'NotificationSoundService: skipped — notificationsEnabled is false for this account');
        return;
      }
      await _ensureInit();
      // resume() replays the already-loaded source from the start —
      // faster and more reliable than calling play(AssetSource(...))
      // fresh every time, and avoids the stop()/play() race that could
      // cut a sound short when two notifications arrive back-to-back.
      await _player.seek(Duration.zero);
      await _player.resume();
    } catch (e) {
      // Sound is best-effort and must never block notification
      // delivery/display — but log it so failures are diagnosable
      // instead of silently invisible.
      debugPrint('NotificationSoundService: playPopIfEnabled failed: $e');
      // One retry attempt using the simple one-shot API, in case the
      // preloaded source got into a bad state (e.g. after an
      // interruption) — still best-effort, still swallowed on failure.
      try {
        await _player.play(AssetSource(_assetPath));
      } catch (e2) {
        debugPrint('NotificationSoundService: fallback play failed: $e2');
      }
    }
  }
}
