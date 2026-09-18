// lib/screens/weather_screen.dart
//
// Экран погоды со спецэффектами.
//
// Состав:
//   • WeatherEffectsOverlay — анимированный фон (дождь/снег/солнце/...);
//   • Hero-блок с температурой, состоянием, ощущается-как;
//   • Сетка метрик: влажность, ветер, давление, УФ-индекс, видимость;
//   • Чипы: качество воздуха, магнитуда, фаза луны;
//   • Pull-to-refresh для обновления.
//
// Данные тянутся из CityWeatherService (Open-Meteo + доп. источники).
//
// NEW (запрос пользователя): экран погоды со спецэффектами погоды.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/city_weather_service.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/weather_effects_overlay.dart';
import '../widgets/aura_living_background.dart';
import '../core/living/aura_living_engine.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  CityWeatherSnapshot _snapshot = CityWeatherSnapshot.empty();
  bool _loading = true;
  String? _error;
  String _selectedThemeKey = 'auto';
  String? _analyzedSkyColorHex;

  @override
  void initState() {
    super.initState();
    _loadThemeKey();
    _load();
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
      cleaned = 'FF' + cleaned;
    }
    final val = int.tryParse(cleaned, radix: 16);
    return val != null ? Color(val) : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapFuture = CityWeatherService.instance.fetchWeather();
      final skyColorFuture = CityWeatherService.instance.fetchSkyColor();
      
      final results = await Future.wait([snapFuture, skyColorFuture]);
      final snap = results[0] as CityWeatherSnapshot;
      final skyColorHex = results[1] as String?;

      if (mounted) {
        setState(() {
          _snapshot = snap;
          _analyzedSkyColorHex = skyColorHex;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить погоду: $e';
          _loading = false;
        });
      }
    }
  }

  int _getAuraMoodForWeather(String condition) {
    final k = condition.toLowerCase();
    if (k.contains('thunder') || k.contains('гроз') || k.contains('storm')) return 1; // Moody storm
    if (k.contains('rain') || k.contains('дожд')) return 2; // Calm rain
    if (k.contains('snow') || k.contains('снег')) return 4; // Winter cozy
    if (k.contains('clear') || k.contains('ясн') || k.contains('солн')) return 5; // Bright sunny
    return 3; // Neutral cloud
  }

  AuraWeather _getAuraWeatherForCondition(String condition, double? kpIndex, bool isDay) {
    if (_selectedThemeKey != 'auto') {
      switch (_selectedThemeKey) {
        case 'cyberpunk': return AuraWeather.cyberpunk;
        case 'neon': return AuraWeather.neon;
        case 'inkDiffuse': return AuraWeather.inkDiffuse;
        case 'starfield': return AuraWeather.starfield;
        case 'nebula': return AuraWeather.nebula;
        case 'voronoi': return AuraWeather.voronoi;
        case 'fluid': return AuraWeather.fluid;
        case 'aurora': return AuraWeather.aurora;
      }
    }

    if (kpIndex != null && kpIndex >= 4.0) {
      return AuraWeather.aurora;
    }
    final k = condition.toLowerCase();
    final hour = DateTime.now().hour;
    
    // Storm / Thunderstorm
    if (k.contains('thunder') || k.contains('гроз') || k.contains('storm') || k.contains('heavy_rain') || k.contains('ливень')) {
      if (hour >= 21 || hour < 5) {
        return AuraWeather.cyberpunk; // Neon cyber rain glitch
      } else if (hour >= 17 && hour < 21) {
        return AuraWeather.supernova; // Twilight supernova storm
      } else if (hour >= 5 && hour < 11) {
        return AuraWeather.glitch; // Electric morning glitch
      } else {
        return AuraWeather.fluid; // Touch interactive fluid storm
      }
    }
    
    // Rain
    if (k.contains('rain') || k.contains('дожд')) {
      if (hour >= 21 || hour < 5) {
        return AuraWeather.neon; // Night neon rain
      } else if (hour >= 17 && hour < 21) {
        return AuraWeather.inkDiffuse; // Ink diffusion in water (sunset rain)
      } else if (hour >= 5 && hour < 11) {
        return AuraWeather.water; // Morning calm water rain ripples
      } else {
        return AuraWeather.rain; // Classic midday rain
      }
    }
    
    // Snow / Hail
    if (k.contains('snow') || k.contains('снег') || k.contains('ice') || k.contains('град')) {
      if (hour >= 21 || hour < 5) {
        return AuraWeather.starfield; // Snowing among pulsing stars
      } else if (hour >= 17 && hour < 21) {
        return AuraWeather.sakura; // Sunset cherry blossom snow style
      } else if (hour >= 5 && hour < 11) {
        return AuraWeather.voronoi; // Morning geometric snow crystals
      } else {
        return AuraWeather.snow; // Normal midday soft snowfall
      }
    }
    
    // Fog / Haze / Mist
    if (k.contains('fog') || k.contains('туман') || k.contains('mist')) {
      if (hour >= 21 || hour < 5) {
        return AuraWeather.nebula; // Mystical space nebula fog
      } else if (hour >= 17 && hour < 21) {
        return AuraWeather.voronoi; // Crystalline twilight fog
      } else if (hour >= 5 && hour < 11) {
        return AuraWeather.fog; // Classic morning dense fog
      } else {
        return AuraWeather.breath; // Day warm breathing mist ring
      }
    }
    
    // Clear / Sunny
    if (k.contains('clear') || k.contains('ясн') || k.contains('солн')) {
      if (isDay) {
        if (hour < 11) return AuraWeather.dawn;
        if (hour > 17) return AuraWeather.sunset;
        return AuraWeather.tropical;
      }
      return AuraWeather.starfield;
    }
    
    // Clouds / Overcast / Default
    if (hour >= 21 || hour < 5) {
      return AuraWeather.blackHole; // Gravitational space night sky
    } else if (hour >= 17 && hour < 21) {
      return AuraWeather.candle; // Cozy warm candle twilight
    } else if (hour >= 5 && hour < 11) {
      return AuraWeather.aura; // Gentle green-blue dawn aura
    } else {
      return AuraWeather.waveFunc; // Day quantum clouds
    }
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
              ('auto', 'Авто (Погода)', Icons.auto_awesome_rounded, const [Color(0xFF6366F1), Color(0xFF10B981)]),
              ('cyberpunk', 'Киберпанк', Icons.bolt_rounded, const [Color(0xFF0A001A), Color(0xFFFF0055)]),
              ('neon', 'Неон дождь', Icons.wb_twilight_rounded, const [Color(0xFF050505), Color(0xFF00FF00)]),
              ('inkDiffuse', 'Акварель', Icons.brush_rounded, const [Color(0xFFF0ECE0), Color(0xFF1A1A2E)]),
              ('starfield', 'Звездное небо', Icons.star_rounded, const [Color(0xFF030008), Color(0xFF80D8FF)]),
              ('nebula', 'Туманность', Icons.bubble_chart_rounded, const [Color(0xFF080014), Color(0xFFFF0080)]),
              ('voronoi', 'Кристаллы', Icons.ac_unit_rounded, const [Color(0xFF080412), Color(0xFF80D8FF)]),
              ('fluid', 'Жидкая плазма', Icons.waves_rounded, const [Color(0xFF040820), Color(0xFF2080FF)]),
              ('aurora', 'Сияние', Icons.nights_stay_rounded, const [Color(0xFF000428), Color(0xFF00FF87)]),
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
                          'Атмосфера погоды',
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
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: colors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.2),
                                      width: isSelected ? 3.0 : 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: colors.last.withOpacity(0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 75,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? sheetTextColor
                                          : sheetTextColor.withOpacity(0.6),
                                      fontSize: 10,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
    final isDay = hour >= 6 && hour < 21;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.canPop() ? context.pop() : context.go('/map'),
        ),
        title: Text(
          'Погода',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_rounded, color: Colors.white),
            onPressed: _showThemeSelector,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: AuraLivingBackground(
        scene: () {
          final hour = DateTime.now().hour;
          final isDay = hour >= 6 && hour < 21;
          
          final baseScene = AuraLivingEngine.resolve(
            mood: _getAuraMoodForWeather(_snapshot.condition),
            streak: 5,
            meditationMinutes: 10,
            practicesCompleted: 5,
            isPremium: true,
            hour: hour,
          );
          
          // Dynamic climate adaptations:
          // 1. Shader speed reacts to real-time wind speed (0.4 to 2.5 multiplier)
          final windSpeed = _snapshot.windSpeedMs ?? 3.0;
          final dynamicSpeed = (0.5 + (windSpeed / 12.0)).clamp(0.4, 2.5);
          
          // 2. Particle density reacts to real-time humidity
          final humidity = _snapshot.humidityPct ?? 60;
          final dynamicParticles = (0.3 + (humidity / 100.0) * 1.2).clamp(0.2, 1.6);
          
          // 3. Shader blur increases slightly during low visibility (fog/heavy mist)
          final visibility = _snapshot.visibilityM ?? 10000.0;
          final dynamicBlur = (baseScene.blur * (1.0 + (10000.0 - visibility) / 5000.0)).clamp(1.0, 15.0);

          final parsedColor = _parseHexColor(_analyzedSkyColorHex);
          final customPalette = (parsedColor != null && _selectedThemeKey == 'auto')
              ? [
                  parsedColor,
                  parsedColor.withOpacity(0.65),
                  parsedColor.withAlpha(100),
                ]
              : null;

          return baseScene.copyWith(
            weather: _getAuraWeatherForCondition(
              _snapshot.condition, 
              _snapshot.kpIndex, 
              isDay,
            ),
            speed: dynamicSpeed,
            particleDensity: dynamicParticles,
            blur: dynamicBlur,
            palette: customPalette,
          );
        }(),
        interactive: true,
        showConstellationVeil: false,
        child: Stack(
          children: [
            // Animated weather particle systems (rain, snow, storm, clouds, fog)
            if (_snapshot.available)
              Positioned.fill(
                child: WeatherEffectsOverlay(
                  effect: weatherEffectFromKind(_snapshot.condition),
                  isDay: isDay,
                  showBackground: false,
                ),
              ),
            // Dark vignette overlay to maintain high text contrast on bright weather shaders
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.65),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const _LoadingView()
                    : _error != null
                        ? _ErrorView(message: _error!, onRetry: _load)
                        : _WeatherContent(snapshot: _snapshot),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// КОНТЕНТ
// ═══════════════════════════════════════════════════════════════════════════

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({required this.snapshot});
  final CityWeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final temp = snapshot.temperatureC;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 32),
      children: [
        // ─── Hero ──────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              _HolographicWeatherOrb(
                condition: snapshot.condition,
                accent: const Color(0xFF00E5FF),
              ),
              Text(
                temp != null ? '${temp.round()}°' : '—°',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 96,
                  fontWeight: FontWeight.w200,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                snapshot.condition,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6),
                  ],
                ),
              ),
              if (snapshot.feelsLikeC != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Ощущается как ${snapshot.feelsLikeC!.round()}°',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ─── Сетка метрик ──────────────────────────────────────────────
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _MetricCard(
              icon: Icons.water_drop_rounded,
              label: 'Влажность',
              value: snapshot.humidityPct != null
                  ? '${snapshot.humidityPct}%'
                  : '—',
            ),
            _MetricCard(
              icon: Icons.air_rounded,
              label: 'Ветер',
              value: snapshot.windSpeedMs != null
                  ? '${snapshot.windSpeedMs!.round()} м/с'
                  : '—',
            ),
            _MetricCard(
              icon: Icons.compress_rounded,
              label: 'Давление',
              value: snapshot.pressureMmHg != null
                  ? '${snapshot.pressureMmHg!.round()} мм'
                  : '—',
            ),
            _MetricCard(
              icon: Icons.wb_sunny_rounded,
              label: 'УФ-индекс',
              value: snapshot.uvIndex != null
                  ? snapshot.uvIndex!.toStringAsFixed(1)
                  : '—',
            ),
            _MetricCard(
              icon: Icons.visibility_rounded,
              label: 'Видимость',
              value: snapshot.visibilityM != null
                  ? '${(snapshot.visibilityM! / 1000).toStringAsFixed(1)} км'
                  : '—',
            ),
            _MetricCard(
              icon: Icons.air_outlined,
              label: 'Порывы',
              value: snapshot.windGustsMs != null
                  ? '${snapshot.windGustsMs!.round()} м/с'
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ─── Доп. чипы ─────────────────────────────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.eco_rounded,
              label: 'Воздух: ${snapshot.airQualityLevel}',
              subtitle: snapshot.airQualitySummary,
            ),
            if (snapshot.moonPhaseName != null)
              _InfoChip(
                icon: Icons.nightlight_rounded,
                label: 'Луна: ${snapshot.moonPhaseName}',
                subtitle: snapshot.moonPhaseDesc,
              ),
            if (snapshot.seismicDescription != null)
              _InfoChip(
                icon: Icons.waves_rounded,
                label: 'Сейсмика',
                subtitle: snapshot.seismicDescription,
              ),
            if (snapshot.kpIndex != null)
              _InfoChip(
                icon: Icons.bolt_rounded,
                label: 'Геомагнитная Kp',
                subtitle: snapshot.kpIndex!.toStringAsFixed(1),
              ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// СОСТОЯНИЯ
// ═══════════════════════════════════════════════════════════════════════════

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
                color: Colors.white.withValues(alpha: 0.8), size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
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

class _HolographicWeatherOrb extends StatefulWidget {
  final String condition;
  final Color accent;
  const _HolographicWeatherOrb({required this.condition, required this.accent});

  @override
  State<_HolographicWeatherOrb> createState() => _HolographicWeatherOrbState();
}

class _HolographicWeatherOrbState extends State<_HolographicWeatherOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getWeatherIcon(String condition) {
    final k = condition.toLowerCase();
    if (k.contains('thunder') || k.contains('гроз') || k.contains('storm')) return Icons.thunderstorm_rounded;
    if (k.contains('rain') || k.contains('дожд')) return Icons.grain_rounded;
    if (k.contains('snow') || k.contains('снег')) return Icons.ac_unit_rounded;
    if (k.contains('fog') || k.contains('туман') || k.contains('mist')) return Icons.filter_drama_rounded;
    if (k.contains('clear') || k.contains('ясн') || k.contains('солн')) return Icons.wb_sunny_rounded;
    return Icons.cloud_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getWeatherIcon(widget.condition);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _controller.value * 2 * math.pi,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accent.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: CircularProgressIndicator(
                        value: 0.8,
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF00FFCC).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(
                  color: widget.accent.withOpacity(0.7),
                  width: 2.0,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 44,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
