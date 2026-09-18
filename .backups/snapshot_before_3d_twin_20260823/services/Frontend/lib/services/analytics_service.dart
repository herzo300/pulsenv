import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  AnalyticsService._();

  static const String _prefix = 'analytics_event_';

  /// Track a conversion or custom action event
  static Future<void> trackEvent(String eventName) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = '$_prefix$eventName';
    final count = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, count + 1);
  }

  /// Get the total count of a specific event
  static Future<int> getEventCount(String eventName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$eventName') ?? 0;
  }

  /// Reset all analytics data
  static Future<void> resetAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Get structured funnel data for visual charts
  static Future<List<Map<String, dynamic>>> getFunnelData() async {
    final int opens = await getEventCount('app_open');
    final int started = await getEventCount('complaint_started');
    final int submitted = await getEventCount('complaint_submitted');
    final int shares = await getEventCount('share_success');

    // Ensure we have a baseline (minimum of 1 to avoid division by zero)
    final baseline = opens == 0 ? 1 : opens;

    return [
      {
        'name': 'Просмотры карты',
        'count': opens,
        'percent': 100.0,
      },
      {
        'name': 'Начало сигнала',
        'count': started,
        'percent': opens == 0 ? 0.0 : (started / baseline * 100.0).clamp(0.0, 100.0),
      },
      {
        'name': 'Успешная подача',
        'count': submitted,
        'percent': opens == 0 ? 0.0 : (submitted / baseline * 100.0).clamp(0.0, 100.0),
      },
      {
        'name': 'Шеринг сигнала',
        'count': shares,
        'percent': opens == 0 ? 0.0 : (shares / baseline * 100.0).clamp(0.0, 100.0),
      },
    ];
  }
}
