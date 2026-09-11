import 'package:shared_preferences/shared_preferences.dart';

/// Gates the dismissible "how Baby Health Tracker works" info banner
/// shown at the top of the Baby Profiles (list) screen.
///
/// Same one-time-ever behavior as [ShopIntroBannerService]: it shows the
/// first time the user opens the screen, and once they tap the close (×)
/// button it never shows again on that device.
class BabyTrackerIntroBannerService {
  BabyTrackerIntroBannerService._();

  static const _prefsKey = 'baby_tracker_intro_banner_dismissed';

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
