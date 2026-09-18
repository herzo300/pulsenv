// lib/services/rain_radar_service.dart
//
// Радар осадков RainViewer (бесплатный, реальные радарные данные).
// Отдаёт шаблон тайлового слоя последнего кадра для flutter_map.

import 'dart:convert';
import 'package:http/http.dart' as http;

class RainRadarService {
  RainRadarService._();
  static final RainRadarService instance = RainRadarService._();

  static const _timelineUrl =
      'https://api.rainviewer.com/public/weather-maps.json';

  String? _cachedTemplate;
  DateTime? _cachedAt;

  /// Шаблон вида https://tilecache.rainviewer.com/v2/radar/<ts>/256/{z}/{x}/{y}/2/1_1.png
  /// Кэш 10 минут (кадры радара обновляются раз в 10 минут).
  Future<String?> getLatestTileTemplate() async {
    final now = DateTime.now();
    if (_cachedTemplate != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < const Duration(minutes: 10)) {
      return _cachedTemplate;
    }
    try {
      final res = await http
          .get(Uri.parse(_timelineUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _cachedTemplate;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final radar = data['radar'] as Map<String, dynamic>?;
      final past = radar?['past'] as List<dynamic>?;
      if (past == null || past.isEmpty) return _cachedTemplate;
      final last = past.last as Map<String, dynamic>;
      final path = last['path'] as String?;
      if (path == null) return _cachedTemplate;
      final host = (data['host'] as String?) ?? 'https://tilecache.rainviewer.com';
      // color scheme 2 (Universal Blue), smooth+snow: 1_1
      _cachedTemplate = '$host$path/256/{z}/{x}/{y}/2/1_1.png';
      _cachedAt = now;
      return _cachedTemplate;
    } catch (_) {
      return _cachedTemplate;
    }
  }
}
