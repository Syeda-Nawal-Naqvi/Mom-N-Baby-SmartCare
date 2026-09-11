import 'package:shared_preferences/shared_preferences.dart';

/// Gates the dismissible "Every registered user, grouped by role..." info
/// banner shown at the top of the Admin dashboard's Accounts section.
///
/// Shows once ever; once the admin taps the close (×) button it never
/// shows again on that device — same pattern as ShopIntroBannerService.
class AdminIntroBannerService {
  AdminIntroBannerService._();

  static const _prefsKey = 'admin_dashboard_intro_banner_dismissed';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefsKey) ?? false);
  }

  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }
}
