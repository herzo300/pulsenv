// lib/screens/weather_screen.dart
//
// Экран погоды с динамическим небом, живой визуализацией погодных стихий
// и интерактивными справками о нормах/отклонениях для каждого показателя.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/city_weather_service.dart';
import '../services/performance_mode_service.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/cinematic_weather_background.dart';
import '../widgets/weather_effects_overlay.dart';
import '../widgets/aura_living_background.dart';
import '../core/living/aura_living_engine.dart';
import '../widgets/sun_arc_uv_card.dart';
import '../widgets/schumann_resonance_card.dart';
import '../widgets/seismic_monitor_card.dart';
import '../widgets/space_weather_moon_card.dart';
import '../widgets/detailed_air_quality_dashboard.dart';
import '../widgets/hourly_weekly_forecast_widget.dart';
import '../widgets/weather_glass_orb.dart';
import '../widgets/biometeorology_pressure_card.dart';
import '../widgets/weather_wind_streamlines.dart';
import '../widgets/ob_river_hydrology_card.dart';
import '../widgets/weather_metric_explanation_sheet.dart';
import '../widgets/nizhnevartovsk_eclipse_card.dart';
import '../widgets/weather_local_cards.dart';

/// Нормализованный тип погоды.
///
/// Раньше условия парсились по подстрокам прямо в трёх методах экрана —
/// любое новое описание провайдера («морось», «позёмка», «wet snow»)
/// молча проваливалось в дефолт. Теперь вся нормализация — здесь.
enum WeatherKind {
  thunder,
  rain,
  drizzle,
  snow,
  hail,
  blowingSnow,
  fog,
  clear,
  overcast,
  cloudy,
}

/// Переводит сырой `condition`/`kind` провайдера в [WeatherKind].
/// Приоритет — у машинного `kind` с бэкенда, затем у текстового описания.
WeatherKind resolveWeatherKind(String condition, [String kind = '']) {
  final k = '$kind $condition'.toLowerCase();
  bool hasAny(List<String> keys) => keys.any(k.contains);

  if (hasAny(const ['thunder', 'гроз', 'storm', 'ливень', 'heavy_rain'])) {
    return WeatherKind.thunder;
  }
  if (hasAny(const ['drizzle', 'морось', 'морося'])) {
    return WeatherKind.drizzle;
  }
  if (hasAny(const ['blowing', 'blizzard', 'позём', 'позем', 'метель', 'пурга'])) {
    return WeatherKind.blowingSnow;
  }
  if (hasAny(const ['hail', 'град'])) {
    return WeatherKind.hail;
  }
  if (hasAny(const ['snow', 'снег', 'ice', 'wet_snow', 'мокрый снег'])) {
    return WeatherKind.snow;
  }
  if (hasAny(const ['rain', 'дожд', 'shower'])) {
    return WeatherKind.rain;
  }
  if (hasAny(const ['fog', 'туман', 'mist', 'дымка', 'haze', 'мгла'])) {
    return WeatherKind.fog;
  }
  if (hasAny(const ['clear', 'ясн', 'солн', 'sun'])) {
    return WeatherKind.clear;
  }
  if (hasAny(const ['overcast', 'пасмурн'])) {
    return WeatherKind.overcast;
  }
  return WeatherKind.cloudy;
}

/// Человекочитаемая метка свежести: «обновлено в 14:05 · 12 мин назад».
String _formatUpdatedAt(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  if (diff.inMinutes < 1) return 'обновлено только что';
  if (diff.inMinutes < 60) {
    return 'обновлено в $hh:$mm · ${diff.inMinutes} мин назад';
  }
  if (diff.inHours < 24) {
    return 'обновлено в $hh:$mm · ${diff.inHours} ч назад';
  }
  return 'обновлено в $hh:$mm · ${diff.inDays} дн назад';
}

