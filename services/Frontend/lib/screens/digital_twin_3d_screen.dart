import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../map/map_config.dart';
import 'webgl/webgl_twin_screen.dart';

/// Интерактивный 3D/4D цифровой двойник Нижневартовска.
/// Единая изометрическая сцена из реальных полигонов зданий (OSM-типология),
/// солнечные тени по астрономии 60.9°N, дневной цикл, паводок, снег,
/// факелы Самотлора и тайм-машина 2015→2026.
class DigitalTwin3DScreen extends StatefulWidget {
  const DigitalTwin3DScreen({super.key});

  @override
  State<DigitalTwin3DScreen> createState() => _DigitalTwin3DScreenState();
}

// ---------------------------------------------------------------------------
// Данные
// ---------------------------------------------------------------------------

class _Bld {
  _Bld(this.ring, this.holes, this.zBottom, this.zTop, this.color, this.name,
      this.category, this.address, this.seed, this.facadePalette);
  final List<Offset> ring; // локальные метры (x=восток, y=север)
  final List<List<Offset>> holes;
  final double zBottom, zTop;
  final Color color;
  final String name, category, address;
  final double seed;
  /// Палитра фасада от Гермеса (изучена по фото камер/OSM), может быть null
  final List<Color>? facadePalette;
  late final Offset center = _ringCenter(ring);
  late final double radius = _ringRadius(ring, center);

  static Offset _ringCenter(List<Offset> r) {
    double sx = 0, sy = 0;
    for (final p in r) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / r.length, sy / r.length);
  }

  static double _ringRadius(List<Offset> r, Offset c) {
    double m = 0;
    for (final p in r) {
      m = math.max(m, (p - c).distance);
    }
    return m;
  }
}

class _Landmark {
  _Landmark(this.name, this.x, this.y, this.heightM, this.color, this.desc);
  final String name, desc;
  final double x, y, heightM;
  final Color color;
}

class _Cam3D {
  _Cam3D(this.name, this.x, this.y, this.elevationM, this.headingDeg,
      this.fovDeg, this.rangeM, this.status);
  final String name, status;
  final double x, y, elevationM, headingDeg, fovDeg, rangeM;
}

enum _TwinMode { sun, flood, snow, samotlor, time }

// ---------------------------------------------------------------------------
// Экран
// ---------------------------------------------------------------------------

