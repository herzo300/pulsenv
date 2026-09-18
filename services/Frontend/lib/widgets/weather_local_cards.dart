// lib/widgets/weather_local_cards.dart
//
// Локальные погодные карточки для Нижневартовска (ХМАО, 60.93° N):
// наукастинг-график, «как одеться», гололёд-индекс, шкала актировки,
// полярный световой день. Единый glass-стиль экрана погоды.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../map/map_config.dart';
import '../services/city_weather_service.dart';

/// Колокольчик подписки на пуш-алерты по теме (актировка, сияние, гололёд).
/// Использует существующий geo-fence API /api/geo-subscriptions;
/// при недоступности сервера сохраняет подписку локально.
class WeatherAlertBell extends StatelessWidget {
  final String topic;
  final String label;
  final Color color;

  const WeatherAlertBell({
    super.key,
    required this.topic,
    required this.label,
    this.color = const Color(0xFF00E5FF),
  });

  Future<void> _subscribe(BuildContext context) async {
    const lat = 60.9344, lng = 76.5531; // центр Нижневартовска
    var serverOk = false;
    try {
      final res = await http
          .post(
            Uri.parse('${MapConfig.backendApiBaseUrl}/geo-subscriptions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lat': lat,
              'lng': lng,
              'radius_m': 25000,
              'label': label,
              'categories': 'weather_alerts,$topic',
            }),
          )
          .timeout(const Duration(seconds: 6));
      serverOk = res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {}

    if (!serverOk) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final subs = prefs.getStringList('weather_alert_subs') ?? [];
        if (!subs.contains(topic)) {
          subs.add(topic);
          await prefs.setStringList('weather_alert_subs', subs);
        }
      } catch (_) {}
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          serverOk
              ? '🔔 Подписка «$label» оформлена — пришлём пуш'
              : '🔔 «$label» сохранена локально, синхронизируем при связи',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Уведомлять: $label',
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.notifications_active_outlined, color: color),
      onPressed: () => _subscribe(context),
    );
  }
}

/// Общий glass-контейнер карточек экрана погоды (единый стиль).
class WeatherGlassCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  const WeatherGlassCard({
    super.key,
    required this.child,
    this.accent = const Color(0xFF00E5FF),
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1626).withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14),
        ],
      ),
      child: child,
    );
  }
}

/// Заголовок карточки в едином стиле.
class WeatherCardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final String? trailing;

  const WeatherCardHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// НАУКАСТИНГ: линейный график осадков на 2 часа
// ═══════════════════════════════════════════════════════════════════════════

class NowcastingChart extends StatelessWidget {
  final List<double> values; // 12 значений, шаг 10 минут

  const NowcastingChart({super.key, required this.values});

  String get _startLabel {
    for (var i = 0; i < values.length; i++) {
      if (values[i] > 0.1) {
        final mins = i * 10;
        return mins == 0
            ? 'Осадки идут сейчас'
            : 'Осадки начнутся через ~$mins мин';
      }
    }
    return 'Ближайшие 2 часа без осадков';
  }