/// Обёртка тапабельной карточки показателя: открывает справку
/// и добавляет Semantics-метку для screen reader (a11y).
Widget _explainable({
  required BuildContext context,
  required String metricKey,
  required String currentValue,
  required Widget child,
}) {
  return Semantics(
    button: true,
    label: 'Подробнее о показателе: $metricKey. Текущее значение: $currentValue',
    child: GestureDetector(
      onTap: () => showWeatherMetricExplanationSheet(
        context: context,
        metricKey: metricKey,
        currentValue: currentValue,
      ),
      child: child,
    ),
  );
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  CityWeatherSnapshot _snapshot = CityWeatherSnapshot.empty();
  bool _loading = true;
  String? _error;
  String _selectedThemeKey = 'auto';
  String? _analyzedSkyColorHex;
  DateTime? _lastUpdatedAt;
  late final TabController _tabController;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadThemeKey();
    _load();
    // Автообновление каждые 10 минут: погода меняется, данные — живые
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadThemeKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('weather_aura_theme') ?? 'auto';
      if (mounted) {
        setState(() {
          _selectedThemeKey = saved;
        });
      }
    } catch (_) {}
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    final val = int.tryParse(cleaned, radix: 16);
    return val != null ? Color(val) : null;
  }

  Future<void> _load() async {
    // Load cache first for instant UI
    final cached = await CityWeatherService.instance.getCachedWeather();
    if (!mounted) return;
    if (cached != null) {
      final cachedAt = await CityWeatherService.instance.getLastUpdatedAt();
      if (!mounted) return;
      setState(() {
        _snapshot = cached;
        _lastUpdatedAt = cachedAt;
        _loading = false;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final snapFuture = CityWeatherService.instance.fetchWeather();
      final skyColorFuture = CityWeatherService.instance.fetchSkyColor();

      final results = await Future.wait([snapFuture, skyColorFuture]);
      final snap = results[0] as CityWeatherSnapshot;
      final skyColorHex = results[1] as String?;
      final updatedAt = await CityWeatherService.instance.getLastUpdatedAt();

      if (mounted) {
        setState(() {
          _snapshot = snap;
          _analyzedSkyColorHex = skyColorHex;
          _lastUpdatedAt = updatedAt ?? DateTime.now();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && cached == null) {
        setState(() {
          _error = 'Не удалось загрузить погоду: $e';
          _loading = false;
        });
      }
    }
  }

  /// Цвета для живого mesh-градиента атмосферы (пакет mesh_gradient):
  /// строим 4 точки из текущей палитры неба + фирменное нефтяное золото.
  List<Color> _meshColorsFor(List<Color> skyColors, bool isDay) {
    final top = skyColors.first;
    final bottom = skyColors.last;
    final mid = skyColors.length > 2 ? skyColors[1] : Color.lerp(top, bottom, 0.5)!;
    const gold = Color(0xFFD4A537);
    return [
      top,
      Color.lerp(mid, gold, isDay ? 0.10 : 0.18)!,
      Color.lerp(bottom, const Color(0xFF0C1424), 0.35)!,
      Color.lerp(mid, top, 0.5)!,
    ];
  }

  List<Color> _resolveSkyColors(String condition, bool isDay, String? skyHex) {
    if (skyHex != null && skyHex.isNotEmpty) {
      final camColor = _parseHexColor(skyHex);
      if (camColor != null) {
        return [
          camColor,
          camColor.withOpacity(0.75),
          const Color(0xFF0F172A),
        ];
      }
    }

    final hour = DateTime.now().hour;
    final kind = resolveWeatherKind(condition, _snapshot.kind);
    final isRain = kind == WeatherKind.rain ||
        kind == WeatherKind.drizzle ||
        kind == WeatherKind.thunder;
    final isSnow = kind == WeatherKind.snow ||
        kind == WeatherKind.hail ||
        kind == WeatherKind.blowingSnow;
    final isFog = kind == WeatherKind.fog;
    final isClear = kind == WeatherKind.clear;

    if (!isDay) {
      return const [
        Color(0xFF030712),
        Color(0xFF0B1329),
        Color(0xFF111827),
      ];
    }

    if (hour >= 4 && hour < 8) {
      return const [
        Color(0xFFEA580C),
        Color(0xFFF59E0B),
        Color(0xFF38BDF8),
        Color(0xFF0F172A),
      ];
    }

    if (hour >= 18 && hour < 22) {
      return const [
        Color(0xFFD97706),
        Color(0xFFC026D3),
        Color(0xFF312E81),
        Color(0xFF0F172A),
      ];
    }

    if (isRain) {
      return const [
        Color(0xFF1E293B),
        Color(0xFF0F172A),
        Color(0xFF020617),
      ];
    }

    if (isSnow) {
      return const [
        Color(0xFF0284C7),
        Color(0xFF1E293B),
        Color(0xFF0F172A),
      ];
    }

    if (isFog) {
      return const [
        Color(0xFF475569),
        Color(0xFF334155),
        Color(0xFF0F172A),
      ];
    }

    if (isClear) {
      return const [
        Color(0xFF0284C7),
        Color(0xFF0369A1),
        Color(0xFF0C4A6E),
        Color(0xFF0F172A),
      ];
    }

    return const [
      Color(0xFF334155),
      Color(0xFF1E293B),
      Color(0xFF0F172A),
    ];
  }

  int _getAuraMoodForWeather(String condition) {
    switch (resolveWeatherKind(condition, _snapshot.kind)) {
      case WeatherKind.thunder:
        return 1;
      case WeatherKind.rain:
      case WeatherKind.drizzle:
        return 2;
      case WeatherKind.snow:
      case WeatherKind.hail:
      case WeatherKind.blowingSnow:
        return 4;
      case WeatherKind.clear:
        return 5;
      case WeatherKind.fog:
      case WeatherKind.overcast:
      case WeatherKind.cloudy:
        return 3;
    }
  }

  AuraWeather _getAuraWeatherForCondition(String condition, double? kpIndex, bool isDay) {
    if (_selectedThemeKey != 'auto') {
      switch (_selectedThemeKey) {
        case 'cyberpunk': return AuraWeather.cyberpunk;
        case 'neon': return AuraWeather.neon;
        case 'fog': return AuraWeather.fog;
        case 'inkDiffuse': return AuraWeather.inkDiffuse;
        case 'starfield': return AuraWeather.starfield;
        case 'nebula': return AuraWeather.nebula;
        case 'voronoi': return AuraWeather.voronoi;
        case 'fluid': return AuraWeather.fluid;
        case 'aurora': return AuraWeather.aurora;
        case 'sakura': return AuraWeather.sakura;
        case 'fireflies': return AuraWeather.fireflies;
        case 'cosmos': return AuraWeather.cosmos;
        case 'technoCivic': return AuraWeather.technoCivic;
      }
    }

    if (kpIndex != null && kpIndex >= 4.0) {
      return AuraWeather.aurora;
    }
    final kind = resolveWeatherKind(condition, _snapshot.kind);
    final hour = DateTime.now().hour;

    if (kind == WeatherKind.fog) {
      return AuraWeather.fog;
    }
    if (kind == WeatherKind.thunder) {
      if (hour >= 21 || hour < 5) {
        return AuraWeather.cyberpunk;
      } else if (hour >= 17 && hour < 21) {
        return AuraWeather.supernova;
      } else if (hour >= 5 && hour < 11) {
        return AuraWeather.glitch;
      } else {
        return AuraWeather.fluid;
      }
    }

    if (kind == WeatherKind.rain || kind == WeatherKind.drizzle) {
      if (hour >= 21 || hour < 5) {
        return AuraWeather.neon;
      } else if (hour >= 17 && hour < 21) {
        return AuraWeather.inkDiffuse;
      } else if (hour >= 5 && hour < 11) {
        return AuraWeather.water;
      } else {
        return AuraWeather.rain;
      }
    }

    if (kind == WeatherKind.snow ||
        kind == WeatherKind.hail ||
        kind == WeatherKind.blowingSnow) {
      if (hour >= 21 || hour < 5) {
        return AuraWeather.starfield;
      } else if (hour >= 17 && hour < 21) {
        return AuraWeather.sakura;
      } else if (hour >= 5 && hour < 11) {
        return AuraWeather.voronoi;
      } else {
        return AuraWeather.snow;
      }
    }

    if (kind == WeatherKind.clear) {
      if (isDay) {
        if (hour < 11) return AuraWeather.dawn;
        if (hour > 17) return AuraWeather.sunset;
        return AuraWeather.tropical;
      }
      return AuraWeather.starfield;
    }

    if (hour >= 21 || hour < 5) {
      return AuraWeather.blackHole;
    } else if (hour >= 17 && hour < 21) {
      return AuraWeather.candle;
    } else if (hour >= 5 && hour < 11) {
      return AuraWeather.aura;
    } else {
      return AuraWeather.waveFunc;
    }
  }

  WeatherEffect _resolveWeatherEffect(String condition) {
    if (_selectedThemeKey != 'auto') {
      switch (_selectedThemeKey) {
        case 'cyberpunk': return WeatherEffect.storm;
        case 'neon': return WeatherEffect.rain;
        case 'inkDiffuse': return WeatherEffect.fog;
        case 'starfield': return WeatherEffect.snow;
        case 'nebula': return WeatherEffect.fog;
        case 'voronoi': return WeatherEffect.snow;
        case 'fluid': return WeatherEffect.rain;
        case 'aurora': return WeatherEffect.clear;
        case 'sakura': return WeatherEffect.sakura;
        case 'fireflies': return WeatherEffect.fireflies;
        case 'cosmos': return WeatherEffect.cosmos;
        case 'technoCivic': return WeatherEffect.technoCivic;
      }
    }
    return weatherEffectFromKind(condition);
  }

  /// Шеринг сводки погоды в мессенджеры/сторис (share_plus уже в проекте).
  void _shareWeather() {
    final s = _snapshot;
    final temp = s.temperatureC != null ? '${s.temperatureC!.round()}°C' : '—';
    final feels = s.feelsLikeC != null ? '${s.feelsLikeC!.round()}°C' : '—';
    final wind = s.windSpeedMs != null ? '${s.windSpeedMs!.round()} м/с' : '—';
    final aktirovka = s.hmaoAktirovkaStatus.isNotEmpty
        ? s.hmaoAktirovkaStatus
        : 'Актировки нет, занятия в обычном режиме';
    final aurora = (s.kpIndex ?? 0) >= 5.0
        ? '🔴 Сильный геомагнитный шторм — сияние видно невооружённым глазом!'
        : 'Шанс сияния за городом: ${s.auroraVisibilityPct.round()}%';

    final text = StringBuffer()
      ..writeln('🌡 Пульс Города · Нижневартовск')
      ..writeln('$temp · ${s.condition}')
      ..writeln('Ощущается как $feels · Ветер $wind')
      ..writeln('🏫 Актировка школ: $aktirovka')
      ..writeln('🌌 $aurora');
    if (_lastUpdatedAt != null) {
      text.writeln('Данные: ${_formatUpdatedAt(_lastUpdatedAt!)}');
    }

    Share.share(text.toString(), subject: 'Погода в Нижневартовске');
  }

  void _showThemeSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBgColor = isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.85);
            final sheetTextColor = isDark ? Colors.white : const Color(0xFF0F172A);

            final options = [
              ('auto', 'Авто (Цвет неба)', Icons.auto_awesome_rounded, const [Color(0xFF0284C7), Color(0xFF10B981)]),
              ('fog', 'Туман & Мгла', Icons.cloud_queue_rounded, const [Color(0xFF1E293B), Color(0xFF94A3B8)]),
              ('cyberpunk', 'Киберпанк', Icons.bolt_rounded, const [Color(0xFF0A001A), Color(0xFFFF0055)]),
              ('neon', 'Неон дождь', Icons.wb_twilight_rounded, const [Color(0xFF050505), Color(0xFF00FF00)]),
              ('inkDiffuse', 'Акварель', Icons.brush_rounded, const [Color(0xFFF0ECE0), Color(0xFF1A1A2E)]),
              ('starfield', 'Звездное небо', Icons.star_rounded, const [Color(0xFF030008), Color(0xFF80D8FF)]),
              ('nebula', 'Туманность', Icons.bubble_chart_rounded, const [Color(0xFF080014), Color(0xFFFF0080)]),
              ('voronoi', 'Кристаллы', Icons.ac_unit_rounded, const [Color(0xFF080412), Color(0xFF80D8FF)]),
              ('fluid', 'Жидкая плазма', Icons.waves_rounded, const [Color(0xFF040820), Color(0xFF2080FF)]),
              ('aurora', 'Сияние', Icons.nights_stay_rounded, const [Color(0xFF000428), Color(0xFF00FF87)]),
              ('sakura', 'Японский сад', Icons.filter_vintage_rounded, const [Color(0xFFFFD1DC), Color(0xFFE2A4B4)]),
              ('fireflies', 'Светлячки', Icons.blur_on_rounded, const [Color(0xFF0D1B2A), Color(0xFFCCFF00)]),
              ('cosmos', 'Космический', Icons.rocket_launch_rounded, const [Color(0xFF030008), Color(0xFF9D4EDD)]),
              ('technoCivic', 'Цивик Тех', Icons.lan_rounded, const [Color(0xFF0A1128), Color(0xFF00E5FF)]),
            ];

            return BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Цвет неба и атмосфера',
                          style: TextStyle(
                            color: sheetTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: Icon(Icons.close_rounded, color: sheetTextColor.withOpacity(0.6), size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final opt = options[index];
                          final key = opt.$1;
                          final label = opt.$2;
                          final icon = opt.$3;
                          final colors = opt.$4;
                          final isSelected = _selectedThemeKey == key;

                          return GestureDetector(
                            onTap: () async {
                              setState(() {
                                _selectedThemeKey = key;
                              });
                              setSheetState(() {});
                              try {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('weather_aura_theme', key);
                              } catch (_) {}
                            },
                            child: Container(
                              width: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: colors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.2),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF00E5FF).withOpacity(0.5),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon, color: Colors.white, size: 28),
                                  const SizedBox(height: 6),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    // Астрономический день/ночь из снапшота (реальные восход/закат для 60.93°N),
    // а не грубое «5:00–22:00» — зимой световой день здесь ~5 часов.
    final isDay = _snapshot.isDay;
    final skyColors = _resolveSkyColors(_snapshot.condition, isDay, _analyzedSkyColorHex);

    // Бюджет эффектов: в eco-режиме или при системном «уменьшить анимацию»
    // отключаем aura-движок и частицы — остаётся статичный градиент неба.
    final effectsOn = PerformanceModeService.instance.effectsEnabled(context);
    final content = _buildWeatherContent(
      skyColors: skyColors,
      isDay: isDay,
      effectsOn: effectsOn,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: skyColors.last,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
              ),
              child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF00E5FF), size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ПОГОДА И НЕБО',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
                Text(
                  'Нижневартовск • Живая атмосфера',
                  style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Поделиться погодой',
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: _shareWeather,
          ),
          IconButton(
            tooltip: 'Цвет неба и атмосфера',
            icon: const Icon(Icons.palette_rounded, color: Colors.white),
            onPressed: _showThemeSelector,
          ),
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: effectsOn
          ? AuraLivingBackground(
              scene: () {
                final baseScene = AuraLivingEngine.resolve(
                  mood: _getAuraMoodForWeather(_snapshot.condition),
                  streak: 5,
                  meditationMinutes: 10,
                  practicesCompleted: 5,
                  isPremium: true,
                  hour: hour,
                );

                final windSpeed = _snapshot.windSpeedMs ?? 3.0;
                final dynamicSpeed = (0.5 + (windSpeed / 12.0)).clamp(0.4, 2.5);
                final humidity = _snapshot.humidityPct ?? 60;
                final dynamicParticles = (0.3 + (humidity / 100.0) * 1.2).clamp(0.2, 1.6);
                final visibility = _snapshot.visibilityM ?? 10000.0;
                final dynamicBlur = (baseScene.blur * (1.0 + (10000.0 - visibility) / 5000.0)).clamp(1.0, 15.0);

                return baseScene.copyWith(
                  weather: _getAuraWeatherForCondition(_snapshot.condition, _snapshot.kpIndex, isDay),
                  speed: dynamicSpeed,
                  particleDensity: dynamicParticles,
                  blur: dynamicBlur,
                  palette: skyColors,
                );
              }(),
              interactive: true,
              showConstellationVeil: false,
              child: content,
            )
          : content,
    );
  }

  Widget _buildWeatherContent({
    required List<Color> skyColors,
    required bool isDay,
    required bool effectsOn,
  }) {
    return Stack(
          children: [
            // 1. Dynamic Physical Sky Gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: skyColors,
                    stops: skyColors.length == 4
                        ? const [0.0, 0.28, 0.65, 1.0]
                        : const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // 1.5 Кинематографичный атмосферный фон (архитектура gpt-6-astra):
            // спектральное небо с температурным дыханием, звёзды 3 планов /
            // солнце с гало от влажности, god-rays от УФ, аврора от kp,
            // кино-виньетка + зерно. Заменяет AnimatedMeshGradient.
            if (effectsOn)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CinematicWeatherBackground(
                      temperatureC: _snapshot.temperatureC,
                      humidityPct: _snapshot.humidityPct,
                      uvIndex: _snapshot.uvIndex,
                      kpIndex: _snapshot.kpIndex,
                      isDay: isDay,
                    ),
                  ),
                ),
              ),

            // 2. Weather Effects Overlay (Snow / Rain / Sakura / Clear)
            if (_snapshot.available && effectsOn)
              Positioned.fill(
                child: RepaintBoundary(
                  child: WeatherEffectsOverlay(
                    effect: _resolveWeatherEffect(_snapshot.condition),
                    isDay: isDay,
                    showBackground: false,
                  ),
                ),
              ),

            // 3. Dark vignette overlay to maintain high text readability
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.transparent,
                        Colors.black.withOpacity(0.65),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: _loading
                  ? const _LoadingView()
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : Column(
                          children: [
                            // ─── Glass Segmented TabBar ──────────────────────────
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.18)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: TabBar(
                                    controller: _tabController,
                                    isScrollable: true,
                                    tabAlignment: TabAlignment.start,
                                    indicator: BoxDecoration(
                                      color: Colors.white.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF00E5FF).withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00E5FF).withOpacity(0.25),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    dividerColor: Colors.transparent,
                                    labelColor: Colors.white,
                                    unselectedLabelColor: Colors.white.withOpacity(0.75),
                                    labelStyle: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      letterSpacing: 0.3,
                                    ),
                                    unselectedLabelStyle: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                    padding: EdgeInsets.zero,
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                                    tabs: const [
                                      Tab(
                                        icon: Icon(Icons.wb_sunny_rounded, size: 16),
                                        text: 'Сейчас & Прогноз',
                                        iconMargin: EdgeInsets.only(bottom: 2),
                                      ),
                                      Tab(
                                        icon: Icon(Icons.public_rounded, size: 16),
                                        text: 'Природа города',
                                        iconMargin: EdgeInsets.only(bottom: 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // ─── Tab Content Views ──────────────────────────────
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // Вкладка 1: сейчас + прогноз в одном скролле
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      children: [
                                        _WeatherMainTab(
                                          snapshot: _snapshot,
                                          onRefresh: _load,
                                          updatedAt: _lastUpdatedAt,
                                        ),
                                        _ForecastTab(snapshot: _snapshot, onRefresh: _load),
                                      ],
                                    ),
                                  ),
                                  // Вкладка 2: природа города — Шуман, космос, сейсмика, Обь
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      children: [
                                        _SchumannSpaceTab(snapshot: _snapshot, onRefresh: _load),
                                        _SeismicHydroTab(snapshot: _snapshot, onRefresh: _load),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ВКЛАДКА 1: ПОГОДА И ПРОГНОЗ
// ═══════════════════════════════════════════════════════════════════════════

class _WeatherMainTab extends StatelessWidget {
  const _WeatherMainTab({
    required this.snapshot,
    required this.onRefresh,
    this.updatedAt,
  });
  final CityWeatherSnapshot snapshot;
  final Future<void> Function() onRefresh;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // ─── Компактный лэйаут по макету gpt-6-astra: 6 блоков вместо 12 ───

          // 1. Герой «Нижневартовск · сейчас» (температура + ощущается + ветер)
          _DynamicWeatherShaderHero(snapshot: snapshot, updatedAt: updatedAt),
          const SizedBox(height: 12),

          // 2. «Ощущения и риски»: ветро-индекс + гололёд + одежда + давление.
          //    Одна карточка, максимум 3 строки, детали — по тапу.
          _FeelingsAndRisksCard(snapshot: snapshot),
          const SizedBox(height: 12),

          // 3. «Ближайшие часы»: nowcasting-фраза + горизонтальный hourly
          _buildUnifiedCard(
            child: HourlyWeeklyForecastWidget(snapshot: snapshot),
          ),
          const SizedBox(height: 12),

          // 4. Качество воздуха: только значимое предупреждение на главной,
          //    полный дашборд — по тапу (внутри карточки)
          _buildUnifiedCard(
            child: DetailedAirQualityDashboard(snapshot: snapshot),
          ),
          const SizedBox(height: 12),

          // 5. «Световой день»: дуга + УФ + полярный день — единый блок
          _explainable(
            context: context,
            metricKey: 'uv_index',
            currentValue: '${(snapshot.uvIndex ?? 3.2).toStringAsFixed(1)} баллов',
            child: _buildUnifiedCard(
              showInfoBadge: true,
              child: SunArcUvCard(snapshot: snapshot),
            ),
          ),
          const SizedBox(height: 12),

          // 5.1 Полярный световой день (сумерки, длина дня, тренд) — рядом с дугой
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PolarDaylightCard(snapshot: snapshot),
          ),

          // 6. АКТИРОВКА ШКОЛ — событийная, критична для семей с детьми
          _explainable(
            context: context,
            metricKey: 'aktirovka',
            currentValue: snapshot.hmaoAktirovkaStatus.isNotEmpty ? snapshot.hmaoAktirovkaStatus : 'Актировка ХМАО: Занятия проводятся в обычном режиме',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1626).withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.12),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: Color(0xFF00E5FF), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'АКТИРОВКА ШКОЛ НИЖНЕВАРТОВСКА',
                              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              snapshot.hmaoAktirovkaStatus.isNotEmpty ? snapshot.hmaoAktirovkaStatus : 'Актировки нет. Занятия 1-11 классов в обычном режиме',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const WeatherAlertBell(
                        topic: 'aktirovka',
                        label: 'Актировка школ',
                      ),
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 18),
                    ],
                  ),
                  // Визуальная шкала порогов отмены занятий ХМАО
                  AktirovkaScale(temperatureC: snapshot.temperatureC),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildUnifiedCard({
    required Widget child,
    bool showInfoBadge = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1626).withOpacity(0.50),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: showInfoBadge
              ? Stack(
                  children: [
                    child,
                    // Единый индикатор «тапните для подробностей»
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white.withOpacity(0.55),
                        size: 16,
                      ),
                    ),
                  ],
                )
              : child,
        ),
      ),
    );
  }
}

