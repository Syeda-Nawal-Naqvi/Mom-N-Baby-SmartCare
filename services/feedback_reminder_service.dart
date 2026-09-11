import 'package:shared_preferences/shared_preferences.dart';

/// Gates the "Send us feedback" banner shown on HomeScreen.
///
/// There is no backend/FCM in this app (see pubspec.yaml notes on
/// flutter_local_notifications), so a real push notification "even when
/// the app is closed" isn't possible without a paid backend. This is the
/// zero-cost equivalent the user actually asked for: an automatic prompt
/// that shows itself, at most once every 7 days, the moment the app is
/// opened — no button press needed to trigger it.
class FeedbackReminderService {
  FeedbackReminderService._();

  static const _prefsKey = 'feedback_reminder_last_shown_at';
  static const Duration _interval = Duration(days: 7);

  /// True if it's been 7+ days (or never) since the banner last showed.
  /// Does NOT mark it as shown — call [markShownNow] only once the
  /// banner has actually been displayed.
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMillis = prefs.getInt(_prefsKey);
    if (lastMillis == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    return DateTime.now().difference(last) >= _interval;
  }

  static Future<void> markShownNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, DateTime.now().millisecondsSinceEpoch);
  }
}
