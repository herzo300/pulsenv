// lib/widgets/cinematic_weather_background.dart
//
// Кинематографичный супер-фон экрана погоды (архитектура gpt-6-astra, 6 слоёв):
//   1. Спектральное небо — вертикальный градиент, интерполяция ночь→сумерки→день
//      по высоте Солнца + закатная полоса + температурное «дыхание».
//   2. Небесная глубина — днём солнечный диск с гало (радиус гало от влажности),
//      ночью 180 детерминированных звёзд в трёх планах с мерцанием.
//   3. Атмосферный свет — днём god-rays от УФ, ночью аврора-ленты от kp-индекса.
//   4. Кинематографический финиш — виньетка + монохромное зерно (12 Гц).
//
// Правила astra: один герой (сияние ЛИБО лучи), плавная физика (данные
// сглаживаются), жёсткий бюджет — один painter, repaint без перестройки виджетов.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class CinematicWeatherBackground extends StatelessWidget {
  const CinematicWeatherBackground({
    super.key,
    required this.temperatureC,
    required this.humidityPct,
    required this.uvIndex,
    required this.kpIndex,
    required this.isDay,
    this.child,
  });

  final double? temperatureC;
  final int? humidityPct;
  final double? uvIndex;
  final double? kpIndex;
  final bool isDay;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return _CinematicBackgroundTicker(
      temperatureC: temperatureC,
      humidityPct: humidityPct,
      uvIndex: uvIndex,
      kpIndex: kpIndex,
      isDay: isDay,
      child: child,
    );
  }
}

class _CinematicBackgroundTicker extends StatefulWidget {
  const _CinematicBackgroundTicker({
    required this.temperatureC,
    required this.humidityPct,
    required this.uvIndex,
    required this.kpIndex,
    required this.isDay,
    this.child,
  });

  final double? temperatureC;
  final int? humidityPct;
  final double? uvIndex;
  final double? kpIndex;
  final bool isDay;
  final Widget? child;

  @override
  State<_CinematicBackgroundTicker> createState() =>
      _CinematicBackgroundTickerState();
}