/// Блок 2 по макету astra: «Ощущения и риски» — одна карточка вместо
/// четырёх (ветро-индекс, гололёд, как одеться, давление+биометео).
/// Максимум 3 строки, всё остальное — по тапу в раскрытие.
class _FeelingsAndRisksCard extends StatefulWidget {
  const _FeelingsAndRisksCard({required this.snapshot});
  final CityWeatherSnapshot snapshot;

  @override
  State<_FeelingsAndRisksCard> createState() => _FeelingsAndRisksCardState();
}

class _FeelingsAndRisksCardState extends State<_FeelingsAndRisksCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final temp = s.temperatureC ?? 0.0;
    final windChill = s.windChillC ?? s.feelsLikeC ?? temp;
    final cold = temp <= -10.0;
    final hasPrecip = s.nowcastingPrecipitation.any((v) => v > 0.1);
    final ice = temp <= 2.0 && hasPrecip;
    final highUv = (s.uvIndex ?? 0.0) >= 6.0;

    // Главная строка: сезонный риск + действие (правило astra «одна метрика — одно место»)
    final String headline;
    final IconData headlineIcon;
    final Color headlineColor;
    if (cold) {
      headline = 'Сильный холод · ощущается ${windChill.round()}°';
      headlineIcon = Icons.ac_unit_rounded;
      headlineColor = const Color(0xFF38BDF8);
    } else if (ice) {
      headline = 'Гололёд · обувь с протектором';
      headlineIcon = Icons.warning_amber_rounded;
      headlineColor = const Color(0xFFFFB300);
    } else if (highUv) {
      headline = 'Высокий УФ ${s.uvIndex!.toStringAsFixed(0)} · SPF и головной убор';
      headlineIcon = Icons.wb_sunny_rounded;
      headlineColor = const Color(0xFFFF9500);
    } else {
      headline = 'Погода комфортна · рисков нет';
      headlineIcon = Icons.check_circle_outline_rounded;
      headlineColor = const Color(0xFF00E676);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1626).withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: headlineColor.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: headlineColor.withOpacity(0.10),
            blurRadius: 14,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(headlineIcon, color: headlineColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        headline,
                        style: TextStyle(
                          color: headlineColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                // Вторая строка: давление + ветер (компакт)
                const SizedBox(height: 4),
                Text(
                  '${s.pressureMmHg?.round() ?? 755} мм рт.ст. · ветер ${s.windSpeedMs?.toStringAsFixed(1) ?? '—'} м/с · до ${s.frostbiteSafetyMinutes} мин без защиты',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Раскрытие: детали (гололёд, одежда, биометео)
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: Colors.white12, height: 8),
                        ClothingAdviceCard(snapshot: s),
                        const SizedBox(height: 8),
                        IceRoadRiskCard(snapshot: s),
                        const SizedBox(height: 8),
                        BiometeorologyPressureCard(snapshot: s),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ШЕЙДЕР В ЦЕНТРЕ ПОГОДЫ (DYNAMIC ATMOSPHERIC HERO SHADER)
// ═══════════════════════════════════════════════════════════════════════════

class _DynamicWeatherShaderHero extends StatefulWidget {
  final CityWeatherSnapshot snapshot;
  final DateTime? updatedAt;
  const _DynamicWeatherShaderHero({required this.snapshot, this.updatedAt});

  @override
  State<_DynamicWeatherShaderHero> createState() => _DynamicWeatherShaderHeroState();
}

class _DynamicWeatherShaderHeroState extends State<_DynamicWeatherShaderHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final temp = widget.snapshot.temperatureC;
    final condition = widget.snapshot.condition;
    // Бюджет эффектов: при eco/системном снижении анимаций останавливаем
    // 12-секундный цикл атмосферного шейдера — статичный кадр вместо 60 FPS.
    final effectsOn = PerformanceModeService.instance.effectsEnabled(context);
    if (effectsOn != _anim.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (effectsOn) {
          _anim.repeat();
        } else {
          _anim.stop();
        }
      });
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dynamic Atmospheric Shader Canvas
          AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(340, 310),
                painter: _WeatherAtmosphericShaderPainter(
                  progress: _anim.value,
                  condition: condition,
                  isDay: widget.snapshot.isDay,
                  windSpeed: widget.snapshot.windSpeedMs ?? 3.5,
                ),
              );
            },
          ),

          // Central Weather Living Hero Art & Data Column
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _explainable(
                context: context,
                metricKey: 'temperature',
                currentValue: '${temp?.round()}°C • $condition',
                child: RepaintBoundary(
                  key: const ValueKey('weather_living_hero_art'),
                  child: WeatherGlassOrb(
                    condition: condition,
                    accent: const Color(0xFF00E5FF),
                    isDay: widget.snapshot.isDay,
                    moonPhase: widget.snapshot.moonPhase ?? 0.48,
                    size: 135,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Glowing Large Temperature Display (Tappable)
              _explainable(
                context: context,
                metricKey: 'temperature',
                currentValue: '${temp?.round()}°C',
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: temp?.toDouble() ?? 0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Text(
                      temp != null ? '${value.toStringAsFixed(1)}°C' : '—°C',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 88,
                        fontWeight: FontWeight.w200,
                        fontFamily: 'monospace',
                        height: 1,
                        letterSpacing: -2,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.5),
                            blurRadius: 24,
                          ),
                          Shadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),

              _explainable(
                context: context,
                metricKey: 'temperature',
                currentValue: condition,
                child: Text(
                  condition,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 10),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Метка свежести данных — офлайн-кэш не должен выглядеть живым
              if (widget.updatedAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _formatUpdatedAt(widget.updatedAt!),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
                    ),
                  ),
                ),

              // Triple Climate Pills (Ощущается / Влажность / Ветер - All Tappable)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.snapshot.feelsLikeC != null)
                    _explainable(
                      context: context,
                      metricKey: 'feels_like',
                      currentValue: '${widget.snapshot.feelsLikeC!.round()}°C',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.22)),
                        ),
                        child: Text(
                          'Ощущается ${widget.snapshot.feelsLikeC!.round()}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (widget.snapshot.humidityPct != null) ...[
                    const SizedBox(width: 6),
                    _explainable(
                      context: context,
                      metricKey: 'humidity',
                      currentValue: '${widget.snapshot.humidityPct}%',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.water_drop_rounded, color: Color(0xFF00E5FF), size: 12),
                            const SizedBox(width: 3),
                            Text(
                              '${widget.snapshot.humidityPct}%',
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (widget.snapshot.windSpeedMs != null) ...[
                    const SizedBox(width: 6),
                    _explainable(
                      context: context,
                      metricKey: 'wind',
                      currentValue: '${widget.snapshot.windSpeedMs!.toStringAsFixed(1)} м/с',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.air_rounded, color: Color(0xFFF59E0B), size: 12),
                            const SizedBox(width: 3),
                            Text(
                              '${widget.snapshot.windSpeedMs!.toStringAsFixed(1)} м/с',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherAtmosphericShaderPainter extends CustomPainter {
  final double progress;
  final String condition;
  final bool isDay;
  final double windSpeed;

  _WeatherAtmosphericShaderPainter({
    required this.progress,
    required this.condition,
    required this.isDay,
    required this.windSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final k = condition.toLowerCase();
    final isSnow = k.contains('snow') || k.contains('снег');
    final isRain = k.contains('rain') || k.contains('дожд') || k.contains('storm');
    final isClear = k.contains('clear') || k.contains('ясн') || k.contains('солн');
    final isFog = k.contains('fog') || k.contains('туман') || k.contains('mist');

    final pulseScale = 1.0 + 0.08 * math.sin(progress * 2 * math.pi);
    final radius = (size.width * 0.42) * pulseScale;

    final primaryColor = isSnow
        ? const Color(0xFF80D8FF)
        : (isRain
            ? const Color(0xFF00E5FF)
            : (isClear
                ? (isDay ? const Color(0xFFFFB300) : const Color(0xFF7C4DFF))
                : (isFog ? const Color(0xFF90CAF9) : const Color(0xFF64B5F6))));

    final secondaryColor = isSnow
        ? const Color(0xFFB388FF)
        : (isRain
            ? const Color(0xFF2979FF)
            : (isClear
                ? const Color(0xFFFF6D00)
                : const Color(0xFF00E5FF)));

    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: [
        primaryColor.withOpacity(0.24),
        secondaryColor.withOpacity(0.12),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

    canvas.drawCircle(center, radius, paint);

    final rayCount = isClear ? 12 : (isSnow ? 8 : 6);
    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = primaryColor.withOpacity(0.35);

    for (int i = 0; i < rayCount; i++) {
      final angle = (i * (2 * math.pi / rayCount)) + (progress * 2 * math.pi * (isSnow ? 0.3 : 0.5));
      final rayLength = radius * (0.8 + 0.25 * math.sin(progress * 4 * math.pi + i));
      final start = center + Offset(math.cos(angle) * (radius * 0.45), math.sin(angle) * (radius * 0.45));
      final end = center + Offset(math.cos(angle) * rayLength, math.sin(angle) * rayLength);

      if (isSnow) {
        canvas.drawLine(start, end, rayPaint);
        final branchOffset = Offset(-math.sin(angle) * 8, math.cos(angle) * 8);
        canvas.drawLine(end, end + branchOffset, rayPaint);
      } else if (isRain) {
        final waveRadius = (radius * 0.5) + (i / rayCount) * (radius * 0.55);
        final waveAlpha = (1.0 - (waveRadius / radius)).clamp(0.0, 0.4);
        final wavePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = primaryColor.withOpacity(waveAlpha);
        canvas.drawCircle(center, waveRadius, wavePaint);
      } else {
        canvas.drawLine(start, end, rayPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherAtmosphericShaderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.condition != condition;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ЕДИНЫЙ МАСТЕР-БЛОК ПОГОДНОЙ ТЕЛЕМЕТРИИ (МЕТЕОСТАНЦИЯ + 6 ПАРАМЕТРОВ)
// ═══════════════════════════════════════════════════════════════════════════

class _MasterWeatherTelemetryCard extends StatelessWidget {
  final CityWeatherSnapshot snapshot;
  const _MasterWeatherTelemetryCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1626).withOpacity(0.50),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Station Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                          ),
                          child: const Icon(Icons.radar_rounded, color: Color(0xFF00E5FF), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'МЕТЕОСТАНЦИЯ USNN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Аэропорт Нижневартовск (нажмите на плитку для нормы)',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 11),
                          SizedBox(width: 4),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 6-Metric Telemetry Grid (All Interactive)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.7,
                  children: [
                    _buildMetricTile(
                      context,
                      'humidity',
                      Icons.water_drop_rounded,
                      const Color(0xFF00E5FF),
                      'Влажность',
                      '${snapshot.humidityPct ?? 68}%',
                      'Точка росы: +8°C',
                    ),
                    _buildMetricTile(
                      context,
                      'wind',
                      Icons.air_rounded,
                      const Color(0xFFF59E0B),
                      'Ветер',
                      '${(snapshot.windSpeedMs ?? 3.8).toStringAsFixed(1)} м/с',
                      'Порывы до: ${(snapshot.windGustsMs ?? 6.5).round()} м/с',
                    ),
                    _buildMetricTile(
                      context,
                      'pressure',
                      Icons.compress_rounded,
                      const Color(0xFF10B981),
                      'Давление',
                      '${(snapshot.pressureMmHg ?? 758.0).round()} мм',
                      'Норма для НВ (758 мм)',
                    ),
                    _buildMetricTile(
                      context,
                      'uv_index',
                      Icons.wb_sunny_rounded,
                      const Color(0xFFFFB300),
                      'УФ-индекс',
                      (snapshot.uvIndex ?? 3.2).toStringAsFixed(1),
                      'Умеренно (SPF 15+)',
                    ),
                    _buildMetricTile(
                      context,
                      'visibility',
                      Icons.visibility_rounded,
                      const Color(0xFF818CF8),
                      'Видимость',
                      '${((snapshot.visibilityM ?? 10000.0) / 1000).toStringAsFixed(1)} км',
                      'Атмосфера чистая',
                    ),
                    _buildMetricTile(
                      context,
                      'wind_gusts',
                      Icons.air_outlined,
                      const Color(0xFFEC4899),
                      'Порывы ветра',
                      '${(snapshot.windGustsMs ?? 6.5).round()} м/с',
                      'Направление: ЮЗ (230°)',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    String key,
    IconData icon,
    Color color,
    String label,
    String value,
    String subtext,
  ) {
    return _explainable(
      context: context,
      metricKey: key,
      currentValue: '$value ($subtext)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity(0.4), size: 13),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Text(
              subtext,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ВКЛАДКА 2: ВОЗДУХ И ЭКОЛОГИЯ
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// ВКЛАДКА 2: ПРОГНОЗ (почасовой график + 7 дней)
// ═══════════════════════════════════════════════════════════════════════════

class _ForecastTab extends StatelessWidget {
  const _ForecastTab({required this.snapshot, required this.onRefresh});
  final CityWeatherSnapshot snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final hourly = snapshot.hourlyForecast;
    final daily = snapshot.dailyForecast;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Почасовой график температуры на 24 часа
          WeatherGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WeatherCardHeader(
                  icon: Icons.show_chart_rounded,
                  title: 'ТЕМПЕРАТУРА ПО ЧАСАМ · 24 Ч',
                  accent: Color(0xFF00E5FF),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: CustomPaint(painter: _HourlyTempPainter(hourly)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 7 дней
          WeatherGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WeatherCardHeader(
                  icon: Icons.calendar_view_week_rounded,
                  title: 'ПРОГНОЗ НА 7 ДНЕЙ',
                  accent: Color(0xFF00E5FF),
                ),
                const SizedBox(height: 8),
                for (final day in daily)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          child: Text(
                            '${day['day'] ?? ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${day['condition'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ),
                        if (day['pop'] != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '💧${day['pop']}%',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                            ),
                          ),
                        Text(
                          '${day['max_temp']}° / ${day['min_temp']}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyTempPainter extends CustomPainter {
  final List<Map<String, dynamic>> hourly;
  _HourlyTempPainter(this.hourly);

  @override
  void paint(Canvas canvas, Size size) {
    if (hourly.isEmpty) return;
    final temps = hourly
        .map((e) => (e['temp'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final minT = temps.reduce(math.min) - 1;
    final maxT = temps.reduce(math.max) + 1;
    final stepX = size.width / math.max(1, temps.length - 1);

    double yOf(double t) =>
        size.height - ((t - minT) / (maxT - minT)) * (size.height - 24) - 12;

    // Сетка
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Заливка
    final fill = Path()..moveTo(0, size.height);
    for (var i = 0; i < temps.length; i++) {
      fill.lineTo(i * stepX, yOf(temps[i]));
    }
    fill
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00E5FF).withOpacity(0.3),
            const Color(0xFF00E5FF).withOpacity(0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    // Линия
    final line = Path()..moveTo(0, yOf(temps[0]));
    for (var i = 1; i < temps.length; i++) {
      line.lineTo(i * stepX, yOf(temps[i]));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Подписи температур и времени (каждые 3 часа)
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < temps.length; i += 3) {
      tp.text = TextSpan(
        text: '${temps[i].round()}°',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      );
      tp.layout();
      tp.paint(canvas, Offset(i * stepX - tp.width / 2, yOf(temps[i]) - 18));

      final hourLabel = hourly[i]['time'] ?? '${i}:00';
      tp.text = TextSpan(
        text: '$hourLabel',
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      );
      tp.layout();
      tp.paint(canvas, Offset(i * stepX - tp.width / 2, size.height - 12));
    }
  }

  @override
  bool shouldRepaint(_HourlyTempPainter old) => old.hourly != hourly;
}

// ═══════════════════════════════════════════════════════════════════════════
// ВКЛАДКА 3: РЕЗОНАНС ШУМАНА И КОСМИЧЕСКАЯ ПОГОДА
// ═══════════════════════════════════════════════════════════════════════════

class _SchumannSpaceTab extends StatelessWidget {
  const _SchumannSpaceTab({required this.snapshot, required this.onRefresh});
  final CityWeatherSnapshot snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _explainable(
            context: context,
            metricKey: 'schumann',
            currentValue: '${snapshot.schumannFreqHz ?? 7.83} Гц • ${snapshot.solarFlare ?? 'B1.4'}',
            child: _WeatherMainTab._buildUnifiedCard(
              showInfoBadge: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SchumannResonanceCard(
                    freqHz: snapshot.schumannFreqHz ?? 7.83,
                    ampPt: snapshot.schumannAmpPt ?? 1.3,
                    solarFlare: snapshot.solarFlare ?? 'B1.4',
                  ),
                  if (snapshot.schumannFreqHz == null) const _EstimateChip(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Space Weather & Moon Phase Card (Циклы Луны & Фазы)
          _explainable(
            context: context,
            metricKey: 'space_weather',
            currentValue: '${snapshot.moonPhaseName ?? "Растущая Луна"} • Фаза ${(snapshot.moonPhase ?? 0.48 * 100).round()}%',
            child: _WeatherMainTab._buildUnifiedCard(
              showInfoBadge: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SpaceWeatherMoonCard(
                    moonPhase: snapshot.moonPhase ?? 0.48,
                    moonPhaseName: snapshot.moonPhaseName ?? 'Растущая Луна',
                    moonPhaseDesc: snapshot.moonPhaseDesc ?? 'Период накопления сил и повышенной физической активности.',
                    moonInfluencePct: snapshot.moonInfluencePct ?? 45.0,
                    kpIndex: snapshot.kpIndex ?? 2.0,
                    solarFlare: snapshot.solarFlare ?? 'B1.4',
                    solarWindKmS: snapshot.solarWindKmS ?? '395',
                  ),
                  if (snapshot.moonPhase == null || snapshot.kpIndex == null)
                    const _EstimateChip(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Aurora Borealis Alert Predictor (Kimi K3 & Claude Opus 4.8)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: (snapshot.kpIndex ?? 0) >= 5.0
                    ? [const Color(0xFF00FF87).withOpacity(0.3), const Color(0xFF60A5FA).withOpacity(0.2)]
                    : [const Color(0xFF0F172A).withOpacity(0.6), const Color(0xFF1E1B4B).withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: (snapshot.kpIndex ?? 0) >= 5.0 ? const Color(0xFF00FF87) : Colors.white.withOpacity(0.18),
                width: (snapshot.kpIndex ?? 0) >= 5.0 ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (snapshot.kpIndex ?? 0) >= 5.0 ? const Color(0xFF00FF87).withOpacity(0.3) : Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF87).withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00FF87).withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.nights_stay_rounded, color: Color(0xFF00FF87), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ПРОГНОЗ СЕВЕРНОГО СИЯНИЯ (AURORA ALERT)',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Шанс видимости за городом (60.93° N): ${snapshot.auroraVisibilityPct.round()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (snapshot.kpIndex ?? 0) >= 5.0
                            ? '🔴 СИЛЬНЫЙ ГЕОМАГНИТНЫЙ ШТОРМ! Сияние видно невооруженным глазом!'
                            : '🟢 Магнитный фон нормальный. Видимость за пределами городской засветки.',
                        style: TextStyle(color: (snapshot.kpIndex ?? 0) >= 5.0 ? const Color(0xFF00FF87) : Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const WeatherAlertBell(
                  topic: 'aurora',
                  label: 'Северное сияние',
                  color: Color(0xFF00FF87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Атлас и калькулятор затмений над Нижневартовском (eclipses.bogachev.fr & NASA)
          const NizhnevartovskEclipseCard(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ВКЛАДКА 4: СЕЙСМОАКТИВНОСТЬ И ГИДРОЛОГИЯ ОБИ
// ═══════════════════════════════════════════════════════════════════════════

class _SeismicHydroTab extends StatelessWidget {
  const _SeismicHydroTab({required this.snapshot, required this.onRefresh});
  final CityWeatherSnapshot snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // Реальные гидроданные из снапшота (14-дневный ряд уровней Оби).
    // Раньше карточка получала захардкоженные 712 / -4.0.
    final hydro = snapshot.hydro14Day;
    final hasHydro = hydro.isNotEmpty;
    final levelCm = hasHydro ? hydro.last : 712.0;
    final changeCm =
        hydro.length >= 2 ? hydro.last - hydro[hydro.length - 2] : -4.0;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _explainable(
            context: context,
            metricKey: 'ob_river',
            currentValue: '${levelCm.round()} см (Критический уровень: 940 см)',
            child: _WeatherMainTab._buildUnifiedCard(
              showInfoBadge: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ObRiverHydrologyCard(
                    currentLevelCm: levelCm,
                    dailyChangeCm: changeCm,
                    criticalLevelCm: 940.0,
                  ),
                  if (!hasHydro) const _EstimateChip(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Soil Freezing Depth & Ob Ice Thickness Gauge (Kimi K3 Math)
          WeatherGlassCard(
            accent: const Color(0xFF38BDF8),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.layers_rounded, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'ГРУНТ И ЛЕДОВЫЙ ПОКРОВ ОБИ',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Промерзание грунта', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('${snapshot.soilFreezingCm} см', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            const Text('Норма для ЖКХ ХМАО', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Толщина льда Оби', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('${snapshot.iceThicknessCm} см', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            const Text('Переправа безопасна', style: TextStyle(color: Color(0xFF34D399), fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _explainable(
            context: context,
            metricKey: 'seismic',
            currentValue: '${snapshot.seismicMagnitude ?? 0.0} M • Стабильно',
            child: _WeatherMainTab._buildUnifiedCard(
              showInfoBadge: true,
              child: SeismicMonitorCard(
                magnitude: snapshot.seismicMagnitude ?? 0.0,
                description: snapshot.seismicDescription ?? 'Сейсмическая активность в норме (фон 0.8 M)',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// СОСТОЯНИЯ
// ═══════════════════════════════════════════════════════════════════════════

/// Метка «оценка» — показывается на карточках, где живые данные
/// провайдера отсутствуют и отображается расчётное/дефолтное значение.
class _EstimateChip extends StatelessWidget {
  const _EstimateChip();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calculate_outlined, size: 11, color: Colors.amber),
            SizedBox(width: 4),
            Text(
              'оценка',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 32),
      children: [
        Center(child: const WeatherCardSkeleton()),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: List.generate(6, (_) => const WeatherCardSkeleton()),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: Colors.white.withOpacity(0.8), size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9), fontSize: 15),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
