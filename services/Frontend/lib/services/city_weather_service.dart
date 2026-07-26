import 'dart:convert';

import 'package:http/http.dart' as http;

import '../map/map_config.dart';
import 'city_provider.dart';

class CityWeatherSnapshot {
  const CityWeatherSnapshot({
    required this.available,
    required this.temperatureC,
    required this.feelsLikeC,
    required this.condition,
    required this.kind,
    required this.humidityPct,
    required this.windSpeedMs,
    required this.windGustsMs,
    required this.isDay,
    required this.airQualityLevel,
    required this.airQualitySummary,
    required this.europeanAqi,
    this.pressureMmHg,
    this.solarFlare,
    this.schumannFreqHz,
    this.schumannAmpPt,
    this.seismicMagnitude,
    this.seismicDescription,
    this.kpIndex,
    this.uvIndex,
    this.visibilityM,
    this.moonPhase,
    this.moonPhaseName,
    this.moonPhaseDesc,
    this.moonInfluencePct,
  });

  final bool available;
  final double? temperatureC;
  final double? feelsLikeC;
  final String condition;
  final String kind;
  final int? humidityPct;
  final double? windSpeedMs;
  final double? windGustsMs;
  final bool isDay;
  final String airQualityLevel;
  final String airQualitySummary;
  final num? europeanAqi;
  final double? pressureMmHg;
  final String? solarFlare;
  final double? schumannFreqHz;
  final double? schumannAmpPt;
  final double? seismicMagnitude;
  final String? seismicDescription;
  final double? kpIndex;
  final double? uvIndex;
  final double? visibilityM;
  final double? moonPhase;
  final String? moonPhaseName;
  final String? moonPhaseDesc;
  final double? moonInfluencePct;

  factory CityWeatherSnapshot.empty() => const CityWeatherSnapshot(
        available: false,
        temperatureC: null,
        feelsLikeC: null,
        condition: 'Нет данных',
        kind: 'cloudy',
        humidityPct: null,
        windSpeedMs: null,
        windGustsMs: null,
        isDay: true,
        airQualityLevel: 'нет данных',
        airQualitySummary: '',
        europeanAqi: null,
        pressureMmHg: null,
        solarFlare: null,
        schumannFreqHz: null,
        schumannAmpPt: null,
        seismicMagnitude: null,
        seismicDescription: null,
        kpIndex: null,
        uvIndex: null,
        visibilityM: null,
        moonPhase: null,
        moonPhaseName: null,
        moonPhaseDesc: null,
        moonInfluencePct: null,
      );

  factory CityWeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final aq = json['air_quality'] as Map<String, dynamic>? ?? const {};
    return CityWeatherSnapshot(
      available: json['available'] == true,
      temperatureC: _toDouble(json['temperature_c']),
      feelsLikeC: _toDouble(json['feels_like_c']),
      condition: '${json['condition'] ?? 'Погода'}',
      kind: '${json['kind'] ?? 'cloudy'}',
      humidityPct: _toInt(json['humidity_pct']),
      windSpeedMs: _toDouble(json['wind_speed_ms']),
      windGustsMs: _toDouble(json['wind_gusts_ms']),
      isDay: json['is_day'] != false && json['is_day'] != 0,
      airQualityLevel: '${aq['level'] ?? 'нет данных'}',
      airQualitySummary: '${aq['summary'] ?? ''}',
      europeanAqi: aq['european_aqi'] as num?,
      pressureMmHg: _toDouble(json['pressure_mm_hg']),
      solarFlare: json['solar_flare'] != null ? '${json['solar_flare']}' : null,
      schumannFreqHz: _toDouble(json['schumann_freq_hz']),
      schumannAmpPt: _toDouble(json['schumann_amp_pt']),
      seismicMagnitude: _toDouble(json['seismic_magnitude']),
      seismicDescription: json['seismic_description'] != null ? '${json['seismic_description']}' : null,
      kpIndex: _toDouble(json['kp_index']),
      uvIndex: _toDouble(json['uv_index']),
      visibilityM: _toDouble(json['visibility_m']),
      moonPhase: _toDouble(json['moon_phase']),
      moonPhaseName: json['moon_phase_name'] != null ? '${json['moon_phase_name']}' : null,
      moonPhaseDesc: json['moon_phase_desc'] != null ? '${json['moon_phase_desc']}' : null,
      moonInfluencePct: _toDouble(json['moon_influence_pct']),
    );
  }

  static double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse('$v');

  static int? _toInt(dynamic v) => v == null ? null : int.tryParse('$v');
}

class CityAlertTickerData {
  const CityAlertTickerData({
    required this.marquee,
    required this.weatherMarquee,
    required this.cityMarquee,
    required this.hasHighSeverity,
    required this.items,
  });

  final String marquee;
  final String weatherMarquee;
  final String cityMarquee;
  final bool hasHighSeverity;
  final List<Map<String, dynamic>> items;

  factory CityAlertTickerData.empty() => const CityAlertTickerData(
        marquee: '',
        weatherMarquee: '',
        cityMarquee: '',
        hasHighSeverity: false,
        items: [],
      );

  factory CityAlertTickerData.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
    final high = items.any((i) => '${i['severity']}' == 'high');
    return CityAlertTickerData(
      marquee: '${json['marquee'] ?? ''}',
      weatherMarquee: '${json['weather_marquee'] ?? ''}',
      cityMarquee: '${json['city_marquee'] ?? ''}',
      hasHighSeverity: high,
      items: items,
    );
  }
}

class CityWeatherService {
  CityWeatherService._();
  static final CityWeatherService instance = CityWeatherService._();

  Future<CityWeatherSnapshot> fetchWeather() async {
    if (!MapConfig.hasBackendConfig) return CityWeatherSnapshot.empty();
    try {
      final cityId = CityProvider().activeCity.id;
      final response = await http
          .get(Uri.parse('${MapConfig.backendApiBaseUrl}/weather/current?city=$cityId'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return CityWeatherSnapshot.empty();
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return CityWeatherSnapshot.fromJson(json);
    } catch (_) {
      return CityWeatherSnapshot.empty();
    }
  }

  Future<CityAlertTickerData> fetchAlerts() async {
    if (!MapConfig.hasBackendConfig) return CityAlertTickerData.empty();
    try {
      final cityId = CityProvider().activeCity.id;
      final response = await http
          .get(Uri.parse('${MapConfig.backendApiBaseUrl}/alerts/ticker?city=$cityId'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return CityAlertTickerData.empty();
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return CityAlertTickerData.fromJson(json);
    } catch (_) {
      return CityAlertTickerData.empty();
    }
  }

  Future<String?> fetchSkyColor() async {
    if (!MapConfig.hasBackendConfig) return null;
    try {
      final response = await http
          .get(Uri.parse('${MapConfig.backendApiBaseUrl}/weather/sky-color'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (json['success'] == true && json['hex'] != null) {
        return json['hex'] as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