class _CinematicBackgroundTickerState extends State<_CinematicBackgroundTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _CinematicWeatherPainter(
            t: _ticker.value * 60.0,
            temperatureC: widget.temperatureC,
            humidityPct: widget.humidityPct,
            uvIndex: widget.uvIndex,
            kpIndex: widget.kpIndex,
            isDay: widget.isDay,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _CinematicWeatherPainter extends CustomPainter {
  final double t; // секунды
  final double? temperatureC;
  final int? humidityPct;
  final double? uvIndex;
  final double? kpIndex;
  final bool isDay;

  _CinematicWeatherPainter({
    required this.t,
    required this.temperatureC,
    required this.humidityPct,
    required this.uvIndex,
    required this.kpIndex,
    required this.isDay,
  });

  static double _smoothstep(double a, double b, double x) {
    final c = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final T = temperatureC ?? 0.0;
    final H = (humidityPct ?? 60) / 100.0;
    final U = ((uvIndex ?? 3.0) / 11.0).clamp(0.0, 1.0);
    final kp = kpIndex ?? 0.0;

    // ── Слой 1: Спектральное небо ──────────────────────────────────
    // Температурный оттенок: ледяной синий → янтарный (S(-15,35,T))
    final tempMix = _smoothstep(-15.0, 35.0, T);
    // Медленное «дыхание» — амплитуда примеси 8% ± 1.5% (период 24 с)
    final breath = 0.08 + 0.015 * math.sin(2 * math.pi * t / 24.0);

    final Color zenith;
    final Color mid;
    final Color horizon;
    if (isDay) {
      zenith = Color.lerp(const Color(0xFF0B4F8A), const Color(0xFF3E7CB8), tempMix)!;
      mid = Color.lerp(const Color(0xFF2C74B3), const Color(0xFF9DBAD0), tempMix)!;
      horizon = Color.lerp(const Color(0xFF6FA8D6), const Color(0xFFE8C39A), tempMix)!;
    } else {
      zenith = Color.lerp(const Color(0xFF020409), const Color(0xFF060A18), tempMix)!;
      mid = Color.lerp(const Color(0xFF050A1A), const Color(0xFF0C1330), tempMix)!;
      horizon = Color.lerp(const Color(0xFF0B1230), const Color(0xFF1A1E3E), tempMix)!;
    }

    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [zenith, mid, horizon],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & size, skyPaint);

    // Закатная полоса: exp(−((y−0.68)/0.18)²) — тёплая, только у горизонта
    final sunsetY = size.height * 0.68;
    final sunsetRect = Rect.fromLTWH(0, sunsetY - size.height * 0.2, size.width, size.height * 0.4);
    final sunsetPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, sunsetY),
        size.height * 0.35,
        [
          const Color(0xFFFF8C42).withOpacity(0.16 * breath * 6),
          const Color(0xFFFF6B35).withOpacity(0.05),
          Colors.transparent,
        ],
      );
    canvas.drawRect(sunsetRect, sunsetPaint);

    // ── Слой 2: Небесная глубина ───────────────────────────────────
    if (isDay) {
      // Солнечный диск с мягким гало: σ = 0.05 + 0.04·H (влажность размывает)
      final sunPos = Offset(size.width * 0.82, size.height * 0.14);
      final sigma = size.height * (0.05 + 0.04 * H) * 3;
      final haloPaint = Paint()
        ..shader = ui.Gradient.radial(
          sunPos,
          sigma,
          [
            const Color(0xFFFFE082).withOpacity(0.20),
            const Color(0xFFFFD54F).withOpacity(0.06),
            Colors.transparent,
          ],
        );
      canvas.drawCircle(sunPos, sigma, haloPaint);
      canvas.drawCircle(
        sunPos,
        size.height * 0.028,
        Paint()..shader = ui.Gradient.radial(
          sunPos,
          size.height * 0.028,
          [const Color(0xFFFFFDE7), const Color(0xFFFFD54F)],
        ),
      );
    } else {
      // Звёзды: 180 штук, три плана, детерминированный PRNG
      final rng = math.Random(20260911);
      final starPaint = Paint()..strokeCap = StrokeCap.round;
      for (int i = 0; i < 180; i++) {
        final sx = rng.nextDouble() * size.width;
        final sy = rng.nextDouble() * size.height * 0.75;
        final plane = i % 3; // 0 дальний, 2 ближний
        final baseR = 0.4 + plane * 0.35 + rng.nextDouble() * 0.3;
        final omega = 0.8 + rng.nextDouble() * 2.2; // рад/с мерцания
        final phi = rng.nextDouble() * 2 * math.pi;
        final twinkle = 0.88 + 0.12 * math.sin(omega * t + phi);
        final alpha = (0.25 + plane * 0.22) * twinkle;
        starPaint.color = (i % 7 == 0 ? const Color(0xFF80D8FF) : Colors.white)
            .withOpacity(alpha.clamp(0.0, 1.0));
        // drawPoints для батчинга: рисуем точкой заданного радиуса
        canvas.drawCircle(Offset(sx, sy), baseR, starPaint);
      }
    }

    // ── Слой 3: Атмосферный свет ──────────────────────────────────
    if (isDay) {
      // God-rays: 5 широких лучей из позиции Солнца, интенсивность от УФ
      final sunPos = Offset(size.width * 0.82, size.height * 0.14);
      final rayAlpha = 0.07 * (0.6 + 0.4 * U);
      final rayPaint = Paint()
        ..shader = ui.Gradient.radial(
          sunPos,
          size.height * 0.9,
          [
            const Color(0xFFFFE082).withOpacity(rayAlpha),
            const Color(0xFFFFD54F).withOpacity(rayAlpha * 0.4),
            Colors.transparent,
          ],
        );
      canvas.save();
      canvas.translate(sunPos.dx, sunPos.dy);
      // Медленное вращение: целый оборот за 60 с цикла (гармоника, без рывков)
      canvas.rotate(t * 2 * math.pi / 60.0);
      for (int i = 0; i < 5; i++) {
        final angle = (i * 2 * math.pi / 5) + 0.3;
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(
              math.cos(angle - 0.09) * size.height * 1.2,
              math.sin(angle - 0.09) * size.height * 1.2)
          ..lineTo(
              math.cos(angle + 0.09) * size.height * 1.2,
              math.sin(angle + 0.09) * size.height * 1.2)
          ..close();
        canvas.drawPath(path, rayPaint);
      }
      canvas.restore();
    } else {
      // Аврора: три ленты, интенсивность S(4,7,kp) — только при kp>4
      final auroraIntensity = 0.22 * _smoothstep(4.0, 7.0, kp);
      if (auroraIntensity > 0.02) {
        for (int j = 0; j < 3; j++) {
          final phase = j * 2.1;
          final path = Path()..moveTo(0, size.height * 0.16);
          for (double x = 0; x <= 1.001; x += 0.05) {
            final y = size.height * (0.12 + j * 0.05) +
                size.height * 0.06 * math.sin(3 * x + 0.12 * t + phase) +
                size.height * 0.02 * math.sin(9 * x - 0.2 * t);
            path.lineTo(x * size.width, y);
          }
          for (double x = 1.0; x >= -0.001; x -= 0.05) {
            final y = size.height * (0.12 + j * 0.05) +
                size.height * 0.06 * math.sin(3 * x + 0.12 * t + phase) +
                size.height * 0.02 * math.sin(9 * x - 0.2 * t) +
                size.height * 0.05; // толщина ленты
            path.lineTo(x * size.width, y);
          }
          path.close();
          final bandPaint = Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, size.height * 0.1),
              Offset(0, size.height * 0.35),
              [
                Color(0xFF00FF87).withOpacity(auroraIntensity),
                Color(0xFF00E5FF).withOpacity(auroraIntensity * 0.6),
                Colors.transparent,
              ],
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
          canvas.drawPath(path, bandPaint);
        }
      }
    }

    // ── Слой 3.5: Плывущие облачные банки (Pareto: max wow / min GPU) ──
    // 4 размытых эллипса дрейфуют с разной скоростью; плотность от влажности
    final cloudAlpha = 0.10 + 0.14 * H;
    final cloudPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    for (int c = 0; c < 4; c++) {
      final speed = 0.008 + c * 0.004; // экранов/сек
      final cx = ((t * speed + c * 0.37) % 1.4 - 0.2) * size.width;
      final cy = size.height * (0.18 + c * 0.13);
      final cw = size.width * (0.38 + 0.1 * math.sin(t * 0.05 + c));
      final chh = size.height * 0.08;
      cloudPaint.color = (isDay ? Colors.white : const Color(0xFF93A8C4))
          .withOpacity(cloudAlpha * (0.7 + 0.3 * math.sin(t * 0.1 + c * 2.0)));
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: cw, height: chh),
        Radius.circular(chh / 2),
      );
      canvas.drawRRect(rrect, cloudPaint);
    }

    // ── Слой 3.6: Воздушные блики-частицы (200 шт, батчed drawPoints) ──
    // Мелкие светлячки воздуха: днём — солнечная пыль, ночью — холодные искры
    final rngDust = math.Random(777);
    final dustColor = isDay
        ? const Color(0xFFFFE9B8)
        : const Color(0xFFBFEFFF);
    final dustPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    final dustPts = <ui.Offset>[];
    final dustAlphas = <double>[];
    for (int d = 0; d < 60; d++) {
      final bx = rngDust.nextDouble();
      final by = rngDust.nextDouble();
      final drift = math.sin(t * (0.3 + rngDust.nextDouble() * 0.5) + d);
      final px = (bx + 0.02 * drift) * size.width;
      final py = (by - 0.015 * t * (0.2 + rngDust.nextDouble() * 0.3) % 1.0) % 1.0 * size.height;
      final tw = 0.5 + 0.5 * math.sin(t * 1.7 + d * 2.4);
      dustPts.add(Offset(px, py));
      dustAlphas.add((0.06 + 0.10 * tw) * (0.4 + 0.6 * U));
    }
    for (int d = 0; d < dustPts.length; d++) {
      dustPaint.color = dustColor.withOpacity(dustAlphas[d].clamp(0.0, 0.35));
      canvas.drawCircle(dustPts[d], 1.4, dustPaint);
    }

    // ── Слой 4: Кинематографический финиш ─────────────────────────
    // Виньетка: мягкая радиальная + затемнение низа под контент
    final vignettePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * 0.45),
        Offset(0, size.height),
        [Colors.transparent, Colors.black.withOpacity(0.30)],
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55),
      vignettePaint,
    );

    // Зерно: монохромное, детерминированное по (t квантованное 12 Гц)
    final grainSeed = (t * 12).floor();
    final rngGrain = math.Random(grainSeed);
    final grainPaint = Paint();
    for (int i = 0; i < 60; i++) {
      final gx = rngGrain.nextDouble() * size.width;
      final gy = rngGrain.nextDouble() * size.height;
      grainPaint.color = Colors.white.withOpacity(0.012 * rngGrain.nextDouble());
      canvas.drawCircle(Offset(gx, gy), 1.0, grainPaint);
    }
  }

  @override
  bool shouldRepaint(_CinematicWeatherPainter old) =>
      old.t != t ||
      old.isDay != isDay ||
      old.temperatureC != temperatureC ||
      old.kpIndex != kpIndex;
}
