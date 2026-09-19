import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  static const _dailyNewKey = 'daily_new_count';
  static const _dailyReviewKey = 'daily_review_count';

  static Future<int> dailyNew() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyNewKey) ?? 10;
  }

  static Future<int> dailyReview() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyReviewKey) ?? 10;
  }

  static Future<void> setDailyNew(int n) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyNewKey, n);
  }

  static Future<void> setDailyReview(int n) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyReviewKey, n);
  }
}
