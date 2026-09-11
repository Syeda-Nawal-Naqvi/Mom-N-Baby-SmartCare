import 'package:shared_preferences/shared_preferences.dart';

/// Gates the dismissible "you'll be redirected to our partner store" info
/// banner shown at the top of the Shop screen.
///
/// Unlike [FeedbackReminderService] (which re-shows every 7 days), this is
/// a one-time-ever banner: it shows the first time the user opens the Shop
/// screen, and once they tap the close (×) button it never shows again on
/// that device.
class ShopIntroBannerService {
  ShopIntroBannerService._();

  static const _prefsKey = 'shop_intro_banner_dismissed';

  /// True if the banner has NOT been dismissed yet (i.e. it should show).
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefsKey) ?? false);
  }

  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }
}
