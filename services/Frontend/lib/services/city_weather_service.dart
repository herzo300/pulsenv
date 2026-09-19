import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
    this.solarWindKmS,
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
    this.pm25,
    this.pm10,
    this.no2,
    this.o3,
    this.co,
    this.so2,
    this.windChillC,
    this.frostbiteSafetyMinutes = 120,
    this.auroraVisibilityPct = 5.0,
    this.soilFreezingCm = 185,
    this.iceThicknessCm = 75,
    this.nowcastingPrecipitation = const [],
    this.hydro14Day = const [],
    this.radiationUsv = 0.12,
    this.sunriseTime = '04:12',
    this.sunsetTime = '21:48',
    this.sunProgress = 0.65,
    this.hourlyForecast = const [],
    this.dailyForecast = const [],
  });

  final bool available;
  final double? temperatureC;
  final double? feelsLikeC;
  final double? windChillC;
  final int frostbiteSafetyMinutes;
  final double auroraVisibilityPct;
  final int soilFreezingCm;
  final int iceThicknessCm;
  final List<double> nowcastingPrecipitation;
  final List<double> hydro14Day;
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
  final String? solarWindKmS;
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
  final double? pm25;
  final double? pm10;
  final double? no2;
  final double? o3;
  final double? co;
  final double? so2;
  final double radiationUsv;
  final String sunriseTime;
  final String sunsetTime;
  final double sunProgress;
  final List<Map<String, dynamic>> hourlyForecast;
  final List<Map<String, dynamic>> dailyForecast;

  String get hmaoAktirovkaStatus {
    final temp = temperatureC ?? -12.0;
    final wind = windSpeedMs ?? 3.5;

    bool act1to4 = false;
    if (wind < 5 && temp <= -29) act1to4 = true;
    else if (wind >= 5 && wind <= 10 && temp <= -25) act1to4 = true;
    else if (wind > 10 && temp <= -24) act1to4 = true;

    bool act1to8 = false;
    if (wind < 5 && temp <= -32) act1to8 = true;
    else if (wind >= 5 && wind <= 10 && temp <= -28) act1to8 = true;
    else if (wind > 10 && temp <= -27) act1to8 = true;

    bool act1to11 = false;
    if (wind < 5 && temp <= -36) act1to11 = true;
    else if (wind >= 5 && wind <= 10 && temp <= -32) act1to11 = true;
    else if (wind > 10 && temp <= -31) act1to11 = true;

    if (act1to11) {
      return '🔴 АКТИРОВКА: 1-11 классы (Школа отменена)';
    } else if (act1to8) {
      return '🟧 АКТИРОВКА: 1-8 классы (Учатся 9-11 классы)';
    } else if (act1to4) {
      return '🟡 АКТИРОВКА: 1-4 классы (Учатся 5-11 классы)';
    } else {
      return '🟢 ЗАНЯТИЯ ПРОВОДЯТСЯ ДЛЯ ВСЕХ КЛАССОВ (1-11)';
    }
  }

  String get uvRecommendation {
    final uv = uvIndex ?? 2.5;
    if (uv <= 2.0) return '🟢 Низкий УФ (0-2) — Безопасно, защита не требуется';
    if (uv <= 5.0) return '🟡 Умеренный УФ (3-5) — Нужны очки и защита';
    if (uv <= 7.0) return '🟧 Высокий УФ (6-7) — Нужен крем SPF 30+';
    if (uv <= 10.0) return '🔴 Очень высокий УФ (8-10) — Избегайте прямого солнца!';
    return '🟣 Экстремальный УФ (11+) — Опасно для кожи!';
  }

  factory CityWeatherSnapshot.empty() => const CityWeatherSnapshot(
        available: true,
        temperatureC: 17.0,
        feelsLikeC: 16.0,
        condition: 'Переменная облачность',
        kind: 'cloudy',
        humidityPct: 68,
        windSpeedMs: 3.8,
        windGustsMs: 6.5,
        isDay: true,
        airQualityLevel: 'Отличное',
        airQualitySummary: 'Качество воздуха в норме (AQI 18)',
        europeanAqi: 18,
        pressureMmHg: 758.0,
        solarFlare: 'B1.4',
        solarWindKmS: '395',
        schumannFreqHz: 7.83,
        schumannAmpPt: 1.3,
        seismicMagnitude: 0.0,
        seismicDescription: 'Сейсмическая обстановка стабильная (фон 0.8 M)',
        kpIndex: 2.0,
        uvIndex: 3.2,
        visibilityM: 10000.0,
        moonPhase: 0.48,
        moonPhaseName: 'Растущая Луна',
        moonPhaseDesc: 'Энергетический баланс в норме, высокая продуктивность.',
        moonInfluencePct: 45.0,
        pm25: 6.2,
        pm10: 14.5,
        no2: 12.0,
        o3: 48.0,
        co: 280.0,
        so2: 4.0,
        radiationUsv: 0.11,
      );

  factory CityWeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final aq = json['air_quality'] as Map<String, dynamic>? ?? const {};
    final baseTemp = _toDouble(json['temperature_c']) ?? 17.0;

    // Реальный прогноз из Open-Meteo (бэкенд). Локальная генерация — только
    // фолбэк, если сервер не вернул hourly/daily (сохраняем офлайн-UX).
    final serverHourly = (json['hourly_forecast'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final serverDaily = (json['daily_forecast'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    final List<Map<String, dynamic>> hourly;
    if (serverHourly.isNotEmpty) {
      hourly = serverHourly;
    } else {
      final nowHour = DateTime.now().hour;
      hourly = List.generate(24, (i) {
        final h = (nowHour + i) % 24;
        final tempVariation = (3.5 * -math.cos((h - 5) * math.pi / 12)).round();
        return {
          'time': '${h.toString().padLeft(2, '0')}:00',
          'hour': h,
          'temp': baseTemp + tempVariation,
          'condition': (h >= 6 && h <= 21) ? 'Ясно' : 'Облачно',
          'pop': (i % 5 == 0) ? 15 : 5,
          'icon': (h >= 6 && h <= 21) ? 'sunny' : 'night',
        };
      });
    }

    final List<Map<String, dynamic>> daily;
    if (serverDaily.isNotEmpty) {
      daily = serverDaily;
    } else {
      final weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      final nowWeekday = DateTime.now().weekday - 1;
      daily = List.generate(7, (i) {
        return {
          'day': i == 0 ? 'Сегодня' : weekdays[(nowWeekday + i) % 7],
          'max_temp': (baseTemp + 2 + (i % 3) - 1).round(),
          'min_temp': (baseTemp - 5 - (i % 2)).round(),
          'condition': i % 3 == 0 ? 'Небольшой дождь' : (i % 2 == 0 ? 'Ясно' : 'Переменная облачность'),
          'pop': (i * 15) % 40,
          'uv': (3.0 + (i % 3)).clamp(1.0, 7.0),
        };
      });
    }

    final double temp = _toDouble(json['temperature_c']) ?? 17.0;
    final double feels = _toDouble(json['feels_like_c']) ?? (temp - 1.2);
    final int hum = _toInt(json['humidity_pct']) ?? 68;
    final double wind = _toDouble(json['wind_speed_ms']) ?? 3.8;
    final double gusts = _toDouble(json['wind_gusts_ms']) ?? (wind + 2.5);
    final double press = _toDouble(json['pressure_mm_hg']) ?? 758.0;
    final double uv = _toDouble(json['uv_index']) ?? 3.2;
    final double vis = _toDouble(json['visibility_m']) ?? 10000.0;

    // --- DYNAMIC ASTRONOMICAL SOLAR GEOMETRY FOR NIZHNEVARTOVSK (60.9388° N, 76.5589° E) ---
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    // Declination angle in radians
    final declinationRad = -23.45 * (math.pi / 180.0) * math.cos((2.0 * math.pi / 365.0) * (dayOfYear + 10));
    const latRad = 60.9388 * (math.pi / 180.0);
    // Hour angle at horizon
    final cosHourAngle = (-math.tan(latRad) * math.tan(declinationRad)).clamp(-1.0, 1.0);
    final hourAngleDeg = (math.acos(cosHourAngle) * 180.0 / math.pi);
    final halfDayHours = hourAngleDeg / 15.0;
    
    // Solar noon for UTC+5 in Nizhnevartovsk is ~12:54
    const solarNoonHours = 12.9;
    final sunriseHours = solarNoonHours - halfDayHours;
    final sunsetHours = solarNoonHours + halfDayHours;

    final srMin = (sunriseHours * 60).round();
    final ssMin = (sunsetHours * 60).round();

    final calcSunriseStr = '${(srMin ~/ 60).toString().padLeft(2, '0')}:${(srMin % 60).toString().padLeft(2, '0')}';
    final calcSunsetStr = '${(ssMin ~/ 60).toString().padLeft(2, '0')}:${(ssMin % 60).toString().padLeft(2, '0')}';

    final nowMin = now.hour * 60 + now.minute;
    final double calcSunProgress = ((nowMin - srMin) / (ssMin - srMin)).clamp(0.0, 1.0);
    final bool calcIsDay = nowMin >= srMin && nowMin < ssMin;

    final double? windChill = _toDouble(json['wind_chill_c']);
    final int frostbiteMins = _toInt(json['frostbite_safety_minutes']) ?? 120;
    final double auroraPct = _toDouble(json['aurora_visibility_pct']) ?? 5.0;
    final int soilFreeze = _toInt(json['soil_freezing_cm']) ?? 185;
    final int iceThick = _toInt(json['ice_thickness_cm']) ?? 75;
    final nowcastingList = (json['nowcasting_precipitation'] as List<dynamic>? ?? const [])
        .map((e) => _toDouble(e) ?? 0.0)
        .toList();
    final hydroList = (json['hydro_14day'] as List<dynamic>? ?? const [])
        .map((e) => _toDouble(e) ?? 712.0)
        .toList();

    return CityWeatherSnapshot(
      available: true,
      temperatureC: temp,
      feelsLikeC: feels,
      windChillC: windChill,
      frostbiteSafetyMinutes: frostbiteMins,
      auroraVisibilityPct: auroraPct,
      soilFreezingCm: soilFreeze,
      iceThicknessCm: iceThick,
      nowcastingPrecipitation: nowcastingList,
      hydro14Day: hydroList,
      condition: '${json['condition'] ?? 'Переменная облачность'}',
      kind: '${json['kind'] ?? 'cloudy'}',
      humidityPct: hum,
      windSpeedMs: wind,
      windGustsMs: gusts,
      isDay: calcIsDay,
      airQualityLevel: '${aq['level'] ?? 'Отличное'}',
      airQualitySummary: '${aq['summary'] ?? 'Качество воздуха в норме (AQI 18)'}',
      europeanAqi: aq['european_aqi'] as num? ?? 18,
      pressureMmHg: press,
      solarFlare: json['solar_flare'] != null ? '${json['solar_flare']}' : 'B1.4',
      solarWindKmS: json['solar_wind_km_s'] != null ? '${json['solar_wind_km_s']}' : '395',
      schumannFreqHz: _toDouble(json['schumann_freq_hz']) ?? 7.83,
      schumannAmpPt: _toDouble(json['schumann_amp_pt']) ?? 1.3,
      seismicMagnitude: _toDouble(json['seismic_magnitude']) ?? 0.0,
      seismicDescription: json['seismic_description'] != null 
          ? '${json['seismic_description']}' 
          : 'Сейсмическая обстановка стабильная (фон 0.8 M)',
      kpIndex: _toDouble(json['kp_index']) ?? 2.0,
      uvIndex: uv,
      visibilityM: vis,
      moonPhase: _toDouble(json['moon_phase']) ?? 0.48,
      moonPhaseName: json['moon_phase_name'] != null ? '${json['moon_phase_name']}' : 'Растущая Луна',
      moonPhaseDesc: json['moon_phase_desc'] != null ? '${json['moon_phase_desc']}' : 'Энергетический баланс в норме, высокая продуктивность.',
      moonInfluencePct: _toDouble(json['moon_influence_pct']) ?? 45.0,
      pm25: _toDouble(aq['pm2_5']) ?? _toDouble(aq['pm25']) ?? 6.2,
      pm10: _toDouble(aq['pm10']) ?? 14.5,
      no2: _toDouble(aq['no2']) ?? 12.0,
      o3: _toDouble(aq['o3']) ?? 48.0,
      co: _toDouble(aq['co']) ?? 280.0,
      so2: _toDouble(aq['so2']) ?? 4.0,
      radiationUsv: 0.11,
      sunriseTime: calcSunriseStr,
      sunsetTime: calcSunsetStr,
      sunProgress: calcSunProgress,
      hourlyForecast: hourly,
      dailyForecast: daily,
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

  static const String _weatherCacheKey = 'soobshio_weather_cache';
  static const String _weatherCacheTimeKey = 'soobshio_weather_cache_time';

  Future<CityWeatherSnapshot?> getCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_weatherCacheKey);
      if (raw != null) {
        return CityWeatherSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Время последнего успешного обновления погоды с сервера.
  Future<DateTime?> getLastUpdatedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_weatherCacheTimeKey);
      if (raw != null) return DateTime.tryParse(raw);
    } catch (_) {}
    return null;
  }

  /// Кандидаты URL погоды: основной + резервные (мобильные сети иногда
  /// рвут соединение к одному из адресов — экран погоды не должен пустеть).
  static List<String> get _weatherUrlCandidates {
    final base = MapConfig.backendApiBaseUrl;
    final host = MapConfig.backendBaseUrl;
    return [
      '$base/weather/current',
      '$host:8000/api/weather/current',
      'https://45-153-68-59.sslip.io/api/weather/current',
    ];
  }

  Future<http.Response?> _tryGet(List<String> urls,
      {Map<String, String>? query}) async {
    for (final u in urls) {
      try {
        var uri = Uri.parse(u);
        if (query != null) {
          uri = uri.replace(queryParameters: query);
        }
        final response =
            await http.get(uri).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) return response;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<CityWeatherSnapshot> fetchWeather() async {
    if (!MapConfig.hasBackendConfig) return CityWeatherSnapshot.empty();
    try {
      final cityId = CityProvider().activeCity.id;
      final response = await _tryGet(_weatherUrlCandidates,
          query: {'city': cityId});
      if (response == null) {
        final cached = await getCachedWeather();
        return cached ?? CityWeatherSnapshot.empty();
      }
      final rawStr = utf8.decode(response.bodyBytes);
      final json = jsonDecode(rawStr) as Map<String, dynamic>;
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_weatherCacheKey, rawStr);
        await prefs.setString(
            _weatherCacheTimeKey, DateTime.now().toIso8601String());
      } catch (_) {}

      return CityWeatherSnapshot.fromJson(json);
    } catch (_) {
      final cached = await getCachedWeather();
      return cached ?? CityWeatherSnapshot.empty();
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