class _DigitalTwin3DScreenState extends State<DigitalTwin3DScreen>
    with TickerProviderStateMixin {
  static const _accent = Color(0xFF00E5FF);
  static const _accent2 = Color(0xFF7DD3FC); // светло-небесный для градиентов
  static const _ok = Color(0xFF34D399);
  static const _warn = Color(0xFFFBBF24);
  static const _danger = Color(0xFFFB7185);
  static const _ink = Color(0xFFEAF6FF); // основной текст
  static const _inkDim = Color(0xFF9DB4CE); // вторичный текст

  bool _isLoading = true;
  String? _error;

  final List<_Bld> _buildings = [];
  final List<_Landmark> _landmarks = [];
  final List<_Cam3D> _cameras = [];
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _floodData;
  Map<String, dynamic>? _solarData;
  Map<String, dynamic>? _snowData;
  Map<String, dynamic>? _flareData;
  List<Map<String, dynamic>> _timeline = [];

  // Камера
  double _azimuth = 0.0; // радианы
  double _zoom = 0.0; // px на метр
  Offset _pan = Offset.zero;
  final double _fitScale = 0.08;
  Rect _worldBounds = Rect.zero;
  Offset _worldCenter = Offset.zero;

  // Режимы
  _TwinMode _mode = _TwinMode.sun;
  double _dayHour = 14.0;
  double _waterLevel = 850;
  int _year = 2026;
  bool _showCameras = true;
  bool _showLandmarks = true;
  bool _autoOrbit = false;
  _Bld? _selected;

  // Анимация. Вода/лес/погода живут на времени painter'а: тик всегда
  // включён, но setState дёргается только для режимов с ростом зданий и
  // автооблётом — в статике кадр перерисовывается без перестройки виджетов.
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 20))
        ..addListener(() {
          if (!mounted) return;
          if (_growthT < 1 || _autoOrbit) {
            setState(() {});
          } else {
            // лёгкая перерисовка сцены (CustomPaint rebuild без setState
            // всего дерева) — река/дымка продолжают жить
            _sceneRepaint.value++;
          }
        });
  final ValueNotifier<int> _sceneRepaint = ValueNotifier<int>(0);
  double _growthT = 1.0; // 0..1 рост зданий (тайм-машина)
  double _growthStart = 0.0; // msec timestamp

  // Жесты
  double _gestureStartZoom = 0;
  double _gestureStartAzimuth = 0;
  Offset _gestureStartPan = Offset.zero;

  // Солнце
  final Map<int, Map<String, dynamic>> _solarCache = {};
  Timer? _solarDebounce;
  double _sunAzimuthRad = math.pi; // куда светит
  double _sunElevation = 35.0;

  // Ландшафт
  _Landscape? _landscape;
  final List<_TwinSignal> _signals = [];

  // Реалтайм-погода сцены (astra §1)
  final TwinWeather _weather = TwinWeather.empty();
  TwinWeather? _weatherTarget;
  double _lastWeatherTick = 0;

  // Полноэкранный режим: HUD скрыт, сцена на весь экран
  bool _isImmersive = false;

  // Hit-test пути последнего кадра
  final List<MapEntry<Path, _Bld>> _roofHits = [];
  // Хит-зоны сигналов последнего кадра (экранные круги)
  final List<MapEntry<Offset, _TwinSignal>> _signalHits = [];

  // Автозум-пролёт камеры к сигналу: плавная анимация pan/zoom
  void _flyToSignal(_TwinSignal s) {
    // Целевой зум: различимая детализация (~x8 от стартового вида)
    final size = context.size;
    if (size == null) return;
    final targetZoom = (_fitScaleFor(size) * 9)
        .clamp(_fitScaleFor(size) * 2, _fitScaleFor(size) * 34);
    final startZoom = _zoom;
    final startPan = _pan;
    final startAz = _azimuth;
    // Проекция сигнала при целевых pan=0: куда надо сместить pan,
    // чтобы сигнал оказался в центре экрана.
    final c = math.cos(startAz), sn = math.sin(startAz);
    final xr = s.x * c - s.y * sn;
    final yr = s.x * sn + s.y * c;
    // screen = size/2 + pan + iso(xr,yr)*zoom → pan = -iso(...)
    final isoX = (xr - yr) * 0.8660254 * targetZoom;
    final isoY = (-(xr + yr) * 0.5) * targetZoom;
    final targetPan = Offset(-isoX, -isoY + size.height * 0.12);

    final dur = const Duration(milliseconds: 1200);
    final startTime = DateTime.now();
    _clock.repeat();
    Timer? flyTimer;
    flyTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final k = (DateTime.now().difference(startTime).inMilliseconds /
              dur.inMilliseconds)
          .clamp(0.0, 1.0);
      final eased = Curves.easeInOutCubic.transform(k);
      setState(() {
        _zoom = startZoom + (targetZoom - startZoom) * eased;
        _pan = Offset.lerp(startPan, targetPan, eased)!;
      });
      if (k >= 1.0) {
        flyTimer?.cancel();
        _ensureTicker();
      }
    });
  }

  static const _earthR = 6378137.0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _toggleImmersive() async {
    setState(() => _isImmersive = !_isImmersive);
    if (_isImmersive) {
      await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _solarDebounce?.cancel();
    _sceneRepaint.dispose();
    _clock.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final base = MapConfig.backendBaseUrl;
    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('$base/api/v1/3d-twin/buildings'))
            .timeout(const Duration(seconds: 60)),
        http
            .get(Uri.parse('$base/api/v1/3d-twin/landmarks'))
            .timeout(const Duration(seconds: 6)),
        http
            .get(Uri.parse('$base/api/v1/3d-twin/cameras-3d'))
            .timeout(const Duration(seconds: 6)),
        http
            .get(Uri.parse('$base/api/v1/3d-twin/stats'))
            .timeout(const Duration(seconds: 6)),
        http
            .get(Uri.parse('$base/api/v1/3d-twin/snow-intelligence'))
            .timeout(const Duration(seconds: 6)),
        http
            .get(Uri.parse('$base/api/v1/3d-twin/samotlor-flares'))
            .timeout(const Duration(seconds: 6)),
        http
            .get(Uri.parse('$base/api/v1/3d-twin/timeline-4d'))
            .timeout(const Duration(seconds: 6)),
        http
            .get(Uri.parse(
                '$base/api/v1/3d-twin/flood-simulation?water_level_cm=850'))
            .timeout(const Duration(seconds: 6)),
      ]);

      _buildings.clear();
      _landmarks.clear();
      _cameras.clear();

      // 1. Здания → локальные метры
      final bData = jsonDecode(utf8.decode(results[0].bodyBytes));
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      final feats = (bData['features'] as List? ?? []);
      // Первый проход: bbox по внешним кольцам (координаты [lng, lat])
      for (final f in feats) {
        final g = f['geometry'];
        if (g == null) continue;
        List coords = g['coordinates'] as List? ?? [];
        if (g['type'] == 'MultiPolygon') {
          coords = coords.isEmpty ? [] : (coords[0] as List);
        }
        if (coords.isEmpty || coords[0] is! List || (coords[0] as List).isEmpty) {
          continue;
        }
        for (final c in (coords[0] as List)) {
          if (c is! List || c.length < 2) continue;
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          minLat = math.min(minLat, lat);
          maxLat = math.max(maxLat, lat);
          minLng = math.min(minLng, lng);
          maxLng = math.max(maxLng, lng);
        }
      }
      // reproject с центром bbox
      final lat0 = (minLat + maxLat) / 2;
      final lng0 = (minLng + maxLng) / 2;
      final cosLat0 = math.cos(lat0 * math.pi / 180);

      // LOD: при полном городе 10.5k зданий рисуем только значимые
      // (радиус >= 14 м), чтобы сцена держала 60 fps на телефоне
      final bool useLod = feats.length > 2500;
      int seedCounter = 0;
      for (final f in feats) {
        if (useLod) {
          final g0 = f['geometry'];
          final List c0 = (g0?['coordinates'] as List? ?? const []);
          if (c0.isEmpty || c0[0] is! List || (c0[0] as List).length < 3) {
            continue;
          }
          final ring0 = c0[0] as List;
          double mnLat = 90, mxLat = -90, mnLng = 180, mxLng = -180;
          for (final p in ring0) {
            if (p is! List || p.length < 2) continue;
            final la = (p[1] as num).toDouble();
            final lo = (p[0] as num).toDouble();
            mnLat = math.min(mnLat, la); mxLat = math.max(mxLat, la);
            mnLng = math.min(mnLng, lo); mxLng = math.max(mxLng, lo);
          }
          final dLat = (mxLat - mnLat) * 111320;
          final dLng = (mxLng - mnLng) * 111320 * 0.5;
          final radius = math.max(dLat, dLng) / 2;
          if (radius < 14) continue; // гаражи/сараи пропускаем в LOD-режиме
        }
        final g = f['geometry'];
        final props = (f['properties'] as Map).cast<String, dynamic>();
        final double h = (props['render_height'] ?? 12).toDouble();
        final double zMin = (props['render_min_height'] ?? 0).toDouble();
        final color = _parseColor(props['color'], fallback: const Color(0xFF4A90E2));
        final ringSrc = <List<Offset>>[];
        final holeSrc = <List<Offset>>[];
        List coords = g?['coordinates'] as List? ?? [];
        if (g?['type'] == 'MultiPolygon') coords = coords.isEmpty ? [] : coords[0] as List;
        if (coords.isNotEmpty) {
          ringSrc.add(_ringToLocal(coords[0], lng0, lat0, cosLat0));
          for (int i = 1; i < coords.length; i++) {
            holeSrc.add(_ringToLocal(coords[i], lng0, lat0, cosLat0));
          }
        }
        if (ringSrc.isEmpty || ringSrc.first.length < 3) continue;
        seedCounter++;
        // Палитра фасада от Гермеса (изучена по фото)
        List<Color>? hermesPalette;
        final fp = props['facade_palette'];
        if (fp is List && fp.isNotEmpty) {
          hermesPalette = fp
              .map((c) => _parseHexColor(c?.toString()))
              .whereType<Color>()
              .toList();
        }
        _buildings.add(_Bld(
          ringSrc.first,
          holeSrc,
          zMin,
          zMin + h,
          color,
          (props['name'] ?? 'Здание').toString(),
          (props['category'] ?? '').toString(),
          (props['address'] ?? '').toString(),
          (seedCounter * 2654435761 % 4294967296).toDouble(),
          hermesPalette,
        ));
      }

      // 2. Доминанты
      if (results[1].statusCode == 200) {
        final data = jsonDecode(utf8.decode(results[1].bodyBytes));
        for (final lm in (data['items'] as List? ?? [])) {
          final lat = (lm['lat'] as num?)?.toDouble();
          final lng = (lm['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          _landmarks.add(_Landmark(
            lm['name'] ?? '',
            _earthR * (lng - lng0) * math.pi / 180 * cosLat0,
            _earthR * (lat - lat0) * math.pi / 180,
            (lm['height'] ?? 20).toDouble(),
            _parseColor(lm['color'], fallback: _danger),
            lm['description'] ?? '',
          ));
        }
      }

      // 3. Камеры
      if (results[2].statusCode == 200) {
        final data = jsonDecode(utf8.decode(results[2].bodyBytes));
        for (final c in (data['items'] as List? ?? [])) {
          final lat = (c['lat'] as num?)?.toDouble();
          final lng = (c['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          _cameras.add(_Cam3D(
            c['name'] ?? 'Камера',
            _earthR * (lng - lng0) * math.pi / 180 * cosLat0,
            _earthR * (lat - lat0) * math.pi / 180,
            (c['elevation_m'] ?? 15).toDouble(),
            (c['heading_deg'] ?? 0).toDouble(),
            (c['fov_deg'] ?? 75).toDouble(),
            (c['range_m'] ?? 120).toDouble(),
            c['status'] ?? 'online',
          ));
        }
      }

      if (results[3].statusCode == 200) {
        _stats = jsonDecode(utf8.decode(results[3].bodyBytes));
      }
      if (results[4].statusCode == 200) {
        _snowData = jsonDecode(utf8.decode(results[4].bodyBytes));
      }
      if (results[5].statusCode == 200) {
        _flareData = jsonDecode(utf8.decode(results[5].bodyBytes));
      }
      if (results[6].statusCode == 200) {
        _timeline = List<Map<String, dynamic>>.from(
            (jsonDecode(utf8.decode(results[6].bodyBytes))['snapshots'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)));
      }
      if (results[7].statusCode == 200) {
        _floodData = jsonDecode(utf8.decode(results[7].bodyBytes))['data'];
      }

      // Ландшафт: Обь, лес, озёра (грузим параллельно, не блокируя город)
      unawaited(_loadLandscape(lng0, lat0));
      unawaited(_loadSignalsAndRepairs(lng0, lat0));
      // Реалтайм-погода для сцены (astra §1)
      unawaited(_loadWeather());
      // Автообновление зданий: если Гермес обновил реестр — тихо перезагружаем
      unawaited(_checkBuildingsRevision());

      // Границы мира
      double minX = double.infinity,
          minY = double.infinity,
          maxX = double.negativeInfinity,
          maxY = double.negativeInfinity;
      for (final b in _buildings) {
        minX = math.min(minX, b.center.dx - b.radius);
        maxX = math.max(maxX, b.center.dx + b.radius);
        minY = math.min(minY, b.center.dy - b.radius);
        maxY = math.max(maxY, b.center.dy + b.radius);
      }
      if (_buildings.isEmpty) {
        minX = -2000; maxX = 2000; minY = -2000; maxY = 2000;
      }
      _worldBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
      _worldCenter = _worldBounds.center;
      _zoom = _fitScale; // будет пересчитан в build по размеру экрана

      await _fetchSolar(_dayHour);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[DigitalTwin3D] load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Не удалось загрузить модель города';
        });
      }
    }
  }

  List<Offset> _ringToLocal(List ring, double lng0, double lat0, double cosLat0) {
    final out = <Offset>[];
    for (int i = 0; i < ring.length; i++) {
      final c = ring[i];
      if (c is! List || c.length < 2) continue;
      final lng = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      final x = _earthR * (lng - lng0) * math.pi / 180 * cosLat0;
      final y = _earthR * (lat - lat0) * math.pi / 180;
      if (out.isNotEmpty && (out.last.dx - x).abs() < 0.01 && (out.last.dy - y).abs() < 0.01) {
        continue; // вырожденные рёбра
      }
      out.add(Offset(x, y));
    }
    if (out.length > 1 &&
        (out.first - out.last).distance < 0.01) {
      out.removeLast();
    }
    return out;
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var h = hex.trim().replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final i = int.tryParse(h);
    return i == null ? null : Color(i);
  }

  static Color _parseColor(dynamic v, {required Color fallback}) {
    if (v is String && v.length >= 7 && v.startsWith('#')) {
      final hex = v.replaceFirst('#', '0xFF');
      final i = int.tryParse(hex);
      if (i != null) return Color(i);
    }
    return fallback;
  }

  Future<void> _fetchSolar(double hour) async {
    final key = (hour * 4).round(); // шаг 15 минут
    final cached = _solarCache[key];
    if (cached != null) {
      _applySolar(cached);
      return;
    }
    try {
      final resp = await http
          .get(Uri.parse(
              '${MapConfig.backendBaseUrl}/api/v1/3d-twin/solar-shadows?hour=$hour'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes))['data'];
        if (data is Map) {
          _solarCache[key] = Map<String, dynamic>.from(data);
          _applySolar(_solarCache[key]!);
        }
      }
    } catch (_) {}
  }

  void _applySolar(Map<String, dynamic> d) {
    if (!mounted) return;
    setState(() {
      _solarData = d;
      _sunElevation = (d['solar_elevation_deg'] as num?)?.toDouble() ?? 30;
      final azDeg = (d['solar_azimuth_deg'] as num?)?.toDouble() ??
          ((_dayHour - 12) * 15 + 180);
      _sunAzimuthRad = azDeg * math.pi / 180;
    });
  }

  void _onDayHourChanged(double h) {
    setState(() => _dayHour = h);
    _solarDebounce?.cancel();
    _solarDebounce = Timer(const Duration(milliseconds: 200), () {
      _fetchSolar(h);
    });
  }

  Future<void> _onWaterLevelChanged(double cm) async {
    setState(() => _waterLevel = cm);
    try {
      final resp = await http
          .get(Uri.parse(
              '${MapConfig.backendBaseUrl}/api/v1/3d-twin/flood-simulation?water_level_cm=${cm.toInt()}'))
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200 && mounted) {
        setState(() {
          _floodData = jsonDecode(utf8.decode(resp.bodyBytes))['data'];
        });
      }
    } catch (_) {}
  }

  void _onYearChanged(int year) {
    if (year == _year) return;
    setState(() {
      _year = year;
      _growthStart = DateTime.now().millisecondsSinceEpoch.toDouble();
      _growthT = 0;
    });
    if (!_clock.isAnimating) _clock.repeat();
  }

  int? _knownBuildingsRev;

  /// Реалтайм-погода для 3D-города (astra §1): weathercode + ветер с бэкенда
  Future<void> _loadWeather() async {
    try {
      final resp = await http
          .get(Uri.parse('${MapConfig.backendBaseUrl}/api/weather/current'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final cur = data is Map
            ? (data['current'] is Map ? data['current'] as Map : data)
            : <String, dynamic>{};
        final code = (cur['weather_code'] as num?)?.toInt() ?? 0;
        // бэкенд отдаёт wind_speed_ms сразу в м/с
        final wind = (cur['wind_speed_ms'] as num?)?.toDouble() ??
            ((cur['wind_speed_10m'] as num?)?.toDouble() ?? 2.0) / 3.6;
        setState(() {
          _weatherTarget = TwinWeather.fromCode(code, windMps: wind);
        });
        _ensureTicker();
      }
    } catch (e) {
      debugPrint('[Twin] weather load failed: $e');
    }
  }

  /// Плавный переход погоды (astra 1.2): вызывается из build
  void _tickWeather() {
    if (_weatherTarget == null) return;
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final dt =
        _lastWeatherTick == 0 ? 0.05 : (now - _lastWeatherTick).clamp(0.0, 0.05);
    _lastWeatherTick = now;
    _weather.approachTo(_weatherTarget!, dt);
  }

  /// Сверка ревизии реестра зданий (Гермес обновляет каждые 6 ч).
  Future<void> _checkBuildingsRevision() async {
    try {
      final resp = await http
          .get(Uri.parse(
              '${MapConfig.backendBaseUrl}/api/v1/3d-twin/buildings-rev'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return;
      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      final rev = (data['revision'] as num?)?.toInt();
      if (rev == null) return;
      if (_knownBuildingsRev == null) {
        _knownBuildingsRev = rev;
        return;
      }
      if (rev != _knownBuildingsRev && mounted) {
        debugPrint('[Twin] buildings registry updated ($rev), reloading...');
        await _loadAll();
        _knownBuildingsRev = rev;
      }
    } catch (_) {}
  }

  Future<void> _loadSignalsAndRepairs(double lng0, double lat0) async {
    final cosLat = math.cos(lat0 * math.pi / 180);
    Offset toWorld(double lng, double lat) => Offset(
          6378137.0 * (lng - lng0) * math.pi / 180 * cosLat,
          6378137.0 * (lat - lat0) * math.pi / 180,
        );
    try {
      // Сигналы с основной карты
      final feedResp = await http
          .get(Uri.parse('${MapConfig.backendBaseUrl}/api/map/feed'))
          .timeout(const Duration(seconds: 12));
      if (feedResp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(feedResp.bodyBytes));
        // Все сигналы жителей (report-*): и с layer=problems, и без него
        final markers = (data['markers'] as List? ?? [])
            .where((m) =>
                ((m as Map)['id']?.toString() ?? '').startsWith('report'))
            .toList();
        Color catColor(String category) {
          final c = category.toLowerCase();
          if (c.contains('дорог')) return const Color(0xFFF97316);
          if (c.contains('жкх')) return const Color(0xFF38BDF8);
          if (c.contains('эколог') || c.contains('мусор')) return const Color(0xFF22C55E);
          if (c.contains('безопас') || c.contains('чп')) return const Color(0xFFEF4444);
          if (c.contains('животн')) return const Color(0xFFF59E0B);
          if (c.contains('вещ') || c.contains('наход')) return const Color(0xFF10B981);
          if (c.contains('освещ')) return const Color(0xFFEAB308);
          if (c.contains('благоустр') || c.contains('парков')) return const Color(0xFFA78BFA);
          return const Color(0xFF00E5FF);
        }
        if (mounted) {
          setState(() {
            _signals
              ..clear()
              ..addAll(markers.take(80).map((m) {
                final lat = (m['lat'] as num?)?.toDouble() ?? 60.9344;
                final lng = (m['lng'] as num?)?.toDouble() ?? 76.5531;
                return _TwinSignal(
                  toWorld(lng, lat).dx,
                  toWorld(lng, lat).dy,
                  30.0, // высота подвеса маркера
                  catColor((m['category'] ?? '').toString()),
                  (m['title'] ?? 'Сигнал').toString(),
                );
              }));
          });
        }
      }

    } catch (e) {
      debugPrint('[Twin] signals/repairs load failed: $e');
    }
  }

  Future<void> _loadLandscape(double lng0, double lat0) async {
    try {
      final resp = await http
          .get(Uri.parse('${MapConfig.backendBaseUrl}/api/v1/3d-twin/landscape'))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        if (data['status'] == 'ok') {
          setState(() {
            _landscape = _Landscape.fromApi(data, lng0, lat0);
          });
        }
      }
    } catch (e) {
      debugPrint('[Twin] landscape load failed: $e');
    }
  }

  void _resetCamera(Size size) {
    setState(() {
      _azimuth = 0;
      _pan = Offset.zero;
      _zoom = _fitScaleFor(size);
    });
  }

  double _fitScaleFor(Size size) {
    final w = _worldBounds.width + 600;
    final h = _worldBounds.height + 600;
    return math.min(
      (size.width - 48) / (w * 1.73),
      (size.height - 220) / (h * 1.0),
    );
  }

  void _ensureTicker() {
    // Тикер всегда живой: река течёт, вода блестит, закат дышит.
    // Дорогой setState происходит только в активных режимах (см. listener).
    if (!_clock.isAnimating) _clock.repeat();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (_worldBounds != Rect.zero && _zoom <= 0) {
      _zoom = _fitScaleFor(size);
    }
    _ensureTicker();
    _tickWeather();
    // рост зданий
    if (_growthT < 1) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - _growthStart;
      _growthT = (elapsed / 1400).clamp(0.0, 1.0);
      if (_growthT >= 1 && !_autoOrbit &&
          _mode != _TwinMode.snow &&
          _mode != _TwinMode.samotlor &&
          _mode != _TwinMode.flood) {
        _clock.stop();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101E33),
      body: _isLoading
          ? const _Loader()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadAll)
              : SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final sceneSize = Size(constraints.maxWidth, constraints.maxHeight);
                      return Stack(
                        children: [
                          // Сцена
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onScaleStart: (d) => _onScaleStart(d),
                              onScaleUpdate: (d) => _onScaleUpdate(d, sceneSize),
                              onScaleEnd: (_) {},
                              onTapUp: (d) => _onTap(d.localPosition, sceneSize),
                              onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
                              onDoubleTap: () => _onDoubleTap(sceneSize),
                              child: AnimatedBuilder(
                                animation: _sceneRepaint,
                                builder: (context, _) => CustomPaint(
                                painter: _ScenePainter(
                                  buildings: _buildings,
                                  landmarks: _showLandmarks ? _landmarks : [],
                                  cameras: _showCameras ? _cameras : [],
                                  worldCenter: _worldCenter,
                                  worldBounds: _worldBounds,
                                  azimuth: _azimuth,
                                  zoom: _zoom,
                                  pan: _pan,
                                  size: sceneSize,
                                  clockValue: _clock.isAnimating || _growthT < 1
                                      ? _clock.value
                                      : 0,
                                  timeMs:
                                      DateTime.now().millisecondsSinceEpoch.toDouble(),
                                  mode: _mode,
                                  dayHour: _dayHour,
                                  sunAzimuthRad: _sunAzimuthRad,
                                  sunElevation: _sunElevation,
                                  waterLevel: _waterLevel,
                                  year: _year,
                                  growthT: _growthT,
                                  selected: _selected,
                                  roofHits: _roofHits,
                                  signalHits: _signalHits,
                                  flareData: _flareData,
                                  landscape: _landscape,
                                  signals: _signals,
                                ),
                                ),
                              ),
                            ),
                          ),
                          // HUD (в полноэкранном режиме скрыт)
                          if (!_isImmersive) ...[
                            _buildTopBar(),
                            _buildStatsStrip(),
                            if (_selected != null) _buildInspector(),
                            _buildBottomDock(sceneSize),
                          ],
                          if (_isImmersive)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: _iconButton(
                                Icons.close_fullscreen_rounded,
                                'Выйти из полноэкранного режима',
                                _toggleImmersive,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Offset? _doubleTapPos;

  // жест останавливает автооблёт до ручного включения
  void _onScaleStart(ScaleStartDetails d) {
    _gestureStartZoom = _zoom;
    _gestureStartAzimuth = _azimuth;
    _gestureStartPan = _pan;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size size) {
    setState(() {
      _zoom = (_gestureStartZoom * d.scale).clamp(_fitScaleFor(size) * 0.6,
          _fitScaleFor(size) * 34);
      if (d.pointerCount >= 2) {
        _azimuth = _gestureStartAzimuth + d.rotation;
      }
      _pan = _gestureStartPan + d.focalPointDelta;
    });
  }

  void _onTap(Offset pos, Size size) {
    // Сигналы: тап по маркеру — автозум-пролёт к месту сигнала
    for (final entry in _signalHits.reversed) {
      if ((entry.key - pos).distance <= 26) {
        _flyToSignal(entry.value);
        return;
      }
    }
    for (final entry in _roofHits.reversed) {
      if (entry.key.contains(pos)) {
        setState(() => _selected = entry.value);
        return;
      }
    }
    if (_selected != null) setState(() => _selected = null);
  }

  void _onDoubleTap(Size size) {
    if (_doubleTapPos == null) return;
    setState(() {
      _zoom = (_zoom * 1.7).clamp(_fitScaleFor(size) * 0.6, _fitScaleFor(size) * 34);
    });
  }

  // -------------------------------------------------------------------------
  // HUD
  // -------------------------------------------------------------------------

  Widget _buildTopBar() {
    // Кинематографичный командный бар: стеклянная капсула с живым
    // градиентом времени суток и «дыханием» города (taste-skill).
    final hour = _dayHour.floor();
    final (phaseIcon, phaseLabel, glowColor) = hour >= 22 || hour < 5
        ? ('🌙', 'НОЧЬ', const Color(0xFF5B7FA6))
        : (hour < 9
            ? ('🌅', 'УТРО', const Color(0xFFF0A868))
            : (hour < 18
                ? ('☀️', 'ДЕНЬ', const Color(0xFF63C7B2))
                : ('🌇', 'ВЕЧЕР', const Color(0xFFE58B62))));
    return Positioned(
      top: 10,
      left: 14,
      right: 14,
      child: Row(
        children: [
          Expanded(
            child: _glassShell(
              borderRadius: 26,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  // Живой «пульс города»: двойное свечение
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white,
                          _accent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: _accent.withOpacity(0.9), blurRadius: 10),
                        BoxShadow(
                            color: _accent2.withOpacity(0.5), blurRadius: 16),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('$phaseIcon ',
                                style: const TextStyle(fontSize: 11)),
                            const Text('НИЖНЕВАРТОВСК',
                                style: TextStyle(
                                    color: _ink,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 2.4)),
                            const SizedBox(width: 6),
                            Text(phaseLabel,
                                style: TextStyle(
                                    color: glowColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9,
                                    letterSpacing: 1.4)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_buildings.length} зданий · ${_signals.length} сигналов · Обь течёт',
                          style: const TextStyle(
                              color: _inkDim,
                              fontSize: 10,
                              letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Компас: стеклянный циферблат направлений
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1B2F49).withOpacity(0.85),
                  const Color(0xFF0D1626).withOpacity(0.92),
                ],
              ),
              border: Border.all(color: _accent.withOpacity(0.40), width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CustomPaint(painter: _CompassPainter(azimuth: _azimuth)),
          ),
          const SizedBox(width: 8),
          _iconButton(
            _autoOrbit ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
            _autoOrbit ? 'Остановить облёт' : 'Автооблёт',
            () {
              setState(() {
                _autoOrbit = !_autoOrbit;
                if (_autoOrbit) {
                  _clock.repeat();
                } else {
                  _ensureTicker();
                }
              });
            },
          ),
          const SizedBox(width: 8),
          _iconButton(Icons.center_focus_strong_rounded, 'Сброс камеры',
              () => _resetCamera(MediaQuery.of(context).size)),
          const SizedBox(width: 8),
          _iconButton(Icons.open_in_full_rounded, 'Полноэкранный режим',
              _toggleImmersive),
          const SizedBox(width: 8),
          // WebGL-режим: фотореалистичная сцена с текстурами (единая модель двойника)
          _iconButton(Icons.view_in_ar_rounded, 'WebGL-сцена с текстурами', () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const WebglTwinScreen()));
          }),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1B2F49).withOpacity(0.85),
                const Color(0xFF0D1626).withOpacity(0.92),
              ],
            ),
            border: Border.all(color: _accent.withOpacity(0.40), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: _accent.withOpacity(0.14),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: _accent, size: 22),
        ),
      ),
    );
  }

  Widget _buildStatsStrip() {
    // Телеметрия: вертикальная стеклянная колонка у левого края —
    // не перекрывает сцену, читается как HUD авиаприбора (taste-skill)
    final avg = _stats?['average_height_m'] ?? '—';
    return Positioned(
      top: 118,
      left: 14,
      child: _glassShell(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            _statCell('${_buildings.length}', 'ЗДАНИЙ', _accent),
            _statDiv(),
            _statCell('$avg', 'СР.ЭТ.', const Color(0xFF7DD3FC)),
            _statDiv(),
            _statCell('${_signals.length}', 'СИГНАЛ.', const Color(0xFFF59E0B)),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.5)),
        const SizedBox(height: 1),
        Text(label,
            style: const TextStyle(
                color: _inkDim,
                fontSize: 7.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _statDiv() {
    return Container(
      width: 30,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _accent.withOpacity(0.45),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildInspector() {
    final b = _selected!;
    return Positioned(
      bottom: 148,
      left: 14,
      right: 14,
      child: _glassShell(
        borderRadius: 24,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Цветовое свечение категории здания
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    b.color.withOpacity(0.9),
                    b.color.withOpacity(0.25),
                  ],
                ),
                border: Border.all(color: b.color.withOpacity(0.8), width: 1.4),
                boxShadow: [
                  BoxShadow(color: b.color.withOpacity(0.5), blurRadius: 14),
                ],
              ),
              child: const Icon(Icons.location_city_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 3),
                  Text(
                    '${b.category} • высота ${(b.zTop - b.zBottom).toStringAsFixed(0)} м${b.address.isNotEmpty ? ' • ${b.address}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _inkDim, fontSize: 11),
                  ),
                ],
              ),
            ),
            // «Моё окно»: инсоляция выбранного дома (уникальная фича)
            _iconButton(Icons.wb_sunny_rounded, 'Что видит моё окно',
                () => _showMyWindowSheet(b)),
            const SizedBox(width: 8),
            _iconButton(Icons.close_rounded, 'Закрыть',
                () => setState(() => _selected = null)),
          ],
        ),
      ),
    );
  }

  /// «Что видит моё окно» (astra): сектор обзора, часы прямого солнца,
  /// затенение соседями. Изометрическая схема + карточка.
  void _showMyWindowSheet(_Bld b) {
    int floor = 1;
    final maxFloor = math.max(1, ((b.zTop - b.zBottom) / 3.0).floor());
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            // Солнце в мире на текущий час
            final sunElev = _sunElevation;
            final sunAz = _sunAzimuthRad;
            // Часы прямого солнца для стороны: по азимуту фасадов
            final sides = [
              ('Южная', 180.0),
              ('Северная', 0.0),
              ('Восточная', 90.0),
              ('Западная', 270.0),
            ];
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0xFF00E5FF), width: 1.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('МОЁ ОКНО',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10,
                          fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(b.name,
                      style: const TextStyle(color: Color(0xFFF8FAFC),
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // Схема: дом + 4 стороны + сектор солнца
                  SizedBox(
                    height: 150,
                    child: CustomPaint(
                      painter: _MyWindowPainter(
                        building: b,
                        azimuth: _azimuth,
                        sunAzimuthRad: sunAz,
                        sunElevation: sunElev,
                        floor: floor,
                        maxFloor: maxFloor,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Выбор этажа
                  Row(
                    children: [
                      const Text('Этаж: ',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: floor.toDouble(),
                          min: 1,
                          max: maxFloor.toDouble(),
                          divisions: math.max(1, maxFloor - 1),
                          label: '$floor',
                          activeColor: const Color(0xFFF59E0B),
                          onChanged: (v) => setSheet(() => floor = v.round()),
                        ),
                      ),
                      Text('$floor / $maxFloor',
                          style: const TextStyle(color: Color(0xFFF8FAFC),
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Инсоляция по сторонам
                  ...sides.map((s) {
                    final hours = _estimateSunHours(b, s.$2, floor, maxFloor);
                    final color = hours > 5
                        ? const Color(0xFF34D399)
                        : hours > 2
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF94A3B8);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.wb_sunny_rounded, size: 14, color: color),
                          const SizedBox(width: 8),
                          Text('${s.$1} сторона',
                              style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12)),
                          const Spacer(),
                          Text(hours > 0
                              ? '≈ ${hours.toStringAsFixed(0)} ч солнца'
                              : 'в тени',
                              style: TextStyle(color: color, fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    'Расчёт по астрономии 60.9°N и высотам соседних зданий. '
                    'Зимой световой день короткий — сравните с тайм-машиной.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Оценка часов прямого солнца для стороны фасада (упрощённая модель)
  double _estimateSunHours(_Bld b, double sideAzDeg, int floor, int maxFloor) {
    final sideAz = sideAzDeg * math.pi / 180;
    // часы, когда солнце на этой стороне горизонта и над горизонтом
    double hours = 0;
    for (double h = 4; h <= 23; h += 0.5) {
      // приблизительная траектория солнца для даты по dayHour-калибровке
      final t = (h - 12) / 12 * math.pi; // -π..π
      final az = math.pi + t; // восток утром → запад вечером (упрощ.)
      final elev = math.cos(t) * 35; // до ~35° в полдень на 61°N летом
      if (elev <= 0) continue;
      // сторона обращена к солнцу?
      final diff = (az - sideAz).abs();
      final facing = math.cos(diff);
      if (facing > 0.2) {
        // затенение соседями: нижние этажи теряют больше
        final floorFactor = 0.4 + 0.6 * (floor / math.max(1, maxFloor));
        hours += 0.5 * facing * floorFactor;
      }
    }
    return hours;
  }

  Widget _buildBottomDock(Size size) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Контекстная панель режима
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: _buildContextPanel(),
          ),
          const SizedBox(height: 8),
          // Чипы режимов
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _modeChip(_TwinMode.sun, Icons.wb_sunny_rounded, 'Солнце'),
                const SizedBox(width: 6),
                _modeChip(_TwinMode.flood, Icons.flood_rounded, 'Паводок'),
                const SizedBox(width: 6),
                _modeChip(_TwinMode.snow, Icons.ac_unit_rounded, 'Снег'),
                const SizedBox(width: 6),
                _modeChip(_TwinMode.samotlor, Icons.local_fire_department_rounded,
                    'Самотлор'),
                const SizedBox(width: 6),
                _modeChip(_TwinMode.time, Icons.history_rounded, '4D'),
                const SizedBox(width: 6),
                _layerChip(
                  icon: Icons.videocam_rounded,
                  label: 'Камеры',
                  active: _showCameras,
                  onTap: () => setState(() => _showCameras = !_showCameras),
                ),
                _layerChip(
                  icon: Icons.architecture_rounded,
                  label: 'Доминанты',
                  active: _showLandmarks,
                  onTap: () => setState(() => _showLandmarks = !_showLandmarks),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _modeChip(_TwinMode m, IconData icon, String label) {
    final active = _mode == m;
    return _layerChip(
      icon: icon,
      label: label,
      active: active,
      onTap: () => setState(() {
        _mode = m;
        _ensureTicker();
      }),
    );
  }

  Widget _layerChip(
      {required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap}) {
    // «Пилюля наблюдателя»: стеклянная капсула с внутренним свечением
    // активного режима; нажатие — с тактильным откликом (taste-skill)
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _accent.withOpacity(0.34),
                    _accent.withOpacity(0.10),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF16283F).withOpacity(0.82),
                    const Color(0xFF0D1626).withOpacity(0.90),
                  ],
                ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: active ? _accent : const Color(0x337A93B8),
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _accent.withOpacity(0.42),
                    blurRadius: 16,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            // «Огонь» индикатор: живая точка режима
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? _accent : const Color(0xFF3B5270),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _accent.withOpacity(0.9),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 9),
            Icon(icon,
                size: 18, color: active ? _accent : const Color(0xFF8FA6C4)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: active ? _ink : const Color(0xFF8FA6C4),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: active ? 0.5 : 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildContextPanel() {
    switch (_mode) {
      case _TwinMode.sun:
        return _sunPanel();
      case _TwinMode.flood:
        return _floodPanel();
      case _TwinMode.snow:
        return _snowPanel();
      case _TwinMode.samotlor:
        return _samotlorPanel();
      case _TwinMode.time:
        return _timePanel();
    }
  }

  /// Liquid-glass декорация (taste-skill): многослойное стекло с
  /// градиентной кромкой, холодным свечением и глубиной. Блюр даёт
  /// ClipRRect+BackdropFilter в _glassShell, тут — цветовая база.
  BoxDecoration _panelDecoration({double borderRadius = 20}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF16283F).withOpacity(0.78),
          const Color(0xFF0C1524).withOpacity(0.88),
        ],
      ),
      border: Border.all(
        color: _accent.withOpacity(0.38),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.38),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: _accent.withOpacity(0.10),
          blurRadius: 30,
          spreadRadius: 2,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Обёртка «жидкое стекло»: настоящий блюр фона под панелью.
  Widget _glassShell({
    required Widget child,
    double borderRadius = 20,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: _panelDecoration(borderRadius: borderRadius),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _panelShell({required Widget child}) {
    return _glassShell(
      borderRadius: 22,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: child,
    );
  }

  Widget _sunPanel() {
    final elev = _sunElevation;
    final season = _solarData?['season_profile'] ?? '';
    final shadowMult = _solarData?['shadow_length_multiplier'];
    final insolation = _solarData?['courtyard_insolation_score_pct'];
    return _panelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 6),
              Text(
                'Время ${_dayHour.toStringAsFixed(2).replaceFirst('.00', ':00').replaceFirst('.', ':')} • высота солнца ${elev.toStringAsFixed(0)}°'
                '${season.isNotEmpty ? ' • $season' : ''}',
                style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: const Color(0xFFF59E0B),
              inactiveTrackColor: Colors.white.withOpacity(0.12),
            ),
            child: Slider(
              value: _dayHour,
              min: 4,
              max: 23,
              divisions: 76, // 15 минут
              label: '${_dayHour.floor()}:${((_dayHour % 1) * 60).round().toString().padLeft(2, '0')}',
              onChanged: _onDayHourChanged,
            ),
          ),
          Row(
            children: [
              if (shadowMult != null)
                _pill('Тени ×${shadowMult.toStringAsFixed(1)} от высоты',
                    const Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              if (insolation != null)
                _pill('Инсоляция дворов $insolation%', _ok),
            ],
          ),
          const SizedBox(height: 8),
          // «Обь ловит закат»: перемотка к сегодняшнему закату — момент,
          // когда солнце касается горизонта и на Оби загорается дорожка.
          _sunsetButton(),
        ],
      ),
    );
  }

  Widget _sunsetButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B).withOpacity(0.14),
          foregroundColor: const Color(0xFFF59E0B),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _showTodaySunset,
        icon: const Icon(Icons.wb_twilight_rounded, size: 18),
        label: const Text('Показать сегодняшний закат',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// Плавная перемотка времени к закату (~высота солнца 3°): запускает
  /// тайм-лайн от текущего часа к найденному часу заката, дорожка на Оби
  /// загорается по мере приближения.
  Future<void> _showTodaySunset() async {
    // ищем час, когда высота солнца ~3° (перебор по API с кэшем)
    double? sunsetHour;
    for (final h in [21.0, 21.5, 22.0, 22.5, 20.5, 20.0, 23.0]) {
      try {
        final resp = await http.get(Uri.parse(
            '${MapConfig.backendBaseUrl}/api/v1/3d-twin/solar-shadows?hour=$h'));
        if (resp.statusCode == 200) {
          final d = (jsonDecode(resp.body)
                  as Map<String, dynamic>)['data'] as Map<String, dynamic>;
          final e = (d['solar_elevation_deg'] as num?)?.toDouble() ?? 99;
          if (e <= 3.5 && e > 0) {
            sunsetHour = h;
            break;
          }
        }
      } catch (_) {}
    }
    final target = sunsetHour ?? 21.5;
    // Плавная анимация перемотки часа
    final from = _dayHour;
    final dur = const Duration(milliseconds: 2600);
    final start = DateTime.now();
    Timer? timer;
    timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final k = (DateTime.now().difference(start).inMilliseconds /
              dur.inMilliseconds)
          .clamp(0.0, 1.0);
      final eased = Curves.easeInOut.transform(k);
      _onDayHourChanged(from + (target - from) * eased);
      if (k >= 1.0) {
        timer?.cancel();
      }
    });
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _floodPanel() {
    final threat = _floodData?['threat_level'] ?? '—';
    final area = _floodData?['flooded_area_hectares'] ?? '—';
    final label = _floodData?['status_label'] ?? '';
    final routes = (_floodData?['evacuation_routes'] as List? ?? []);
    final color = threat.toString().toLowerCase().contains('critical')
        ? _danger
        : threat.toString().toLowerCase().contains('high')
            ? _warn
            : _ok;
    return _panelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.flood_rounded, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Уровень Оби ${_waterLevel.toInt()} см • $threat • затоплено $area га',
                  style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
            ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: color,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
            ),
            child: Slider(
              value: _waterLevel,
              min: 500,
              max: 1100,
              divisions: 60,
              label: '${_waterLevel.toInt()} см',
              onChanged: (v) => setState(() => _waterLevel = v),
              onChangeEnd: _onWaterLevelChanged,
            ),
          ),
          Text('Вода на сцене — условная визуализация уровня, площадь и угроза — данные гидромодели',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9)),
          if (routes.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final r in routes)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _pill(
                        '${r['from']} → ${r['to']}',
                        r['safe'] == true ? _ok : _danger,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _snowPanel() {
    final zones = (_snowData?['drift_risk_zones'] as List? ?? []);
    final km = _snowData?['total_snow_routes_km'] ?? '—';
    return _panelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Маршруты уборки: $km км • зон перемётов: ${zones.length}',
              style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final z in zones)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _pill('${z['name']} · ${z['risk']}', _warn),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _samotlorPanel() {
    final flares = (_flareData?['active_flares'] as List? ?? []);
    final disp = _flareData?['air_quality_dispersion_vector'] ?? '';
    return _panelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Факельные установки: ${flares.length} • сенсор SWIR Sentinel-2',
              style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in flares)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _pill('${f['field']} · ${f['heat_mw']} МВт', _danger),
                  ),
              ],
            ),
          ),
          if (disp.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Рассеивание: $disp',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _timePanel() {
    final snap = _timeline.cast<Map<String, dynamic>?>().firstWhere(
          (t) => t?['year'] == _year,
          orElse: () => null,
        );
    final footprints = _timeline
        .map((t) => ((t['urban_footprint_km2'] as num?)?.toDouble() ?? 0))
        .toList();
    final maxF = footprints.isEmpty ? 1.0 : footprints.reduce(math.max);
    return _panelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: _accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  snap?['title'] ?? 'Тайм-машина города',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final t in _timeline) ...[
                _yearChip((t['year'] as num).toInt()),
                if (t != _timeline.last) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Мини-график footprint
          SizedBox(
            height: 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < footprints.length; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 8 + 24 * (footprints[i] / maxF),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _timeline[i]['year'] == _year
                            ? _accent
                            : _accent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text('Площадь застройки: ${snap?['urban_footprint_km2'] ?? '—'} км² (современная геометрия, исторические показатели)',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _yearChip(int year) {
    final active = _year == year;
    return GestureDetector(
      onTap: () => _onYearChanged(year),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _accent.withOpacity(0.18) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _accent : Colors.transparent),
        ),
        child: Text('$year',
            style: TextStyle(
                color: active ? _accent : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Сигналы и ремонты на 3D-карте (общие данные с основной картой)
// ---------------------------------------------------------------------------

class _TwinSignal {
  _TwinSignal(this.x, this.y, this.z, this.color, this.title);
  final double x, y, z;
  final Color color;
  final String title;
}


// ---------------------------------------------------------------------------
// Ландшафт долины Оби
// ---------------------------------------------------------------------------

class _Landscape {
  _Landscape({
    required this.originLng,
    required this.originLat,
    required this.cosLat,
    required this.obMirror,
    required this.obLine,
    required this.lakes,
    required this.forest,
    required this.gaugeZeroAbsM,
    required this.demOffsetM,
  });

  final double originLng, originLat, cosLat;
  final List<Offset> obMirror; // мировые метры
  final List<Offset> obLine;
  final List<_Lake> lakes;
  final List<List<Offset>> forest;
  final double gaugeZeroAbsM;
  final double demOffsetM;

  static const _earthR = 6378137.0;

  static _Landscape? fromApi(Map<String, dynamic> data, double lng0, double lat0) {
    try {
      final ob = (data['ob'] as Map).cast<String, dynamic>();
      final cosLat = math.cos(lat0 * math.pi / 180);
      Offset toWorld(List c) => Offset(
            _earthR * ((c[0] as num).toDouble() - lng0) * math.pi / 180 * cosLat,
            _earthR * ((c[1] as num).toDouble() - lat0) * math.pi / 180,
          );
      Offset toWorldDyn(dynamic c) => toWorld(c as List);
      final mirror =
          (ob['mirror'] as List).map(toWorldDyn).toList();
      final line = (ob['line'] as List).map(toWorldDyn).toList();
      final lakes = <_Lake>[
        for (final l in data['lakes'] as List)
          _Lake(
            ring: (l['ring'] as List).map(toWorldDyn).toList(),
            name: l['name'] as String?,
            water: l['water'] as String? ?? 'water',
          )
      ];
      final forest = <List<Offset>>[
        for (final f in data['forest'] as List)
          (f['ring'] as List).map(toWorldDyn).toList()
      ];
      final flood = (data['flood'] as Map).cast<String, dynamic>();
      return _Landscape(
        originLng: lng0,
        originLat: lat0,
        cosLat: cosLat,
        obMirror: mirror,
        obLine: line,
        lakes: lakes,
        forest: forest,
        gaugeZeroAbsM: (flood['gauge_zero_abs_m'] as num?)?.toDouble() ?? 31.9,
        demOffsetM: (flood['gauge_offset_dem_m'] as num?)?.toDouble() ?? 3.3,
      );
    } catch (e) {
      debugPrint('[Twin] landscape parse error: $e');
      return null;
    }
  }
}

class _Lake {
  _Lake({required this.ring, this.name, this.water = 'water'});
  final List<Offset> ring;
  final String? name;
  final String water;
}

// ---------------------------------------------------------------------------
// Реалтайм-погода в 3D-городе (astra): пресеты по weathercode Open-Meteo
// ---------------------------------------------------------------------------

class TwinWeather {
  TwinWeather.empty()
      : code = 0,
        rain = 0,
        snow = 0,
        fogBeta = 0.00012,
        sunMul = 1.0,
        skyFillMul = 1.0,
        wetness = 0,
        snowCover = 0,
        windMps = 2;

  TwinWeather.live(this.code, this.windMps)
      : rain = 0,
        snow = 0,
        fogBeta = 0.00012,
        sunMul = 1.0,
        skyFillMul = 1.0,
        wetness = 0,
        snowCover = 0;

  final int code;
  final double windMps;
  double rain, snow, fogBeta, sunMul, skyFillMul, wetness, snowCover;

  static TwinWeather fromCode(int code, {double windMps = 2}) {
    final w = TwinWeather.live(code, windMps);
    switch (code) {
      case 0: // ясно
        w.fogBeta = 0.00012; w.sunMul = 1.00; w.skyFillMul = 1.00;
      case 1: case 2: // малооблачно
        w.fogBeta = 0.00020; w.sunMul = 0.75; w.skyFillMul = 0.92;
      case 3: // пасмурно
        w.fogBeta = 0.00035; w.sunMul = 0.08; w.skyFillMul = 0.82;
      case 45: case 48: // туман
        w.fogBeta = 0.0050; w.sunMul = 0.03; w.skyFillMul = 0.84;
      case 51: case 53: case 55: // морось
        w.rain = 0.18; w.fogBeta = 0.0009; w.sunMul = 0.06; w.skyFillMul = 0.78; w.wetness = 0.5;
      case 61: // слабый дождь
        w.rain = 0.25; w.fogBeta = 0.00055; w.sunMul = 0.05; w.skyFillMul = 0.76; w.wetness = 0.7;
      case 63:
        w.rain = 0.55; w.fogBeta = 0.00085; w.sunMul = 0.03; w.skyFillMul = 0.70; w.wetness = 0.9;
      case 65: case 80: case 81: case 82: // сильный/ливень
        w.rain = 0.90; w.fogBeta = 0.00130; w.sunMul = 0.00; w.skyFillMul = 0.62; w.wetness = 1.0;
      case 71: case 77: case 85: // слабый снег/зёрна
        w.snow = 0.30; w.fogBeta = 0.00070; w.sunMul = 0.08; w.skyFillMul = 0.86; w.snowCover = 0.5;
      case 73:
        w.snow = 0.55; w.fogBeta = 0.00110; w.sunMul = 0.04; w.skyFillMul = 0.82; w.snowCover = 0.8;
      case 75: case 86:
        w.snow = 0.90; w.fogBeta = 0.00180; w.sunMul = 0.02; w.skyFillMul = 0.78; w.snowCover = 1.0;
      default:
        w.fogBeta = 0.00020; w.sunMul = 0.8; w.skyFillMul = 0.95;
    }
    return w;
  }

  /// Плавный переход к целевому состоянию (astra 1.2)
  void approachTo(TwinWeather target, double dt) {
    double ap(double v, double t, double tau) =>
        v + (t - v) * (1.0 - math.exp(-dt / tau));
    rain = ap(rain, target.rain, 2.5);
    snow = ap(snow, target.snow, 3.0);
    fogBeta = ap(fogBeta, target.fogBeta, 5.0);
    sunMul = ap(sunMul, target.sunMul, 6.0);
    skyFillMul = ap(skyFillMul, target.skyFillMul, 6.0);
    wetness = ap(wetness, target.wetness, target.wetness > wetness ? 25.0 : 240.0);
    snowCover = ap(snowCover, target.snowCover, 120.0);
  }

  bool get isClear => rain < 0.05 && snow < 0.05 && fogBeta < 0.0004;
}

// ---------------------------------------------------------------------------
// Painter сцены
// ---------------------------------------------------------------------------

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.buildings,
    required this.landmarks,
    required this.cameras,
    required this.worldCenter,
    required this.worldBounds,
    required this.azimuth,
    required this.zoom,
    required this.pan,
    required this.size,
    required this.clockValue,
    required this.timeMs,
    required this.mode,
    required this.dayHour,
    required this.sunAzimuthRad,
    required this.sunElevation,
    required this.waterLevel,
    required this.year,
    required this.growthT,
    required this.selected,
    required this.roofHits,
    required this.signalHits,
    required this.flareData,
    this.landscape,
    this.signals = const [],
    TwinWeather? weather,
  }) : weather = weather ?? TwinWeather.empty();

  final List<_Bld> buildings;
  final List<_Landmark> landmarks;
  final List<_Cam3D> cameras;
  final Offset worldCenter;
  final Rect worldBounds;
  final double azimuth;
  final double zoom;
  final Offset pan;
  final Size size;
  final double clockValue;
  final double timeMs;
  final _TwinMode mode;
  final double dayHour;
  final double sunAzimuthRad;
  final double sunElevation;
  final double waterLevel;
  final int year;
  final double growthT;
  final _Bld? selected;
  final List<MapEntry<Path, _Bld>> roofHits;
  final List<MapEntry<Offset, _TwinSignal>> signalHits;
  final Map<String, dynamic>? flareData;
  final _Landscape? landscape;
  final List<_TwinSignal> signals;
  final TwinWeather weather;

  // Кэш сортировки глубины (astra 1.3): pan/zoom порядок не меняют
  static List<_Bld>? _sortedCache;
  static double? _sortedCacheAzimuth;
  Offset get _depthAxis {
    final c = math.cos(azimuth), s = math.sin(azimuth);
    // ось глубины в мировых координатах (проекция (1,1) экрана обратно)
    final v = Offset(c - s, s + c);
    final l = v.distance;
    return l > 0 ? v / l : v;
  }

  static const _accent = Color(0xFF00E5FF);

  Offset _p(double x, double y, double z) {
    final c = math.cos(azimuth), s = math.sin(azimuth);
    final xr = x * c - y * s;
    final yr = x * s + y * c;
    return Offset(
      size.width / 2 + pan.dx + (xr - yr) * 0.8660254 * zoom,
      size.height / 2 + pan.dy + (-(xr + yr) * 0.5 - z * 1.25) * zoom,
    );
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    roofHits.clear();
    signalHits.clear();
    final t = timeMs / 1000.0;

    // 1. Небо
    _paintSky(canvas, canvasSize, t);

    // 1b. Ландшафт долины Оби: земля, лес, озёра, болота, текущая река
    if (landscape != null) {
      _paintLandscapeGround(canvas);
      _paintForest(canvas, t);
      _paintLakes(canvas, t);
      _paintObRiver(canvas, t);
    }

    // 2. Ось роста зданий (тайм-машина)
    final double growth = Curves.easeOutCubic.transform(growthT);

    // 3. Сортировка зданий (painter's algorithm) — кэшируется:
    // pan и zoom не меняют порядок глубины, пересортируем только при azimuth (astra 1.3)
    if (_sortedCache == null || _sortedCacheAzimuth != azimuth) {
      _sortedCacheAzimuth = azimuth;
      _sortedCache = [...buildings]..sort((a, b) {
          final da = a.center.dx * _depthAxis.dx + a.center.dy * _depthAxis.dy;
          final db = b.center.dx * _depthAxis.dx + b.center.dy * _depthAxis.dy;
          return db.compareTo(da); // дальние первыми
        });
    }
    final visible = _sortedCache!;

    // 4. Тени на земле (до зданий)
    if (sunElevation > 0.5 && mode != _TwinMode.samotlor) {
      _paintGroundShadows(canvas, growth);
    }

    // 5. Земля-подложка под городом
    _paintGround(canvas);

    // 6. Вода (паводок) — по DEM, всё ниже уровня воды затапливается
    if (mode == _TwinMode.flood) {
      _paintWater(canvas, t);
      _paintFacadeWaterlines(canvas);
    }

    // 7. Здания (с viewport culling: дешёвая проверка центра+радиуса до проекции)
    final cullMargin = 200.0;
    for (final b in visible) {
      // быстрый тест: центр здания в проекции + запас на высоту/радиус
      final cp = _p(b.center.dx, b.center.dy, 0);
      final reachPx = (b.radius + b.zTop * 1.4) * zoom + 60;
      if (cp.dx < -cullMargin - reachPx ||
          cp.dx > size.width + cullMargin + reachPx ||
          cp.dy < -cullMargin - reachPx ||
          cp.dy > size.height + cullMargin + reachPx) {
        continue;
      }
      _paintBuilding(canvas, b, growth, t);
    }

    // 8. Камеры (FOV сектора)
    for (final cam in cameras) {
      _paintCameraFov(canvas, cam, t);
    }

    // 9. Доминанты
    for (final lm in landmarks) {
      _paintLandmark(canvas, lm, t);
    }

    // 9b. Ремонты убраны с карты двойника (по запросу пользователя)

    // 9c. Сигналы жителей (пульсирующие маркеры над зданиями)
    _paintSignals(canvas, t);

    // 10. Факелы Самотлора
    if (mode == _TwinMode.samotlor) {
      _paintFlares(canvas, t);
    }

    // 11. Снег-режим (демо) или реалтайм осадки по погоде
    if (mode == _TwinMode.snow) {
      _paintSnow(canvas, t);
    } else {
      // Реалтайм дождь: 3 слоя глубины, наклон по ветру (astra 1.3)
      if (weather.rain > 0.05) {
        _paintRealtimeRain(canvas, t);
      }
      // Реалтайм снег
      if (weather.snow > 0.05) {
        _paintRealtimeSnow(canvas, t);
      }
    }
  }

  // --- Небо ---

  void _paintSky(Canvas canvas, Size cs, double t) {
    final (top, bottom) = _skyColors();
    final rect = Rect.fromLTWH(0, 0, cs.width, cs.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
    // Реалистичные Солнце и Луна: положение по азимуту/высоте (условное над городом)
    _paintSunAndMoon(canvas, cs);
    // Звёзды ночью
    final night = _nightFactor();
    if (night > 0.05) {
      final starPaint = Paint()..color = Colors.white.withOpacity(0.7 * night);
      final rnd = math.Random(42);
      for (int i = 0; i < 90; i++) {
        final x = rnd.nextDouble() * cs.width;
        final y = rnd.nextDouble() * cs.height * 0.6;
        final tw = 0.5 + 0.5 * math.sin(t * 2 + i * 7.3);
        canvas.drawCircle(
            Offset(x, y), 0.6 + tw * 0.8, starPaint..strokeWidth = 1);
      }
    }
  }

  /// Солнце и Луна над городом: экранные координаты из азимута/высоты.
  /// Позиция условная — соотносится с реальным углом светила над горизонтом.
  void _paintSunAndMoon(Canvas canvas, Size cs) {
    // азимут 0..2π → экранная X (восток слева, запад справа — художественно)
    final az = sunAzimuthRad;
    final azNorm = ((az % (2 * math.pi)) + 2 * math.pi) % (2 * math.pi);
    final x = cs.width * (1.0 - azNorm / math.pi).clamp(0.06, 0.94);
    // высота 90°→ верх экрана, 0°→ линия горизонта (~68% высоты)
    final eNorm = (sunElevation / 90.0).clamp(-0.1, 1.0);
    final horizonY = cs.height * 0.68;
    final y = horizonY - eNorm * horizonY * 0.82;

    if (sunElevation > -2) {
      // ── Солнце ──
      final glowR = 46 + weather.skyFillMul * 14;
      // атмосферное гало
      canvas.drawCircle(
        Offset(x, y), glowR,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFF3C4).withOpacity(0.55 * weather.sunMul),
            const Color(0xFFFFC879).withOpacity(0.18 * weather.sunMul),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: Offset(x, y), radius: glowR)),
      );
      // диск
      canvas.drawCircle(
        Offset(x, y), 16,
        Paint()
          ..shader = RadialGradient(colors: const [
            Color(0xFFFFFBF0),
            Color(0xFFFFE9A8),
            Color(0xFFFFC879),
          ]).createShader(Rect.fromCircle(center: Offset(x, y), radius: 16)),
      );
      // блик на облаках при закате (низкое солнце — тёплое свечение шире)
      if (sunElevation < 12 && sunElevation > -2) {
        canvas.drawCircle(
          Offset(x, y), 80,
          Paint()..color = const Color(0xFFFF9100).withOpacity(0.12),
        );
      }
    }

    // ── Луна: противоположная сторона неба, видна ночью ──
    final night = _nightFactor();
    if (night > 0.25) {
      // Луна ~ напротив Солнца по азимуту, фиксированная художественная высота
      final mx = cs.width - x;
      final my = cs.height * 0.16 + math.sin(azNorm) * 14;
      final moonAlpha = (night - 0.25) / 0.75;
      // свечение
      canvas.drawCircle(
        Offset(mx, my), 34,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFD8E4F0).withOpacity(0.30 * moonAlpha),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: Offset(mx, my), radius: 34)),
      );
      // диск с кратерами
      canvas.drawCircle(
        Offset(mx, my), 14,
        Paint()..color = const Color(0xFFE8EEF4).withOpacity(0.95 * moonAlpha),
      );
      // кратеры (детерминированные)
      final crater = Paint()
        ..color = const Color(0xFFB8C4D4).withOpacity(0.5 * moonAlpha);
      canvas.drawCircle(Offset(mx - 4, my - 3), 2.6, crater);
      canvas.drawCircle(Offset(mx + 5, my + 2), 1.8, crater);
      canvas.drawCircle(Offset(mx + 1, my + 6), 1.3, crater);
      canvas.drawCircle(Offset(mx - 6, my + 4), 1.1, crater);
      // терминатор (фаза): тень по дуге
      final phase = (timeMs / 86400000.0) % 1.0; // медленно меняющаяся фаза
      final shadowShift = math.cos(phase * 2 * math.pi) * 9;
      canvas.drawCircle(
        Offset(mx + shadowShift, my), 13.5,
        Paint()
          ..color = _skyColors().$1.withOpacity(0.85 * moonAlpha),
      );
    }
  }

  (Color, Color) _skyColors() {
    // Базовые состояния (astra 5.2), затем смешивание с погодой
    const night = (Color(0xFF0B1026), Color(0xFF1E2A52));
    const dawn = (Color(0xFF3B3A85), Color(0xFFFEC5B0));
    const day = (Color(0xFF2E7FBF), Color(0xFFB8DFF2));
    const dusk = (Color(0xFF5B2E8E), Color(0xFFFDC38A));
    // Погода: пасмурно/дождь/снег — светлое городское небо по кадрам камер НВ
    const overcast = (Color(0xFF8FA1AC), Color(0xFFD2DAE0));
    const rainSky = (Color(0xFF5A7080), Color(0xFFA5B5C0));
    const snowSky = (Color(0xFF9AAAB8), Color(0xFFDCE5EB));
    final morning = dayHour < 13;
    final e = sunElevation;
    Color lerpC(Color a, Color b, double t) => Color.lerp(a, b, t)!;

    (Color, Color) base;
    if (e <= -10) {
      base = night;
    } else if (e <= 0) {
      final t = (e + 10) / 10;
      final m = morning ? dawn : dusk;
      base = (lerpC(night.$1, m.$1, t), lerpC(night.$2, m.$2, t));
    } else if (e <= 8) {
      base = morning ? dawn : dusk;
    } else if (e <= 16) {
      final t = (e - 8) / 8;
      final m = morning ? dawn : dusk;
      base = (lerpC(m.$1, day.$1, t), lerpC(m.$2, day.$2, t));
    } else {
      base = day;
    }
    // Смешивание с погодным небом (пресеты смешиваются, не if — astra 5.2)
    var out = base;
    final oc = (1.0 - weather.skyFillMul).clamp(0.0, 1.0);
    if (oc > 0.03) {
      out = (lerpC(out.$1, overcast.$1, oc), lerpC(out.$2, overcast.$2, oc));
    }
    if (weather.rain > 0.05) {
      final k = weather.rain * 0.8;
      out = (lerpC(out.$1, rainSky.$1, k), lerpC(out.$2, rainSky.$2, k));
    }
    if (weather.snow > 0.05) {
      final k = weather.snow * 0.7;
      out = (lerpC(out.$1, snowSky.$1, k), lerpC(out.$2, snowSky.$2, k));
    }
    return out;
  }

  double _nightFactor() {
    final e = sunElevation;
    if (e <= -6) return 1;
    if (e >= 4) return 0;
    return 1 - (e + 6) / 10;
  }

  // --- Ландшафт долины Оби ---

  /// Земля вокруг города: тёплая тайга вместо чёрной пустоты
  void _paintLandscapeGround(Canvas canvas) {
    final r = worldBounds;
    final margin = 12000.0; // ~12 км во все стороны
    final p1 = _p(r.left - margin, r.top - margin, 0);
    final p2 = _p(r.right + margin, r.top - margin, 0);
    final p3 = _p(r.right + margin, r.bottom + margin, 0);
    final p4 = _p(r.left - margin, r.bottom + margin, 0);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF0E1A14), const Color(0xFF2E4A33),
                (sunElevation / 12).clamp(0.0, 1.0))!,
            Color.lerp(const Color(0xFF0A140F), const Color(0xFF243D2B),
                (sunElevation / 12).clamp(0.0, 1.0))!,
          ],
        ).createShader(Rect.fromPoints(p1, p3))
        ..style = PaintingStyle.fill,
    );
  }

  /// Лес (astra Вариант A): объёмная подложка — 3 оттенка хвои, пятна,
  /// тёмная полоса под опушкой, светлая кромка. Геометрия пятен кэшируется.
  static Map<int, List<List<Offset>>>? _forestSpotCache;

  void _paintForest(Canvas canvas, double t) {
    final woods = landscape?.forest ?? const [];
    if (woods.isEmpty) return;

    // Палитра дня (astra §3)
    const deepShadow = Color(0xFF112B21);
    const base = Color(0xFF163826);
    const midNeedle = Color(0xFF204633);
    const tops = Color(0xFF31543B);

    // Ночью лес темнеет и синеет
    final night = _nightFactor();
    final cDeep = Color.lerp(deepShadow, const Color(0xFF0A1712), night)!;
    final cBase = Color.lerp(base, const Color(0xFF0F2019), night)!;
    final cMid = Color.lerp(midNeedle, const Color(0xFF142A20), night)!;
    final cTop = Color.lerp(tops, const Color(0xFF1B3328), night)!;
    // Снегопад: светлый налёт
    final snowK = weather.snowCover * 0.3;
    final cBaseW = Color.lerp(cBase, const Color(0xFF8FA396), snowK)!;
    final cMidW = Color.lerp(cMid, const Color(0xFF9FB2A4), snowK)!;

    for (int wi = 0; wi < woods.length; wi++) {
      final w = woods[wi];
      if (w.length < 3) continue;
      final path = Path();
      bool first = true;
      Offset? minP, maxP;
      for (final p in w) {
        final sp = _p(p.dx, p.dy, 0);
        minP = minP == null ? sp : Offset(math.min(minP.dx, sp.dx), math.min(minP.dy, sp.dy));
        maxP = maxP == null ? sp : Offset(math.max(maxP.dx, sp.dx), math.max(maxP.dy, sp.dy));
        if (first) {
          path.moveTo(sp.dx, sp.dy);
          first = false;
        } else {
          path.lineTo(sp.dx, sp.dy);
        }
      }
      path.close();
      // вне экрана — пропускаем
      final b = path.getBounds();
      if (b.right < -50 || b.left > size.width + 50 || b.bottom < -50 || b.top > size.height + 50) {
        continue;
      }
      // Основа
      canvas.drawPath(path, Paint()..color = cBaseW.withOpacity(0.95));
      // Тёмная полоса под опушкой (нижняя часть)
      canvas.drawPath(path, Paint()..color = cDeep.withOpacity(0.25));
      // Пятна хвои — генерируются один раз на полигон (кэш).
      // Порог снижен: городские парки и рощи (маленькие полигоны) тоже
      // получают деревья, а не пропускаются.
      if (b.width > 8 && b.height > 8) {
        _forestSpotCache ??= {};
        var spots = _forestSpotCache![wi];
        if (spots == null) {
          spots = [];
          final rnd = math.Random(wi * 7919);
          var n = math.min(14, (b.width * b.height / 2200).ceil());
          if (n < 2) n = 2;
          for (int s = 0; s < n; s++) {
            final cx = b.left + rnd.nextDouble() * b.width;
            final cy = b.top + rnd.nextDouble() * b.height;
            final r = 8 + rnd.nextDouble() * 18;
            final poly = <Offset>[];
            for (int k = 0; k < 6; k++) {
              final ang = k * math.pi / 3 + rnd.nextDouble() * 0.5;
              final rr = r * (0.7 + rnd.nextDouble() * 0.5);
              poly.add(Offset(cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * 0.6));
            }
            spots.add(poly);
          }
          _forestSpotCache![wi] = spots;
        }
        final spotPaint = Paint()..color = cMidW.withOpacity(0.6);
        final topPaint = Paint()..color = cTop.withOpacity(0.35);
        for (int si = 0; si < spots.length; si++) {
          final poly = spots[si];
          final sp = Path()..moveTo(poly[0].dx, poly[0].dy);
          for (int k = 1; k < poly.length; k++) {
            sp.lineTo(poly[k].dx, poly[k].dy);
          }
          sp.close();
          canvas.drawPath(sp, si % 2 == 0 ? spotPaint : topPaint);
        }
      }
      // Светлая кромка (освещённая опушка)
      canvas.drawPath(
        path,
        Paint()
          ..color = cTop.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  /// Озёра и старицы: тёмная вода с бликами
  void _paintLakes(Canvas canvas, double t) {
    final lakes = landscape?.lakes ?? const [];
    for (final lake in lakes) {
      if (lake.ring.length < 3) continue;
      final path = Path();
      bool first = true;
      for (final p in lake.ring) {
        final sp = _p(p.dx, p.dy, 0);
        if (first) {
          path.moveTo(sp.dx, sp.dy);
          first = false;
        } else {
          path.lineTo(sp.dx, sp.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFF0B2E4A).withOpacity(0.92),
      );
      // мерцающий блик
      final c = _ringCentroid(lake.ring);
      final cp = _p(c.dx, c.dy, 0);
      final tw = 0.5 + 0.5 * math.sin(t * 0.7 + c.dx * 0.01);
      canvas.drawCircle(
        cp,
        3 + tw * 4,
        Paint()..color = const Color(0xFF67E8F9).withOpacity(0.10 * tw),
      );
    }
  }

  Offset _ringCentroid(List<Offset> ring) {
    double sx = 0, sy = 0;
    for (final p in ring) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / ring.length, sy / ring.length);
  }

  /// Обь: реальное зеркало реки + течение (штрихи потока) + световая дорожка
  void _paintObRiver(Canvas canvas, double t) {
    final mirror = landscape?.obMirror ?? const [];
    if (mirror.length < 3) return;

    // 1. Зеркало реки
    final path = Path();
    bool first = true;
    for (final p in mirror) {
      final sp = _p(p.dx, p.dy, 0);
      if (first) {
        path.moveTo(sp.dx, sp.dy);
        first = false;
      } else {
        path.lineTo(sp.dx, sp.dy);
      }
    }
    path.close();

    // Градиент поперёк реки: тёмная середина, светлые берега
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFF123A5C), Color(0xFF1B4E77), Color(0xFF123A5C)],
        ).createShader(bounds)
        ..style = PaintingStyle.fill,
    );
    // Контур берега — светлая кромка
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF67E8F9).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 2. ТЕЧЕНИЕ: многорядный поток по всей ширине русла.
    // Струи бегут вдоль линии с разными скоростями/фазами и смещением
    // поперёк русла — река живая на любом зуме. Яркость усилена, чтобы
    // течение читалось даже на затемнённой воде.
    final line = landscape?.obLine ?? const [];
    if (line.length >= 2) {
      final flow = Paint()
        ..color = const Color(0xFFCFEFFB).withOpacity(0.55)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final flowDim = Paint()
        ..color = const Color(0xFFA8DCEF).withOpacity(0.34)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      final flowFar = Paint()
        ..color = const Color(0xFF8FC6DF).withOpacity(0.22)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      // длина русла в сегментах
      final nSeg = line.length - 1;
      // перпендикуляр к локальному направлению русла
      for (int i = 0; i < nSeg; i++) {
        final p0 = line[i];
        final p1 = line[i + 1];
        final dx = p1.dx - p0.dx;
        final dy = p1.dy - p0.dy;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 1) continue;
        final ux = dx / len, uy = dy / len; // вдоль
        final px = -uy, py = ux; // поперёк
        // 7 струй: центр + 3 слева/справа по всей ширине русла
        for (int lane = -3; lane <= 3; lane++) {
          final laneOff = lane * 42.0; // метры поперёк русла
          // скорость течения: центр быстрее, у берега медленнее
          final speed = 0.16 - lane.abs() * 0.017;
          final phase = (t * speed + i * 0.31 + lane * 0.43) % 1.0;
          final streakLen = 42.0 + lane.abs() * 14.0;
          final mx = p0.dx + dx * phase + px * laneOff;
          final my = p0.dy + dy * phase + py * laneOff;
          final ex = mx + ux * streakLen;
          final ey = my + uy * streakLen;
          final s0 = _p(mx, my, 0);
          final s1 = _p(ex, ey, 0);
          if (lane == 0) {
            canvas.drawLine(s0, s1, flow);
          } else if (lane.abs() <= 1) {
            canvas.drawLine(s0, s1, flowDim);
          } else {
            canvas.drawLine(s0, s1, flowFar);
          }
        }
      }
      // Вихри у берега: короткие дуги, вращаются по потоку
      final eddy = Paint()
        ..color = const Color(0xFFD8F2FF).withOpacity(0.26)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final rndE = math.Random(9);
      for (int e = 0; e < 30; e++) {
        final seg = rndE.nextInt(nSeg);
        final side = rndE.nextBool() ? 1 : -1;
        final p0 = line[seg];
        final p1 = line[seg + 1];
        final dx = p1.dx - p0.dx, dy = p1.dy - p0.dy;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 1) continue;
        final px = -dy / len, py = dx / len;
        final off = side * (16 + rndE.nextDouble() * 22);
        final ph = (t * 0.5 + e * 0.83) % 1.0;
        final cx = p0.dx + dx * ph + px * off;
        final cy = p0.dy + dy * ph + py * off;
        final c0 = _p(cx, cy, 0);
        canvas.drawCircle(c0, 3.5 + ph * 2.5, eddy);
      }
    }

    // 3. Прибрежная полоса (astra 4.1): светлая кромка вдоль берега
    final shore = Paint()
      ..color = const Color(0xFF3E6E92).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, shore);

    // 4. «Обь ловит закат»: солнечная дорожка от низкого солнца к городу.
    // Появляется при высоте солнца 0..14° — тёплое свечение и мерцающие
    // полосы на воде вдоль направления на солнце, гаснут после заката.
    if (sunElevation < 14 && sunElevation > -3) {
      final sunsetK = (1 - sunElevation.abs() / 14).clamp(0.0, 1.0) *
          (sunElevation < 0 ? (1 + sunElevation / 3).clamp(0.0, 1.0) : 1.0);
      final warm = sunElevation < 8 ? 1.0 : 0.6;
      final glowR = 200.0 + sunsetK * 160;
      final rg = RadialGradient(colors: [
        Color.lerp(const Color(0xFFFFC879), const Color(0xFFFF9100), warm)!
            .withOpacity(0.22 * sunsetK * weather.sunMul),
        Color.lerp(const Color(0xFFFFB35C), const Color(0xFFE07020), warm)!
            .withOpacity(0.10 * sunsetK * weather.sunMul),
        Colors.transparent,
      ]);
      // Центр дорожки — точка реки, ближайшая к направлению на солнце
      final c0 = _ringCentroid(mirror);
      Offset best = c0;
      double bestDot = -1;
      final sunDir = Offset(math.sin(sunAzimuthRad), -math.cos(sunAzimuthRad));
      for (final p in mirror) {
        final d = p - c0;
        final len = d.distance;
        if (len < 1) continue;
        final dot = (d.dx * sunDir.dx + d.dy * sunDir.dy) / len;
        if (dot > bestDot) {
          bestDot = dot;
          best = p;
        }
      }
      final trailC = _p(best.dx, best.dy, 0);
      canvas.drawCircle(
        trailC,
        glowR,
        Paint()..shader = rg.createShader(Rect.fromCircle(center: trailC, radius: glowR)),
      );
      // Мерцающие тёплые полосы на воде вдоль дорожки
      final strip = Paint()
        ..color = Color.lerp(
                const Color(0xFFFFD9A0), const Color(0xFFFFAA33), warm)!
            .withOpacity(0.30 * sunsetK)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final rndS = math.Random(31);
      final perp = Offset(-sunDir.dy, sunDir.dx);
      for (int i = 0; i < 26; i++) {
        final along = (rndS.nextDouble() * 2 - 1) * glowR * 0.55;
        final across = (rndS.nextDouble() * 2 - 1) * glowR * 0.34;
        final wob = math.sin(t * 1.7 + i * 2.4) * 4;
        final base = Offset(
            best.dx + sunDir.dx * along + perp.dx * across,
            best.dy + sunDir.dy * along + perp.dy * across);
        final s0 = _p(base.dx, base.dy, 0);
        final s1 = _p(
            base.dx + perp.dx * (10 + wob), base.dy + perp.dy * (6 + wob), 0);
        if (!_onScreen(s0, 80)) continue;
        canvas.drawLine(s0, s1, strip);
      }
    }

    // 5. Ночные блики городских огней (astra 4.3)
    final c = _ringCentroid(mirror);
    final cp = _p(c.dx, c.dy, 0);
    final gl = 0.5 + 0.5 * math.sin(t * 0.9);
    canvas.drawCircle(
      cp,
      18 + gl * 10,
      Paint()..color = const Color(0xFFBFEFFF).withOpacity(0.05 + 0.04 * gl),
    );
    // Ночью: тёплые отражения городских огней — разорванные полосы у берега
    final night = _nightFactor();
    if (night > 0.4) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFC879).withOpacity(0.10 * night)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 14; i++) {
        // вдоль берега (первые точки зеркала = левый берег)
        final idx = (i * mirror.length / 28).floor() % mirror.length;
        final p = mirror[idx];
        final sp = _p(p.dx, p.dy, 0);
        if (!_onScreen(sp, 60)) continue;
        final wob = math.sin(t * 1.3 + i * 2.1) * 3;
        canvas.drawLine(
          sp + Offset(-8 + wob, 0),
          sp + Offset(8 + wob, 4),
          glowPaint,
        );
      }
    }
  }

  // --- Земля и тени ---

  void _paintGround(Canvas canvas) {
    final path = Path();
    final r = worldBounds;
    final margin = 300.0;
    final p1 = _p(r.left - margin, r.top - margin, 0);
    final p2 = _p(r.right + margin, r.top - margin, 0);
    final p3 = _p(r.right + margin, r.bottom + margin, 0);
    final p4 = _p(r.left - margin, r.bottom + margin, 0);
    path.moveTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p3.dx, p3.dy);
    path.lineTo(p4.dx, p4.dy);
    path.close();
    // Реальная обстановка по камерам: днём город стоит на светлом
    // серо-зелёном грунте (асфальт+газоны), ночью — тёмная подложка.
    final dayK = (sunElevation / 10).clamp(0.0, 1.0);
    final ground = Color.lerp(
        const Color(0xFF141C2E), const Color(0xFF6F7D6A), dayK * 0.9)!;
    canvas.drawPath(
      path,
      Paint()
        ..color = ground.withOpacity(0.88)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _accent.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _paintGroundShadows(Canvas canvas, double growth) {
    final mult = (sunElevation <= 0)
        ? 0.0
        : (1.0 / math.tan(sunElevation * math.pi / 180)).clamp(0.0, 6.0);
    if (mult <= 0) return;
    final alpha = 0.30 * (sunElevation / 30).clamp(0.25, 1.0);
    final dx = -math.sin(sunAzimuthRad);
    final dy = -math.cos(sunAzimuthRad);
    final paint = Paint()..color = const Color(0xFF020617).withOpacity(alpha);

    for (final b in buildings) {
      final h = (b.zTop - b.zBottom) * growth;
      if (h < 4) continue;
      final L = h * mult;
      final path = Path();
      final ring = b.ring;
      for (int i = 0; i < ring.length; i++) {
        final p1 = ring[i];
        final p2 = ring[(i + 1) % ring.length];
        final s1 = _p(p1.dx, p1.dy, 0);
        final s2 = _p(p2.dx, p2.dy, 0);
        final s3 = _p(p2.dx + dx * L, p2.dy + dy * L, 0);
        final s4 = _p(p1.dx + dx * L, p1.dy + dy * L, 0);
        path.moveTo(s1.dx, s1.dy);
        path.lineTo(s2.dx, s2.dy);
        path.lineTo(s3.dx, s3.dy);
        path.lineTo(s4.dx, s4.dy);
        path.close();
      }
      canvas.drawPath(path, paint);
    }
  }

  // --- Здания ---

  void _paintBuilding(Canvas canvas, _Bld b, double growth, double t) {
    // Тайм-машина: рост от центра сцены
    double localGrowth = growth;
    if (growth < 1) {
      final distNorm = ((b.center - worldCenter).distance /
              (worldBounds.longestSide / 2))
          .clamp(0.0, 1.0);
      localGrowth = Curves.easeOutCubic
          .transform(((growthT - distNorm * 0.16) / 0.84).clamp(0.0, 1.0));
    }
    final h = (b.zTop - b.zBottom) * localGrowth;
    if (h <= 0.5) return;

    // Материалы фасадов Нижневартовска (astra 2.2): советская типовая застройка
    // Панель кремовая/серая, силикатный кирпич терракотовый, современные ЖК — цветные
    Color base = _facadeMaterial(b);
    if (year == 2015) {
      final hsl = HSLColor.fromColor(base);
      base = hsl.withSaturation(hsl.saturation * 0.45).withLightness(0.32).toColor();
    } else if (year == 2020) {
      base = Color.lerp(base, const Color(0xFF3B82F6), 0.22)!;
    }

    final night = _nightFactor();
    // Атмосферная дымка (astra 2.5): далёкие дома выцветают к цвету атмосферы
    final depthM = (b.center.dx * _depthAxis.dx + b.center.dy * _depthAxis.dy);
    base = _applyHaze(base, depthM);
    // Направление на солнце в мировых координатах
    final sunX = math.sin(sunAzimuthRad);
    final sunY = math.cos(sunAzimuthRad);
    final cosAz = math.cos(azimuth), sinAz = math.sin(azimuth);

    // Тень-подложка контура
    final groundPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    // 1. Крыша
    final roofPath = Path();
    final roofPts = <Offset>[];
    for (final p in b.ring) {
      final sp = _p(p.dx, p.dy, h);
      roofPts.add(sp);
    }
    if (roofPts.length < 3) return;
    roofPath.moveTo(roofPts[0].dx, roofPts[0].dy);
    for (int i = 1; i < roofPts.length; i++) {
      roofPath.lineTo(roofPts[i].dx, roofPts[i].dy);
    }
    roofPath.close();
    for (final hole in b.holes) {
      final hp = hole.map((p) => _p(p.dx, p.dy, h)).toList();
      if (hp.length < 3) continue;
      roofPath.moveTo(hp[0].dx, hp[0].dy);
      for (int i = 1; i < hp.length; i++) {
        roofPath.lineTo(hp[i].dx, hp[i].dy);
      }
      roofPath.close();
    }
    roofPath.fillType = PathFillType.evenOdd;

    // 2. Боковые грани (только видимые и достаточного размера)
    final sides = <(Path, double, Offset, Offset)>[]; // path, длина px, mid, normal
    for (int i = 0; i < b.ring.length; i++) {
      final p1 = b.ring[i];
      final p2 = b.ring[(i + 1) % b.ring.length];
      // внешняя нормаль (CCW кольцо)
      final ex = p2.dx - p1.dx, ey = p2.dy - p1.dy;
      final nx = ey, ny = -ex;
      final nl = math.sqrt(nx * nx + ny * ny);
      if (nl < 0.01) continue;
      // видимость: нормаль в повёрнутых координатах направлена к зрителю
      final nrx = (nx * cosAz - ny * sinAz) / nl;
      final nry = (nx * sinAz + ny * cosAz) / nl;
      if (nrx + nry >= 0) continue; // невидимая грань
      // освещённость фасада
      final light =
          (0.55 + 0.45 * math.max(0, (nx * sunX + ny * sunY) / nl)).clamp(0.0, 1.0);
      final s1 = _p(p1.dx, p1.dy, 0);
      final s2 = _p(p2.dx, p2.dy, 0);
      final edgeLenPx = (s2 - s1).distance;
      if (edgeLenPx < 2) continue;
      final path = Path()
        ..moveTo(s1.dx, s1.dy)
        ..lineTo(s2.dx, s2.dy)
        ..lineTo(roofPts[(i + 1) % roofPts.length].dx,
            roofPts[(i + 1) % roofPts.length].dy)
        ..lineTo(roofPts[i].dx, roofPts[i].dy)
        ..close();
      sides.add((path, edgeLenPx, (s1 + s2) / 2, Offset(nrx, nry)));
      canvas.drawPath(
        path,
        Paint()
          ..color = _shade(base, 0.58 + 0.42 * light)
          ..style = PaintingStyle.fill,
      );

      // Детализация фасада по LOD (astra): швы этажей, окна, балконы
      final floorPx = 3.0 * 1.25 * zoom;
      if (floorPx >= 5 && edgeLenPx >= 26) {
        _paintFacadeDetails(canvas, b, p1, p2, i, h, base, edgeLenPx, floorPx);
      }
      // Ночные окна: яркие тёплые прямоугольники на всех фасадах —
      // огни появляются уже в сумерках (высота солнца < 12°)
      if (night > 0.18 && edgeLenPx > 14 && h > 8) {
        final winPaint = Paint()
          ..color = const Color(0xFFFFD88A).withOpacity(0.92 * night);
        final winPaintDim = Paint()
          ..color = const Color(0xFFE8B86D).withOpacity(0.55 * night);
        final rnd = math.Random((b.seed + i * 31).toInt());
        final count = (edgeLenPx / 14).floor().clamp(1, 8);
        final heightPx = h * 1.25 * zoom;
        final floorsN = math.max(1, (h / 3.0).floor());
        for (int w = 0; w < count; w++) {
          // не все окна горят — живая мозаика
          final lit = rnd.nextDouble();
          if (lit > 0.78) continue;
          final tt = (w + 0.5) / count;
          // окно на случайном этаже
          final floor = rnd.nextInt(floorsN);
          final zFrac = 1.0 - (floor + 0.35 + rnd.nextDouble() * 0.2) / floorsN;
          final wx = s1.dx + (s2.dx - s1.dx) * tt;
          final wy = s1.dy + (s2.dy - s1.dy) * tt - heightPx * zFrac;
          final winW = math.max(2.0, edgeLenPx * 0.035);
          final winH = winW * 1.3;
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset(wx, wy), width: winW, height: winH),
              lit < 0.5 ? winPaint : winPaintDim);
        }
      }
    }

    // Контур земли
    if (sides.isNotEmpty) {
      final gp = Path()
        ..moveTo(b.ring[0].dx, b.ring[0].dy);
      // рисуем только если хоть что-то видно — используем проекции
      final gPath = Path();
      Offset first = _p(b.ring[0].dx, b.ring[0].dy, 0);
      gPath.moveTo(first.dx, first.dy);
      for (int i = 1; i < b.ring.length; i++) {
        final sp = _p(b.ring[i].dx, b.ring[i].dy, 0);
        gPath.lineTo(sp.dx, sp.dy);
      }
      gPath.close();
      canvas.drawPath(gPath, groundPaint);
      gp.close();
    }

    // 3. Крыша поверх — реалистичные материалы Нижневартовска (astra 2.3)
    // Освещение крыши: ambient + direct раздельно (astra 5.1) + мокрота
    final sunN = math.max(0, math.sin(sunElevation * math.pi / 180));
    var roofLight = (0.60 * weather.skyFillMul +
            (0.55 + 0.45 * sunN - 0.60) * weather.sunMul)
        .clamp(0.10, 1.0);
    // Мягкая кровля (рубероид) для жилого фонда, металл — по seed для прочих
    final isResidential = b.category.contains('Жилой') || b.category.contains('МКД');
    final roofVariant = (b.seed.toInt()) % 3;
    Color roofBase;
    if (isResidential) {
      // рубероид: выцветшие участки + ремонтные карты
      roofBase = switch (roofVariant) {
        0 => const Color(0xFF414747),
        1 => const Color(0xFF484E4C),
        _ => const Color(0xFF535957),
      };
    } else {
      // оцинковка / графит / приглушённо-зелёный
      roofBase = switch (roofVariant) {
        0 => const Color(0xFF929FA1),
        1 => const Color(0xFF59636A),
        _ => const Color(0xFF596F63),
      };
    }
    final roofDepthM = (b.center.dx * _depthAxis.dx + b.center.dy * _depthAxis.dy);
    // Мокрая крыша: темнее + холодный небесный оттенок (astra 1.4)
    if (weather.wetness > 0.05) {
      roofBase = Color.lerp(roofBase, const Color(0xFF111923), weather.wetness * 0.14)!;
      roofBase = Color.lerp(roofBase, const Color(0xFFB4C4CE), weather.wetness * 0.12)!;
    }
    // Снежная шапка: светлый покров по snowCover (astra 1.5)
    if (weather.snowCover > 0.05) {
      roofBase = Color.lerp(roofBase, const Color(0xFFDCE5E8), weather.snowCover * 0.75)!;
    }
    roofBase = _applyHaze(roofBase, roofDepthM);
    canvas.drawPath(
      roofPath,
      Paint()
        ..color = _shade(roofBase, 0.75 + 0.35 * roofLight)
        ..style = PaintingStyle.fill,
    );
    // Парапет: светлая кромка 0.3-0.6 м по периметру крыши
    if (zoom * 1.25 * 3.0 >= 4) {
      canvas.drawPath(
        roofPath,
        Paint()
          ..color = const Color(0xFFA9ABA4).withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, 0.45 * 1.25 * zoom),
      );
    }
    // Контур крыши
    canvas.drawPath(
      roofPath,
      Paint()
        ..color = (b == selected)
            ? _accent
            : Colors.white.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (b == selected) ? 2 : 0.6,
    );

    roofHits.add(MapEntry(roofPath, b));
  }

  /// Детализация фасада (astra LOD): полосы этажей, окна, балконы, парапет.
  void _paintFacadeDetails(
    Canvas canvas,
    _Bld b,
    Offset p1,
    Offset p2,
    int edgeIdx,
    double h,
    Color base,
    double edgeLenPx,
    double floorPx,
  ) {
    final floors = math.max(1, (h / 3.0).round());
    final floorH = h / floors;
    final dir = (p2 - p1) / edgeLenPx;
    final night = _nightFactor();
    final isApartments = b.category.contains('Жилой') || b.category.contains('МКД');
    // Градиент зажигания окон (astra 2.2): порог по seed, плавный smooth01
    final bSeed = (b.seed % 1000) / 1000.0;

    // 1. Реальная фактура фасада (по типу материала):
    // панель — межэтажные и межпанельные швы; кирпич — кладка;
    // штукатурка — лёгкая вертикальная вариация тона.
    // Материал по типологии: учитываем и процедурный вывод из высоты
    // (нетипизированные здания), и явную категорию
    final heightM = b.zTop - b.zBottom;
    final catGeneric = b.category.isEmpty || b.category == 'Здание';
    final isPanel = b.category.contains('Жилой') ||
        b.category.contains('МКД') ||
        (catGeneric && heightM >= 21 && heightM < 34);
    final isBrick = b.category.contains('5-этажный') ||
        b.category.contains('кирпич') ||
        (catGeneric && heightM >= 12 && heightM < 21);
    final seam = Paint()
      ..color = Colors.black.withOpacity(isPanel ? 0.22 : 0.15)
      ..strokeWidth = isPanel ? 1.0 : 0.7;
    for (int f = 1; f < floors; f++) {
      // линия шва на высоте f*floorH (в экранных координатах: смещение вверх)
      final zPx = f * floorH * 1.25 * zoom;
      final y1 = p1.dy - zPx;
      final y2 = p2.dy - zPx;
      canvas.drawLine(Offset(p1.dx, y1), Offset(p2.dx, y2), seam);
    }
    // Вертикальные межпанельные швы / кладка (LOD2+)
    if (floorPx >= 8) {
      final vSeam = Paint()
        ..color = Colors.black.withOpacity(isPanel ? 0.14 : 0.10)
        ..strokeWidth = 0.7;
      final rndV = math.Random((b.seed + edgeIdx * 17).toInt());
      final panelW = isBrick ? 3.2 : 9.0; // кирпич мельче
      final nV = (edgeLenPx / panelW).floor().clamp(2, 40);
      for (int v = 1; v < nV; v++) {
        final tt = v / nV;
        // небольшая «неровность» кладки по seed
        final jitter = rndV.nextDouble() * 2.0 - 1.0;
        final vx = p1.dx + (p2.dx - p1.dx) * tt + dir.dx * jitter;
        final vy = p1.dy + (p2.dy - p1.dy) * tt + dir.dy * jitter;
        final topZ = floors * floorH * 1.25 * zoom;
        canvas.drawLine(
          Offset(vx, vy),
          Offset(vx + (p1.dx - p2.dx) * 0, vy - topZ),
          vSeam,
        );
      }
    }

    // 2. Окна: по сетке этажей и секций
    final lod2 = floorPx >= 8;
    int floorIdx = 0;
    if (lod2) {
      final winW = math.min(6.0, edgeLenPx / 8); // ширина окна px
      final winH = floorPx * 0.5;
      final rnd = math.Random((b.seed + edgeIdx * 131).toInt());
      for (int f = 0; f < floors; f++) {
        floorIdx = f;
        final floors01 = floors > 1 ? floorIdx / (floors - 1) : 0.5;
        final zPx = (f + 0.32) * floorH * 1.25 * zoom;
        final count = (edgeLenPx / (winW * 2.2)).floor().clamp(1, 10);
        for (int w = 0; w < count; w++) {
          final tt = (w + 0.5) / count;
          final wx = p1.dx + (p2.dx - p1.dx) * tt - winW / 2;
          final wy = p1.dy + (p2.dy - p1.dy) * tt - zPx - winH;
          // Эмиссия окна: seed квартиры + этажа + dusk — окна зажигаются
          // заметно раньше (уже с сумерек), чтобы город «жил» огнями
          final aSeed = rnd.nextDouble();
          final threshold = 0.02 + 0.14 * aSeed + 0.06 * bSeed + 0.05 * floors01;
          final sm = ((night - threshold) / 0.10).clamp(0.0, 1.0).toDouble();
          final emiss = sm * sm * (3 - 2 * sm);
          if (emiss > 0.04) {
            // цветовые группы: 70% тёплых / 20% нейтральных / 10% холодных
            final wc = aSeed < 0.7
                ? const Color(0xFFFFC879)
                : (aSeed < 0.9 ? const Color(0xFFFFE7BC) : const Color(0xFFC7DDF2));
            canvas.drawRect(
              Rect.fromLTWH(wx, wy, winW, winH),
              Paint()..color = wc.withOpacity(0.95 * emiss),
            );
          } else {
            // дневное: тёмное стекло с бликом
            canvas.drawRect(
              Rect.fromLTWH(wx, wy, winW, winH),
              Paint()..color = const Color(0xFF0D1B2E).withOpacity(0.55),
            );
          }
        }
      }
    }

    // 3. Балконы (LOD3, только жилые): горизонтальные полупрозрачные плиты
    if (floorPx >= 13 && isApartments) {
      final balconyPaint = Paint()
        ..color = Colors.white.withOpacity(0.10);
      for (int f = 1; f < floors; f++) {
        final zPx = f * floorH * 1.25 * zoom;
        final inset = edgeLenPx * 0.12;
        final y1 = p1.dy - zPx;
        final y2 = p2.dy - zPx;
        canvas.drawLine(
          Offset(p1.dx + dir.dx * inset, y1),
          Offset(p2.dx - dir.dx * inset, y2),
          balconyPaint..strokeWidth = 2.4,
        );
      }
    }
  }

  /// Уникальная фича «Водная линия на доме»: при паводке показываем уровень воды
  /// прямо на фасаде затопленного здания + глубину у входа (astra 5.1).
  void _paintFacadeWaterlines(Canvas canvas) {
    final gaugeZero = landscape?.gaugeZeroAbsM ?? 31.9;
    final demOffset = landscape?.demOffsetM ?? 3.3;
    // Абсолютная высота зеркала воды в системе DEM
    final waterAbs = gaugeZero + waterLevel / 100.0 + demOffset;
    // Базовая высота земли города по DEM ≈ 44 м (замер по городу)
    const cityGroundDem = 44.0;
    final depthAtHouse = waterAbs - cityGroundDem; // м над землёй у дома
    if (depthAtHouse <= 0) return; // город ещё сухой

    final waterlinePaint = Paint()
      ..color = const Color(0xFF4AD9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final depthPaint = Paint()
      ..color = const Color(0xFF4AD9FF).withOpacity(0.22);

    // Рисуем линию воды на видимых фасадах зданий города
    for (final b in buildings) {
      final waterZ = depthAtHouse; // высота воды над землёй
      if (waterZ >= (b.zTop - b.zBottom)) continue; // дом полностью скрыт
      for (int i = 0; i < b.ring.length; i++) {
        final p1 = b.ring[i];
        final p2 = b.ring[(i + 1) % b.ring.length];
        final ex = p2.dx - p1.dx, ey = p2.dy - p1.dy;
        final nl = math.sqrt(ex * ex + ey * ey);
        if (nl < 0.01) continue;
        final cosAz = math.cos(azimuth), sinAz = math.sin(azimuth);
        final nrx = (ey * cosAz - (-ex) * sinAz) / nl;
        final nry = (ey * sinAz + (-ex) * cosAz) / nl;
        if (nrx + nry >= 0) continue; // невидимая грань
        final s1 = _p(p1.dx, p1.dy, 0);
        final s2 = _p(p2.dx, p2.dy, 0);
        if ((s2 - s1).distance < 8) continue;
        // линия воды на высоте waterZ
        final w1 = _p(p1.dx, p1.dy, waterZ);
        final w2 = _p(p2.dx, p2.dy, waterZ);
        canvas.drawLine(w1, w2, waterlinePaint);
        // полупрозрачная «мокрая» зона ниже линии
        final wet = Path()
          ..moveTo(s1.dx, s1.dy)
          ..lineTo(s2.dx, s2.dy)
          ..lineTo(w2.dx, w2.dy)
          ..lineTo(w1.dx, w1.dy)
          ..close();
        canvas.drawPath(wet, depthPaint);
      }
    }
  }

  /// Сигналы жителей: пульсирующие кольца над зданиями + хит-зоны для тапа
  void _paintSignals(Canvas canvas, double t) {
    const maxPulse = 10;
    var pulsed = 0;
    for (final s in signals) {
      final anchor = _p(s.x, s.y, s.z);
      if (!_onScreen(anchor, 100)) continue;
      final center = anchor + const Offset(0, -18);
      // хит-зона для автозум-пролёта по тапу
      signalHits.add(MapEntry(center, s));
      final stem = Paint()
        ..color = s.color.withOpacity(0.7)
        ..strokeWidth = 1.2;
      canvas.drawLine(anchor, center, stem);
      // пульс только у части (лимит)
      if (pulsed < maxPulse) {
        final phase = (t / 1.8) % 1.0;
        canvas.drawCircle(
          center,
          10 + 11 * phase,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = s.color.withOpacity(0.4 * (1 - phase)),
        );
        pulsed++;
      }
      canvas.drawCircle(center, 5.5, Paint()..color = s.color);
      canvas.drawCircle(
        center,
        2.5,
        Paint()..color = Colors.white.withOpacity(0.9),
      );
    }
  }

  /// Реальные материалы фасадов НВ: панель 1-464/468 кремовая,
  /// кирпич силикатный терракотовый, серая панель, современные ЖК.
  /// 73% зданий OSM без типа получают процедурную типологию по
  /// высоте: хрущёвки 5 эт — кирпич, 9 эт — панель, 12+ — ЖК.
  Color _facadeMaterial(_Bld b) {
    // Палитра от Гермеса (изучена по фото реального дома) — приоритет
    final hermes = b.facadePalette;
    if (hermes != null && hermes.isNotEmpty) {
      return hermes[(b.seed.toInt()) % hermes.length];
    }
    final cat = b.category;
    final variant = (b.seed.toInt()) % 4;
    final heightM = b.zTop - b.zBottom;
    // Нетипизированные здания («Здание») — выводим материал из высоты
    if (cat.isEmpty || cat == 'Здание') {
      if (heightM >= 34) {
        // высотки: современные материалы — цветная штукатурка/навесной фасад
        return switch (variant) {
          0 => const Color(0xFFB0693F),
          1 => const Color(0xFF7F9BB3),
          2 => const Color(0xFFC9A44C),
          _ => const Color(0xFF93A8A0),
        };
      }
      if (heightM >= 21) {
        // 9-этажки: типовая панель
        return switch (variant) {
          0 => const Color(0xFFD8CFC0),
          1 => const Color(0xFFC9C5BC),
          2 => const Color(0xFFB8B4AC),
          _ => const Color(0xFFDFD8CC),
        };
      }
      if (heightM >= 12) {
        // 5-этажки: силикатный кирпич
        return switch (variant) {
          0 => const Color(0xFFC4886B),
          1 => const Color(0xFFB07A5E),
          2 => const Color(0xFFCFC5B8),
          _ => const Color(0xFFBFA89A),
        };
      }
      // малоэтажка: дерево/штукатурка частного сектора
      return switch (variant) {
        0 => const Color(0xFFA98F76),
        1 => const Color(0xFFB5A48D),
        2 => const Color(0xFF9E8E7B),
        _ => const Color(0xFF8FA08F),
      };
    }
    if (cat.contains('Жилой') || cat.contains('МКД')) {
      // Советская панель: кремовый / светло-серый / белый с потемнением
      return switch (variant) {
        0 => const Color(0xFFD8CFC0), // кремовая панель (типовая 1-464)
        1 => const Color(0xFFC9C5BC), // серо-бежевая (468-я серия)
        2 => const Color(0xFFB8B4AC), // потемневшая панель
        _ => const Color(0xFFDFD8CC), // светлая после ремонта
      };
    }
    if (cat.contains('5-этажный')) {
      return switch (variant) {
        0 => const Color(0xFFC4886B), // силикатный кирпич терракот
        1 => const Color(0xFFB07A5E),
        2 => const Color(0xFFCFC5B8),
        _ => const Color(0xFFBFA89A),
      };
    }
    if (cat.contains('Высотный') || cat.contains('высотн')) {
      // современные ЖК: цветная штукатурка
      return switch (variant) {
        0 => const Color(0xFFB0693F),
        1 => const Color(0xFF7F9BB3),
        2 => const Color(0xFFC9A44C),
        _ => const Color(0xFF93A8A0),
      };
    }
    if (cat.contains('Образование')) return const Color(0xFFE0A98E);
    if (cat.contains('Детский')) return const Color(0xFFF2C094);
    if (cat.contains('Здраво')) return const Color(0xFFBEDDD6);
    if (cat.contains('Торговля') || cat.contains('Торговый')) {
      return switch (variant) {
        0 => const Color(0xFF8E9BAA),
        1 => const Color(0xFFA79BB5),
        _ => const Color(0xFF9AA7A2),
      };
    }
    if (cat.contains('Промзона') || cat.contains('Склад')) {
      return switch (variant) {
        0 => const Color(0xFF8D9398),
        1 => const Color(0xFF7A8288),
        _ => const Color(0xFF9CA3A8),
      };
    }
    if (cat.contains('Гараж')) return const Color(0xFF8B9296);
    if (cat.contains('Административ')) return const Color(0xFFA8BCCB);
    // частный сектор / прочее
    return switch (variant) {
      0 => const Color(0xFFA98F76), // дерево/брус
      1 => const Color(0xFFB5A48D),
      2 => const Color(0xFF9E8E7B),
      _ => const Color(0xFF8FA08F),
    };
  }

  /// Атмосферная перспектива: смешивание цвета с дымкой по глубине (astra 2.5)
  /// β зависит от погоды: туман 45/48 даёт β≈0.005 (astra 1.6)
  Color _applyHaze(Color lit, double depthM) {
    final beta = weather.fogBeta;
    final start = beta > 0.002 ? 60.0 : 500.0; // туман начинается ближе
    final maxA = beta > 0.002 ? 0.92 : 0.40;
    final d = math.max(0.0, depthM - start);
    final alpha = (1.0 - math.exp(-beta * d)).clamp(0.0, maxA).toDouble();
    if (alpha < 0.02) return lit;
    // цвет тумана светлее ночью темнее — возьмём нейтральный от неба
    final fogColor = sunElevation > 0
        ? const Color(0xFFCEDBE0)
        : const Color(0xFF1A2530);
    return Color.lerp(lit, fogColor, alpha)!;
  }

  Color _shade(Color c, double f) {
    return Color.fromRGBO(
      (c.red * f).clamp(0, 255).round(),
      (c.green * f).clamp(0, 255).round(),
      (c.blue * f).clamp(0, 255).round(),
      1,
    );
  }

  // --- Вода ---

  void _paintWater(Canvas canvas, double t) {
    // Марджин города уменьшается с уровнем: 500см → 600м, 1100см → -80м
    final levelT = ((waterLevel - 500) / 600).clamp(0.0, 1.0);
    final margin = 600 - 680 * levelT;
    final r = worldBounds;

    // Вода — рамка вокруг города: строим из четырёх трапеций в проекции
    final projected = Path();
    void addQuad(Offset a, Offset b, Offset c, Offset d) {
      final pa = _p(a.dx, a.dy, 0);
      final pb = _p(b.dx, b.dy, 0);
      final pc = _p(c.dx, c.dy, 0);
      final pd = _p(d.dx, d.dy, 0);
      projected.moveTo(pa.dx, pa.dy);
      projected.lineTo(pb.dx, pb.dy);
      projected.lineTo(pc.dx, pc.dy);
      projected.lineTo(pd.dx, pd.dy);
      projected.close();
    }

    final o = Rect.fromLTRB(
        r.left - 3000, r.top - 3000, r.right + 3000, r.bottom + 3000);
    final i = Rect.fromLTRB(
        r.left - margin, r.top - margin, r.right + margin, r.bottom + margin);
    addQuad(o.topLeft, o.topRight, i.topRight, i.topLeft); // север
    addQuad(o.topRight, o.bottomRight, i.bottomRight, i.topRight); // восток
    addQuad(o.bottomRight, o.bottomLeft, i.bottomLeft, i.bottomRight); // юг
    addQuad(o.bottomLeft, o.topLeft, i.topLeft, i.bottomLeft); // запад

    canvas.drawPath(
      projected,
      Paint()
        ..color = const Color(0xFF0284C7).withOpacity(0.30)
        ..style = PaintingStyle.fill,
    );

    // Блики-волны
    final gl = Paint()..color = const Color(0xFF67E8F9).withOpacity(0.20);
    final rnd = math.Random(7);
    for (int k = 0; k < 130; k++) {
      final side = rnd.nextInt(4);
      double wx, wy;
      if (side == 0) {
        wx = o.left + rnd.nextDouble() * o.width;
        wy = o.top + rnd.nextDouble() * math.max(1, i.top - o.top);
      } else if (side == 1) {
        wx = i.right + rnd.nextDouble() * math.max(1, o.right - i.right);
        wy = o.top + rnd.nextDouble() * o.height;
      } else if (side == 2) {
        wx = o.left + rnd.nextDouble() * o.width;
        wy = i.bottom + rnd.nextDouble() * math.max(1, o.bottom - i.bottom);
      } else {
        wx = o.left + rnd.nextDouble() * math.max(1, i.left - o.left);
        wy = o.top + rnd.nextDouble() * o.height;
      }
      final wave = 0.6 * math.sin(0.08 * wx + 1.3 * t) +
          0.4 * math.sin(0.05 * wy - 0.9 * t);
      final sp = _p(wx, wy + wave * 3, 0);
      canvas.drawCircle(sp, 1.4 + wave.abs() * 1.2, gl);
    }
  }

  // --- Камеры ---

  void _paintCameraFov(Canvas canvas, _Cam3D cam, double t) {
    final center = _p(cam.x, cam.y, cam.elevationM);
    if (!_onScreen(center, 100)) return;
    // Сектор FOV на земле
    final heading = cam.headingDeg * math.pi / 180;
    final half = cam.fovDeg * math.pi / 360;
    final path = Path()..moveTo(center.dx, center.dy);
    for (int a = 0; a <= 16; a++) {
      final ang = heading - half + (half * 2) * a / 16;
      final ex = cam.x + math.sin(ang) * cam.rangeM;
      final ey = cam.y + math.cos(ang) * cam.rangeM;
      final sp = _p(ex, ey, 0);
      path.lineTo(sp.dx, sp.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF10B981).withOpacity(0.10)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF10B981).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Мачта камеры
    final base = _p(cam.x, cam.y, 0);
    canvas.drawLine(
        base,
        center,
        Paint()
          ..color = const Color(0xFF10B981)
          ..strokeWidth = 2);
    canvas.drawCircle(
        center, 3.5, Paint()..color = const Color(0xFF10B981));
    // Пульс статуса
    final pulse = 0.5 + 0.5 * math.sin(t * 3 + cam.x);
    canvas.drawCircle(
      center,
      5 + pulse * 4,
      Paint()..color = const Color(0xFF10B981).withOpacity(0.35 * (1 - pulse)),
    );
  }

  // --- Доминанты ---

  void _paintLandmark(Canvas canvas, _Landmark lm, double t) {
    final top = _p(lm.x, lm.y, lm.heightM);
    final base = _p(lm.x, lm.y, 0);
    if (!_onScreen(base, 160)) return;
    // Вертикальная метка
    canvas.drawLine(
        base,
        top,
        Paint()
          ..color = lm.color
          ..strokeWidth = 2.5);
    final pulse = 0.5 + 0.5 * math.sin(t * 2.2 + lm.x);
    canvas.drawCircle(
      top,
      4 + pulse * 2,
      Paint()..color = lm.color.withOpacity(0.85),
    );
    canvas.drawCircle(
      top,
      7 + pulse * 6,
      Paint()..color = lm.color.withOpacity(0.25 * (1 - pulse)),
    );
    // Подпись: премиальный пин — иконка-ромб над НОМЕРОМ, название
    // строго ПОД иконкой по центру (не сбоку и не поверх)
    final tp = TextPainter(
      text: TextSpan(
        text: lm.name,
        style: const TextStyle(
            color: Color(0xFFF8FAFC), fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 0.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 150);
    final boxW = tp.width + 14;
    final boxX = top.dx - boxW / 2;
    final boxY = top.dy + 10;
    // Стеклянная капсула подписи
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxW, tp.height + 8),
        const Radius.circular(9),
      ),
      Paint()..color = const Color(0xFF0D1626).withOpacity(0.88),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxW, tp.height + 8),
        const Radius.circular(9),
      ),
      Paint()
        ..color = lm.color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tp.paint(canvas, Offset(boxX + 7, boxY + 4));
  }

  // --- Факелы Самотлора ---

  void _paintFlares(Canvas canvas, double t) {
    final flares = (flareData?['active_flares'] as List? ?? []);
    if (flares.isEmpty) return;
    // Схематический горизонт на северо-востоке
    final r = worldBounds;
    final anchor = _p(r.right + 1200, r.top - 1200, 0);
    if (!_onScreen(anchor, 600)) {
      // всё равно рисуем — горизонт может быть за краем при сильном зуме
    }
    // Земля горизонта
    final g1 = _p(r.right + 300, r.top - 300, 0);
    final g2 = _p(r.right + 2600, r.top - 2600, 0);
    canvas.drawLine(
      g1,
      g2,
      Paint()
        ..color = const Color(0xFFFB7185).withOpacity(0.3)
        ..strokeWidth = 1,
    );

    final n = flares.length;
    for (int i = 0; i < n; i++) {
      final f = flares[i];
      final heat = ((f['heat_mw'] as num?)?.toDouble() ?? 50);
      final intensity = (math.log(1 + heat) / 6).clamp(0.35, 1.0);
      final fx = anchor.dx + (i - (n - 1) / 2) * 70;
      final fy = anchor.dy + math.sin(i * 2.7) * 18;
      // Столб огня
      final rnd = math.Random(i * 977);
      for (int k = 0; k < 26; k++) {
        final life = (t * (0.9 + intensity * 0.6) + rnd.nextDouble()) % 1.0;
        final py = fy - life * (46 + 60 * intensity);
        final px = fx + math.sin(life * 6 + i) * (3 + life * 8);
        final alpha = math.pow(1 - life, 2).toDouble();
        final color = Color.lerp(
          const Color(0xFFFFB703),
          const Color(0xFFFB5607),
          life,
        )!;
        canvas.drawCircle(
          Offset(px, py),
          1.5 + (1 - life) * 3.2 * intensity,
          Paint()..color = color.withOpacity(alpha * 0.85),
        );
      }
      // Подпись
      final tp = TextPainter(
        text: TextSpan(
          text: '${f['field']} · ${f['heat_mw']} МВт',
          style: const TextStyle(color: Color(0xFFFB7185), fontSize: 9,
              fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(fx - tp.width / 2, fy + 8));
    }
    // Подпись сцены
    final label = TextPainter(
      text: const TextSpan(
        text: 'САМОТЛОР · ЭНЕРГЕТИЧЕСКИЙ ГОРИЗОНТ (СХЕМА)',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9,
            letterSpacing: 1.2, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(anchor.dx - label.width / 2, anchor.dy + 42));
  }

  // --- Снег ---

  void _paintSnow(Canvas canvas, double t) {
    final rnd = math.Random(11);
    final paint = Paint()..color = const Color(0xFFE0F2FE).withOpacity(0.8);
    for (int i = 0; i < 130; i++) {
      final speed = 22 + rnd.nextDouble() * 44;
      final depth = 0.4 + rnd.nextDouble() * 1.2; // три плана глубины
      final x0 = rnd.nextDouble() * size.width * 1.2;
      final y0 = rnd.nextDouble() * size.height;
      final x = (x0 + math.sin(t * 1.8 + i) * 14 * depth + t * 18 * depth) %
          (size.width + 40) -
          20;
      final y = (y0 + t * speed * depth) % (size.height + 20);
      canvas.drawCircle(Offset(x, y), 0.8 * depth + 0.6, paint);
    }
    // Накопление на «крышах» — лёгкая светлая полоса поверх контура города
  }

  /// Реалтайм дождь (astra 1.3): 3 слоя глубины, наклон по ветру, drawRawPoints-батчи
  void _paintRealtimeRain(Canvas canvas, double t) {
    final intensity = weather.rain;
    // ветер → экранный наклон (художественно ограничен 35°)
    final windPx = (weather.windMps * 6).clamp(0.0, 90.0);
    final rainPaint = Paint()
      ..color = const Color(0xFFB4C4CE)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    final layers = [
      (100, 5.0, 0.10, 280.0), // count, len, alpha, speed (дальний)
      (130, 9.0, 0.17, 440.0), // средний
      (70, 15.0, 0.24, 620.0), // ближний
    ];
    final rnd = math.Random(97);
    for (final (count, len, alpha, speed) in layers) {
      final n = (count * intensity).round();
      rainPaint.color = const Color(0xFFB4C4CE).withOpacity(alpha * intensity);
      final pts = <double>[];
      for (int i = 0; i < n; i++) {
        final x0 = rnd.nextDouble() * size.width;
        final phase = (t * speed + i * 97.3) % (size.height + len);
        final y0 = phase - len;
        pts.addAll([x0, y0, x0 - windPx * (len / 120), y0 + len]);
      }
      final flat = Float32List.fromList(pts);
      canvas.drawRawPoints(PointMode.lines, flat, rainPaint);
    }
  }

  /// Реалтайм снег (astra 1.5): 3 слоя, drift по ветру
  void _paintRealtimeSnow(Canvas canvas, double t) {
    final intensity = weather.snow;
    final windDrift = weather.windMps * 3;
    final layers = [
      (90, 0.8, 0.20, 17.0),  // дальний
      (100, 1.4, 0.38, 30.0), // средний
      (45, 2.3, 0.55, 48.0),  // ближний
    ];
    final rnd = math.Random(31);
    for (final (count, r, alpha, speed) in layers) {
      final n = (count * intensity).round();
      final paint = Paint()
        ..color = Colors.white.withOpacity(alpha * (0.5 + 0.5 * intensity));
      for (int i = 0; i < n; i++) {
        final baseX = rnd.nextDouble() * size.width;
        final baseY = rnd.nextDouble() * size.height;
        // drift: синус на группы (astra — не на каждую снежинку)
        final grp = i % 12;
        final drift = math.sin(t * (0.6 + grp * 0.07) + grp) * 6 + windDrift;
        final x = (baseX + drift) % size.width;
        final y = (baseY + t * speed * (0.7 + (i % 5) * 0.12)) % size.height;
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  bool _onScreen(Offset p, double margin) {
    return p.dx >= -margin &&
        p.dx <= size.width + margin &&
        p.dy >= -margin &&
        p.dy <= size.height + margin;
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}

// ---------------------------------------------------------------------------
// Компас
// ---------------------------------------------------------------------------

class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.azimuth});
  final double azimuth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.width / 2 - 3,
        Paint()..color = const Color(0x2994A3B8).withOpacity(0.3));
    // Север в мире (0,1) → экран
    final cosA = math.cos(azimuth), sinA = math.sin(azimuth);
    final nrx = -sinA, nry = cosA;
    final dx = (nrx - nry) * 0.8660254;
    final dy = -(nrx + nry) * 0.5;
    final len = size.width / 2 - 6;
    final n = Offset(dx, dy) * len;
    canvas.drawLine(c, c + n,
        Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 2);
    canvas.drawCircle(c + n, 2.5, Paint()..color = const Color(0xFF00E5FF));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.azimuth != azimuth;
}

/// Схема «Моё окно»: дом сверху-сбоку, выбранный этаж, сектор солнца
class _MyWindowPainter extends CustomPainter {
  _MyWindowPainter({
    required this.building,
    required this.azimuth,
    required this.sunAzimuthRad,
    required this.sunElevation,
    required this.floor,
    required this.maxFloor,
  });

  final _Bld building;
  final double azimuth;
  final double sunAzimuthRad;
  final double sunElevation;
  final int floor;
  final int maxFloor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 18);
    // Проекция здания (упрощённая изометрия)
    Offset p(double x, double y, double z) {
      final cosA = math.cos(azimuth), sinA = math.sin(azimuth);
      final xr = x * cosA - y * sinA;
      final yr = x * sinA + y * cosA;
      final s = math.min(size.width, size.height) / 90.0;
      return Offset(
        c.dx + (xr - yr) * 0.866 * s,
        c.dy - (-(xr + yr) * 0.5 - z * 1.25) * s,
      );
    }

    final r = building.radius > 0 ? building.radius : 15.0;
    final h = building.zTop - building.zBottom;

    // Основание
    final b1 = p(-r, -r, 0), b2 = p(r, -r, 0), b3 = p(r, r, 0), b4 = p(-r, r, 0);
    final ground = Path()
      ..moveTo(b1.dx, b1.dy)
      ..lineTo(b2.dx, b2.dy)
      ..lineTo(b3.dx, b3.dy)
      ..lineTo(b4.dx, b4.dy)
      ..close();
    canvas.drawPath(ground, Paint()..color = const Color(0xFF111C30));
    canvas.drawPath(ground, Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // Фасад (юго-западная видимая грань)
    final t1 = p(-r, -r, h), t2 = p(r, -r, h), t3 = p(r, r, h), t4 = p(-r, r, h);
    final side = Path()
      ..moveTo(b1.dx, b1.dy)
      ..lineTo(b2.dx, b2.dy)
      ..lineTo(t2.dx, t2.dy)
      ..lineTo(t1.dx, t1.dy)
      ..close();
    canvas.drawPath(side, Paint()..color = const Color(0xFF24344D));
    final side2 = Path()
      ..moveTo(b2.dx, b2.dy)
      ..lineTo(b3.dx, b3.dy)
      ..lineTo(t3.dx, t3.dy)
      ..lineTo(t2.dx, t2.dy)
      ..close();
    canvas.drawPath(side2, Paint()..color = const Color(0xFF1A2A40));
    // Крыша
    final roof = Path()
      ..moveTo(t1.dx, t1.dy)
      ..lineTo(t2.dx, t2.dy)
      ..lineTo(t3.dx, t3.dy)
      ..lineTo(t4.dx, t4.dy)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF3A4A5D));

    // Выбранный этаж: светящаяся полоса
    final floorZ = (floor - 1) * h / math.max(1, maxFloor) + 1.5;
    final fw1 = p(-r, -r, floorZ), fw2 = p(r, -r, floorZ);
    final fw3 = p(r, -r, floorZ + 2.8), fw4 = p(-r, -r, floorZ + 2.8);
    final band = Path()
      ..moveTo(fw1.dx, fw1.dy)
      ..lineTo(fw2.dx, fw2.dy)
      ..lineTo(fw3.dx, fw3.dy)
      ..lineTo(fw4.dx, fw4.dy)
      ..close();
    canvas.drawPath(band, Paint()..color = const Color(0xFFFFC879).withOpacity(0.85));

    // Солнце: направление от азимута
    if (sunElevation > 0) {
      final sunAngle = sunAzimuthRad;
      final sunPos = Offset(
        c.dx - math.sin(sunAngle) * size.width * 0.34,
        c.dy - size.height * 0.34 - sunElevation * 1.2,
      );
      // луч к зданию
      final ray = Paint()
        ..color = const Color(0xFFFFC879).withOpacity(0.35)
        ..strokeWidth = 1.5;
      canvas.drawLine(sunPos, Offset(c.dx, c.dy - h * 0.5), ray);
      // диск
      canvas.drawCircle(sunPos, 12,
          Paint()..shader = RadialGradient(colors: const [
            Color(0xFFFFFBF0), Color(0xFFFFE9A8), Color(0xFFFFC879),
          ]).createShader(Rect.fromCircle(center: sunPos, radius: 12)));
      // подпись
      final tp = TextPainter(
        text: TextSpan(text: '☀ ${sunElevation.toStringAsFixed(0)}°',
            style: const TextStyle(color: Color(0xFFFFC879), fontSize: 10,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, sunPos + Offset(-tp.width / 2, -24));
    } else {
      final tp = TextPainter(
        text: const TextSpan(text: '🌙 солнце под горизонтом',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, 8));
    }
  }

  @override
  bool shouldRepaint(_MyWindowPainter old) =>
      old.floor != floor || old.azimuth != azimuth || old.sunAzimuthRad != sunAzimuthRad;
}

// ---------------------------------------------------------------------------
// Загрузка / ошибка
// ---------------------------------------------------------------------------

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Промо-арт двойника (сгенерирован топовой image-моделью)
          Opacity(
            opacity: 0.55,
            child: Image.network(
              '${MapConfig.backendBaseUrl}/twin_hero.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
          Container(color: const Color(0xFF0F172A).withOpacity(0.45)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                      color: Color(0xFF00E5FF), strokeWidth: 2.5),
                ),
                const SizedBox(height: 16),
                const Text('Строим 3D-модель Нижневартовска…',
                    style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('10 560 зданий • река Обь • затопление в реальном времени',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFF94A3B8), size: 40),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 14)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
                foregroundColor: const Color(0xFF00E5FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