  @override
  Widget build(BuildContext context) {
    final hasRain = values.any((v) => v > 0.1);
    return WeatherGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WeatherCardHeader(
            icon: Icons.grain_rounded,
            title: 'ОСАДКИ В ТЕЧЕНИЕ 2 ЧАСОВ',
            accent: const Color(0xFF00E5FF),
            trailing: 'USNN Radar',
          ),
          const SizedBox(height: 6),
          Text(
            _startLabel,
            style: TextStyle(
              color: hasRain ? const Color(0xFF00E5FF) : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(painter: _NowcastingPainter(values)),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('сейчас', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('+30 мин', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('+1 ч', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('+2 ч', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NowcastingPainter extends CustomPainter {
  final List<double> values;
  _NowcastingPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final zonePaint = Paint()..color = Colors.white.withOpacity(0.04);
    // Зоны интенсивности: слабо / умеренно / сильно
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.66, size.width, size.height * 0.34), zonePaint);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.33, size.width, size.height * 0.33), zonePaint..color = Colors.white.withOpacity(0.07));

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 0.5;
    for (final y in [0.33, 0.66]) {
      canvas.drawLine(Offset(0, size.height * y), Offset(size.width, size.height * y), gridPaint);
    }

    if (values.isEmpty) return;
    final maxV = math.max(1.0, values.reduce(math.max) * 1.2);
    final stepX = size.width / math.max(1, values.length - 1);

    Offset pointAt(int i) {
      final norm = (values[i] / maxV).clamp(0.0, 1.0);
      return Offset(i * stepX, size.height - norm * size.height * 0.9 - 4);
    }

    // Заливка под кривой
    final fillPath = Path()..moveTo(0, size.height);
    for (var i = 0; i < values.length; i++) {
      fillPath.lineTo(pointAt(i).dx, pointAt(i).dy);
    }
    fillPath
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00E5FF).withOpacity(0.35),
            const Color(0xFF00E5FF).withOpacity(0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    // Линия
    final linePath = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      linePath.lineTo(pointAt(i).dx, pointAt(i).dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Точки
    final dotPaint = Paint()..color = const Color(0xFF00E5FF);
    for (var i = 0; i < values.length; i++) {
      if (values[i] > 0.1) {
        canvas.drawCircle(pointAt(i), 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_NowcastingPainter old) => old.values != values;
}

// ═══════════════════════════════════════════════════════════════════════════
// КАК ОДЕТЬСЯ СЕГОДНЯ (ветро-холодовой индекс + таймер обморожения)
// ═══════════════════════════════════════════════════════════════════════════

class ClothingAdviceCard extends StatelessWidget {
  final CityWeatherSnapshot snapshot;

  const ClothingAdviceCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final effective = snapshot.windChillC ?? snapshot.feelsLikeC ?? snapshot.temperatureC;
    if (effective == null) return const SizedBox.shrink();
    final wind = snapshot.windSpeedMs ?? 0;
    final t = effective;

    final String advice;
    final IconData icon;
    final Color accent;
    if (t <= -35) {
      advice = 'Экстремальный холод: тяжёлый пуховик, балаклава, '
          'термобельё, варежки. На улице — не более '
          '${snapshot.frostbiteSafetyMinutes} мин.';
      icon = Icons.severe_cold_rounded;
      accent = const Color(0xFFFF453A);
    } else if (t <= -25) {
      advice = 'Пуховик, шапка закрывающая уши, варежки, '
          'тёплая обувь. Лицо закрывайте от ветра.';
      icon = Icons.ac_unit_rounded;
      accent = const Color(0xFF38BDF8);
    } else if (t <= -15) {
      advice = 'Тёплая куртка, шапка, перчатки. '
          'Детям — шарф и сменные варежки.';
      icon = Icons.ac_unit_rounded;
      accent = const Color(0xFF38BDF8);
    } else if (t <= -5) {
      advice = 'Зимняя куртка и шапка. Ветер $wind м/с — '
          'одевайтесь «по ощущаемой» температуре.';
      icon = Icons.checkroom_rounded;
      accent = const Color(0xFF00E5FF);
    } else if (t <= 5) {
      advice = 'Демисезонная куртка. Утром возможен гололёд — '
          'обувь с протектором.';
      icon = Icons.checkroom_rounded;
      accent = const Color(0xFF00E5FF);
    } else if (t <= 15) {
      advice = 'Лёгкая куртка или худи. Вечером прохладнее — '
          'возьмите слой про запас.';
      icon = Icons.checkroom_rounded;
      accent = const Color(0xFF34D399);
    } else {
      advice = 'Лёгкая одежда. Не забудьте воду и головной убор на солнце.';
      icon = Icons.wb_sunny_rounded;
      accent = const Color(0xFFFFC857);
    }

    return WeatherGlassCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WeatherCardHeader(
            icon: icon,
            title: 'КАК ОДЕТЬСЯ СЕГОДНЯ',
            accent: accent,
            trailing: 'ощущ. ${t.round()}°',
          ),
          const SizedBox(height: 8),
          Text(
            advice,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ГОЛОЛЁД-ИНДЕКС ДЛЯ ВОДИТЕЛЕЙ
// ═══════════════════════════════════════════════════════════════════════════

class IceRoadRiskCard extends StatelessWidget {
  final CityWeatherSnapshot snapshot;

  const IceRoadRiskCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final t = snapshot.temperatureC;
    if (t == null) return const SizedBox.shrink();
    final humidity = snapshot.humidityPct ?? 60;
    final kind = resolveKind();

    // Индекс 0..10: пик опасности в коридоре -3..+1 °C при влажности и осадках
    double risk = 0;
    if (t >= -3 && t <= 1) {
      risk = 5;
    } else if (t > -6 && t < 3) {
      risk = 3;
    } else if (t <= -20) {
      risk = 1.5; // сухой снег — сцепление лучше, но тормозной путь всё равно растёт
    }
    if (humidity >= 85) risk += 2;
    if (kind == _PrecipKind.rain || kind == _PrecipKind.drizzle) risk += 3;
    if (kind == _PrecipKind.snow) risk += 1.5;
    final index = risk.clamp(0, 10).round();

    final (label, accent) = switch (index) {
      >= 7 => ('ВЫСОКИЙ РИСК ГОЛОЛЁДА', const Color(0xFFFF453A)),
      >= 4 => ('УМЕРЕННЫЙ РИСК', const Color(0xFFFFC857)),
      >= 2 => ('НИЗКИЙ РИСК', const Color(0xFF38BDF8)),
      _ => ('ДОРОГИ СУХИЕ', const Color(0xFF34D399)),
    };

    return WeatherGlassCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WeatherCardHeader(
            icon: Icons.car_crash_rounded,
            title: 'ГОЛОЛЁД-ИНДЕКС',
            accent: accent,
            trailing: '$index / 10',
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: index / 10,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            index >= 4
                ? 'Снизьте скорость, увеличьте дистанцию. Особенно опасны мосты и путепроводы.'
                : 'Стандартный режим движения. Следите за прогнозом — индекс обновляется.',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
          ),
        ],
      ),
    );
  }

  _PrecipKind resolveKind() {
    final k = '${snapshot.kind} ${snapshot.condition}'.toLowerCase();
    if (k.contains('drizzle') || k.contains('морось')) return _PrecipKind.drizzle;
    if (k.contains('rain') || k.contains('дожд')) return _PrecipKind.rain;
    if (k.contains('snow') || k.contains('снег')) return _PrecipKind.snow;
    return _PrecipKind.none;
  }
}

enum _PrecipKind { none, drizzle, rain, snow }

// ═══════════════════════════════════════════════════════════════════════════
// ШКАЛА АКТИРОВКИ ХМАО (пороги отмены занятий)
// ═══════════════════════════════════════════════════════════════════════════

class AktirovkaScale extends StatelessWidget {
  final double? temperatureC;

  /// Пороги ХМАО: 1–4 классы −25°, 5–9 классы −30°, 10–11 классы −35°.
  static const List<(double, String)> thresholds = [
    (-25, '1–4 кл'),
    (-30, '5–9 кл'),
    (-35, '10–11 кл'),
  ];

  const AktirovkaScale({super.key, required this.temperatureC});

  @override
  Widget build(BuildContext context) {
    final t = temperatureC;
    if (t == null) return const SizedBox.shrink();
    // Шкала от -40 до -15
    const minT = -40.0, maxT = -15.0;
    final pos = ((t - minT) / (maxT - minT)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Полоса шкалы
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF453A), Color(0xFFFFC857), Color(0xFF34D399)],
                        ),
                      ),
                    ),
                  ),
                  // Пороговые метки
                  for (final (th, label) in thresholds)
                    Positioned(
                      left: ((th - minT) / (maxT - minT)) * w - 14,
                      top: 0,
                      child: Column(
                        children: [
                          Text(
                            '${th.round()}°',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          Container(width: 2, height: 12, color: Colors.white54),
                          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  // Маркер текущей температуры
                  Positioned(
                    left: pos * w - 7,
                    top: 10,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF00E5FF), width: 3),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.6), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Text(
          'Сейчас ${t.round()}° — маркер показывает, сколько градусов осталось до отмены занятий',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ПОЛЯРНЫЙ СВЕТОВОЙ ДЕНЬ (сумерки, длина дня, тренд)
// ═══════════════════════════════════════════════════════════════════════════

class PolarDaylightCard extends StatelessWidget {
  final CityWeatherSnapshot snapshot;

  const PolarDaylightCard({super.key, required this.snapshot});

  int _toMin(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _fmt(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sr = _toMin(snapshot.sunriseTime);
    final ss = _toMin(snapshot.sunsetTime);
    if (ss <= sr) return const SizedBox.shrink();

    final dayLen = ss - sr;
    final dayH = dayLen ~/ 60;
    final dayM = dayLen % 60;
    // Гражданские сумерки на 61°N: ~35–60 мин, берём умеренную оценку
    const twilight = 45;
    // Тренд длины дня: модель по дню года (оценка)
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    // Производная ~cos: растёт до солнцестояния (172-й день), убывает после
    final growing = dayOfYear < 172 || dayOfYear > 355;
    final trendMin = (4.5 * math.cos((dayOfYear - 172) * 2 * math.pi / 365)).abs().round();

    return WeatherGlassCard(
      accent: const Color(0xFFFFC857),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WeatherCardHeader(
            icon: Icons.wb_twilight_rounded,
            title: 'СВЕТОВОЙ ДЕНЬ · 61° С.Ш.',
            accent: Color(0xFFFFC857),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metric('Длина дня', '$dayH ч $dayM мин'),
              ),
              Expanded(
                child: _metric('Сумерки', '±$twilight мин'),
              ),
              Expanded(
                child: _metric(
                  growing ? 'День прибавляется' : 'День убывает',
                  '~$trendMin мин/сут',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Рассвет ${_fmt(sr)} · закат ${_fmt(ss)} · '
            'сумерки до ~${_fmt(ss + twilight)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
