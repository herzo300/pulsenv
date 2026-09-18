// lib/widgets/weather_glass_orb.dart
//
// Живой Центр Визуализации Погоды (Weather Living Hero Art).
//
// Вместо однотипного шарика рендерит динамический живой погодный арт:
//   • Ясно/День: Сияющее 3D-Солнце с вращающимися лучами, короной и солнечными протуберанцами;
//   • Ночь: Объемная 3D-Луна с кратерами, мерцающим звездным полем и лунным сиянием;
//   • Облачно: Объемный многослойный кластер 3D-облаков с мягким рассеиванием света;
//   • Дождь: Дождевое 3D-облако с потоком падающих светящихся капель и брызгами;
//   • Гроза: Штормовая туча с динамическими разрядами молний и электрическими искрами;
//   • Снег: Вращающаяся 3D-снежинка/кристалл с гексагональными дендритами и алмазной пылью;
//   • Туман: Дрейфующие слои плотного объемного тумана и атмосферного марева.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class WeatherGlassOrb extends StatefulWidget {
  final String condition;
  final Color accent;
  final double size;
  final bool isDay;
  final double moonPhase; // 0.0 to 1.0 (0=New, 0.25=First Q, 0.5=Full, 0.75=Last Q)

  const WeatherGlassOrb({
    super.key,
    required this.condition,
    required this.accent,
    this.size = 140,
    this.isDay = true,
    this.moonPhase = 0.48,
  });

  @override
  State<WeatherGlassOrb> createState() => _WeatherGlassOrbState();
}

class _WeatherGlassOrbState extends State<WeatherGlassOrb>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _lightningController;

  final math.Random _rng = math.Random(1337);
  late final List<_HeroParticle> _particles;

  StreamSubscription<AccelerometerEvent>? _sensorSub;
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _lightningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _initParticles();
    _initSensors();
  }

  void _initSensors() {
    try {
      _sensorSub = accelerometerEventStream().listen((event) {
        if (mounted) {
          setState(() {
            _tiltX = (event.x / 9.8).clamp(-1.0, 1.0) * -0.25;
            _tiltY = (event.y / 9.8).clamp(-1.0, 1.0) * 0.25;
          });
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _initParticles() {
    _particles = [];
    final k = widget.condition.toLowerCase();
    final isRain = k.contains('rain') || k.contains('дожд') || k.contains('storm') || k.contains('гроз');
    final isSnow = k.contains('snow') || k.contains('снег') || k.contains('ice') || k.contains('метель');
    final isSun = widget.isDay && (k.contains('clear') || k.contains('ясн') || k.contains('солн'));
    final isNight = !widget.isDay;

    final count = isRain ? 28 : (isSnow ? 32 : (isSun ? 24 : (isNight ? 26 : 18)));
    for (int i = 0; i < count; i++) {
      _particles.add(_HeroParticle(
        x: _rng.nextDouble() * 2 - 1,
        y: _rng.nextDouble() * 2 - 1,
        speed: 0.008 + _rng.nextDouble() * 0.02,
        size: 1.5 + _rng.nextDouble() * 3.0,
        angle: _rng.nextDouble() * math.pi * 2,
        color: isSun
            ? const Color(0xFFFFD54F)
            : (isNight
                ? const Color(0xFFC7D2FE)
                : (isSnow
                    ? Colors.white
                    : (isRain ? const Color(0xFF38BDF8) : const Color(0xFF00E5FF)))),
      ));
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _rotationController.dispose();
    _pulseController.dispose();
    _lightningController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return SizedBox(
      width: size + 36,
      height: size + 36,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationController,
          _pulseController,
          _lightningController,
        ]),
        builder: (context, child) {
          return CustomPaint(
            size: Size(size + 36, size + 36),
            painter: _WeatherLivingHeroPainter(
              condition: widget.condition,
              accent: widget.accent,
              isDay: widget.isDay,
              moonPhase: widget.moonPhase,
              rotProgress: _rotationController.value,
              pulseProgress: _pulseController.value,
              lightningProgress: _lightningController.value,
              particles: _particles,
              tiltX: _tiltX,
              tiltY: _tiltY,
            ),
          );
        },
      ),
    );
  }
}

class _HeroParticle {
  double x;
  double y;
  double speed;
  double size;
  double angle;
  Color color;

  _HeroParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.angle,
    required this.color,
  });
}

class _WeatherLivingHeroPainter extends CustomPainter {
  final String condition;
  final Color accent;
  final bool isDay;
  final double moonPhase;
  final double rotProgress;
  final double pulseProgress;
  final double lightningProgress;
  final List<_HeroParticle> particles;
  final double tiltX;
  final double tiltY;

  _WeatherLivingHeroPainter({
    required this.condition,
    required this.accent,
    required this.isDay,
    required this.moonPhase,
    required this.rotProgress,
    required this.pulseProgress,
    required this.lightningProgress,
    required this.particles,
    required this.tiltX,
    required this.tiltY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 + tiltX * 10, size.height / 2 + tiltY * 10);
    final radius = (size.width - 40) / 2;

    final k = condition.toLowerCase();
    final isThunder = k.contains('storm') || k.contains('гроз') || k.contains('ливень');
    final isRain = !isThunder && (k.contains('rain') || k.contains('дожд') || k.contains('морось'));
    final isSnow = k.contains('snow') || k.contains('снег') || k.contains('ice') || k.contains('метель') || k.contains('град');
    final isFog = k.contains('fog') || k.contains('туман') || k.contains('mist') || k.contains('дымка');
    final isSun = isDay && (k.contains('clear') || k.contains('ясн') || k.contains('солн'));
    final isNight = !isDay;

    if (isThunder) {
      _paintThunderstorm(canvas, center, radius);
    } else if (isRain) {
      _paintRainCloud(canvas, center, radius);
    } else if (isSnow) {
      _paintSnowCrystal(canvas, center, radius);
    } else if (isFog) {
      _paintFogAtmosphere(canvas, center, radius);
    } else if (isSun) {
      _paintRadiantSun(canvas, center, radius);
    } else if (isNight) {
      _paintMoonAndStars(canvas, center, radius);
    } else {
      _paintVolumetricClouds(canvas, center, radius);
    }
  }

  // ─── 1. СОЛНЦЕ (Day Clear / Sunny) ───
  void _paintRadiantSun(Canvas canvas, Offset center, double radius) {
    final sunRadius = radius * 0.72;
    final pulse = pulseProgress;

    // Внешнее солнечное свечение (Halo)
    canvas.drawCircle(
      center,
      sunRadius * (1.35 + 0.15 * pulse),
      Paint()
        ..color = const Color(0xFFFFB300).withOpacity(0.22 + 0.1 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );

    // Вращающиеся солнечные лучи (12 лучей разной длины)
    final rayPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFE082), Color(0xFFFF9800), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: sunRadius * 1.5))
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * math.pi / 6) + rotProgress * math.pi * 2;
      final rayLen = (i % 2 == 0 ? 1.45 : 1.25) * sunRadius + (math.sin(angle * 3 + pulse * math.pi) * 4);
      final pStart = center + Offset(math.cos(angle) * (sunRadius * 0.95), math.sin(angle) * (sunRadius * 0.95));
      final pEnd = center + Offset(math.cos(angle) * rayLen, math.sin(angle) * rayLen);
      canvas.drawLine(pStart, pEnd, rayPaint);
    }

    // Солнечное ядро
    final sunShader = RadialGradient(
      center: const Alignment(-0.25, -0.25),
      colors: const [
        Color(0xFFFFFDE7),
        Color(0xFFFFEE58),
        Color(0xFFFFA726),
        Color(0xFFE65100),
      ],
      stops: const [0.0, 0.35, 0.75, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: sunRadius));

    canvas.drawCircle(center, sunRadius, Paint()..shader = sunShader);

    // Коронарный блик
    final flarePaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center + Offset(-sunRadius * 0.35, -sunRadius * 0.35), sunRadius * 0.22, flarePaint);
  }

  // ─── 2. ЛУНА И ЗВЕЗДЫ (Night Clear) ───
  void _paintMoonAndStars(Canvas canvas, Offset center, double radius) {
    final moonRadius = radius * 0.75;
    final pulse = pulseProgress;

    // Звездное поле вокруг луны
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final twinkle = (math.sin(rotProgress * math.pi * 6 + i) * 0.5 + 0.5).clamp(0.2, 1.0);
      final px = center.dx + p.x * radius * 1.35;
      final py = center.dy + p.y * radius * 1.35;

      canvas.drawCircle(
        Offset(px, py),
        p.size * (0.8 + 0.4 * twinkle),
        Paint()..color = Colors.white.withOpacity(0.4 * twinkle),
      );
    }

    // Небесное лунное гало
    canvas.drawCircle(
      center,
      moonRadius * (1.3 + 0.1 * pulse),
      Paint()
        ..color = const Color(0xFF818CF8).withOpacity(0.25 + 0.08 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    // Объемный темный диск Луны
    final moonDarkPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, 0.2),
        colors: const [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF030712)],
      ).createShader(Rect.fromCircle(center: center, radius: moonRadius));
    canvas.drawCircle(center, moonRadius, moonDarkPaint);

    // Освещенный полумесяц / фаза Луны
    final crescentPath = Path()
      ..addArc(Rect.fromCircle(center: center, radius: moonRadius), -math.pi / 2, math.pi);
    crescentPath.addArc(
      Rect.fromCenter(center: center + Offset(-moonRadius * 0.25, 0), width: moonRadius * 1.2, height: moonRadius * 2),
      math.pi / 2,
      -math.pi,
    );

    final moonLightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: const [Color(0xFFFFFFFF), Color(0xFFE2E8F0), Color(0xFF94A3B8)],
      ).createShader(Rect.fromCircle(center: center, radius: moonRadius));

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: moonRadius)));
    canvas.drawPath(crescentPath, moonLightPaint);

    // Кратеры
    final craterPaint = Paint()..color = const Color(0xFF64748B).withOpacity(0.4);
    canvas.drawCircle(center + Offset(moonRadius * 0.2, -moonRadius * 0.2), 5, craterPaint);
    canvas.drawCircle(center + Offset(moonRadius * 0.35, moonRadius * 0.15), 4, craterPaint);
    canvas.restore();
  }

  // ─── 3. ОБЛАКА (Cloudy / Overcast) ───
  void _paintVolumetricClouds(Canvas canvas, Offset center, double radius) {
    final floatY = math.sin(rotProgress * math.pi * 2) * 5;
    final cloudCenter = center + Offset(0, floatY);

    // Солнечный луч сзади облака
    canvas.drawCircle(
      cloudCenter + Offset(-radius * 0.45, -radius * 0.25),
      radius * 0.45,
      Paint()
        ..color = const Color(0xFFFFB300).withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Объемные слои облаков (3-слойный пушистый кучевый кластер)
    _drawCloudShape(canvas, cloudCenter + const Offset(-18, -4), radius * 0.68, const Color(0xFF64748B), 0.7);
    _drawCloudShape(canvas, cloudCenter + const Offset(14, 6), radius * 0.62, const Color(0xFF94A3B8), 0.85);
    _drawCloudShape(canvas, cloudCenter, radius * 0.75, const Color(0xFFE2E8F0), 1.0);
  }

  void _drawCloudShape(Canvas canvas, Offset pos, double r, Color color, double opacity) {
    final cloudPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(opacity), color.withOpacity(opacity * 0.7)],
      ).createShader(Rect.fromCircle(center: pos, radius: r));

    final path = Path();
    path.addOval(Rect.fromCenter(center: pos, width: r * 1.6, height: r * 0.95));
    path.addOval(Rect.fromCenter(center: pos + Offset(-r * 0.35, -r * 0.15), width: r * 0.9, height: r * 0.85));
    path.addOval(Rect.fromCenter(center: pos + Offset(r * 0.28, -r * 0.2), width: r * 0.95, height: r * 0.9));
    path.addOval(Rect.fromCenter(center: pos + Offset(0, -r * 0.35), width: r * 1.1, height: r * 0.95));

    canvas.drawPath(path, cloudPaint);
  }

  // ─── 4. ДОЖДЕВОЕ ОБЛАКО (Rain) ───
  void _paintRainCloud(Canvas canvas, Offset center, double radius) {
    final cloudPos = center + Offset(0, -radius * 0.2);

    // Облако
    _drawCloudShape(canvas, cloudPos, radius * 0.72, const Color(0xFF475569), 0.95);

    // Падающие светящиеся капли дождя
    final dropPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 14; i++) {
      final col = (i % 7) - 3;
      final speedOffset = (rotProgress * 4 + i * 0.25) % 1.0;
      final dx = cloudPos.dx + col * (radius * 0.22);
      final dy = cloudPos.dy + radius * 0.35 + (speedOffset * radius * 0.75);

      canvas.drawLine(
        Offset(dx, dy),
        Offset(dx - 2, dy + 8),
        dropPaint..color = const Color(0xFF38BDF8).withOpacity(1.0 - speedOffset * 0.7),
      );
    }
  }

  // ─── 5. ГРОЗОВАЯ ТУЧА С МОЛНИЯМИ (Thunderstorm) ───
  void _paintThunderstorm(Canvas canvas, Offset center, double radius) {
    final cloudPos = center + Offset(0, -radius * 0.15);
    final flash = (lightningProgress * 10).toInt() % 4 == 0 ? 0.7 : 0.0;

    // Вспышка молнии
    if (flash > 0) {
      canvas.drawCircle(
        cloudPos,
        radius * 1.3,
        Paint()
          ..color = const Color(0xFFC084FC).withOpacity(flash * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
      );
    }

    // Темная грозовая туча
    _drawCloudShape(canvas, cloudPos, radius * 0.75, const Color(0xFF1E1B4B), 1.0);

    // Разряд молнии
    final boltPath = Path();
    boltPath.moveTo(cloudPos.dx - 6, cloudPos.dy + radius * 0.25);
    boltPath.lineTo(cloudPos.dx + 4, cloudPos.dy + radius * 0.55);
    boltPath.lineTo(cloudPos.dx - 4, cloudPos.dy + radius * 0.58);
    boltPath.lineTo(cloudPos.dx + 12, cloudPos.dy + radius * 0.95);

    canvas.drawPath(
      boltPath,
      Paint()
        ..color = const Color(0xFFFDE047)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  // ─── 6. ЛЕДЯНОЙ КРИСТАЛЛ / СНЕЖИНКА (Snow) ───
  void _paintSnowCrystal(Canvas canvas, Offset center, double radius) {
    final crystalRadius = radius * 0.75;
    final pulse = pulseProgress;

    // Ледяное сияние
    canvas.drawCircle(
      center,
      crystalRadius * (1.25 + 0.1 * pulse),
      Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.3 + 0.1 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // 6-лучевая кристальная снежинка
    final flakePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) + rotProgress * 0.6;
      final armEnd = center + Offset(math.cos(angle) * crystalRadius, math.sin(angle) * crystalRadius);
      canvas.drawLine(center, armEnd, flakePaint);

      // Ответвления
      for (double d = 0.4; d <= 0.8; d += 0.3) {
        final branchRoot = center + Offset(math.cos(angle) * (crystalRadius * d), math.sin(angle) * (crystalRadius * d));
        final branch1 = branchRoot + Offset(math.cos(angle + math.pi / 4) * (crystalRadius * 0.25), math.sin(angle + math.pi / 4) * (crystalRadius * 0.25));
        final branch2 = branchRoot + Offset(math.cos(angle - math.pi / 4) * (crystalRadius * 0.25), math.sin(angle - math.pi / 4) * (crystalRadius * 0.25));
        canvas.drawLine(branchRoot, branch1, flakePaint..strokeWidth = 1.6);
        canvas.drawLine(branchRoot, branch2, flakePaint..strokeWidth = 1.6);
      }
    }

    // Центральный кристаллический шестиугольник
    canvas.drawCircle(center, crystalRadius * 0.18, Paint()..color = const Color(0xFF7DD3FC));
    canvas.drawCircle(center, crystalRadius * 0.1, Paint()..color = Colors.white);
  }

  // ─── 7. ТУМАН / ДЫМКА (Fog) ───
  void _paintFogAtmosphere(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < 4; i++) {
      final yOffset = (i - 1.5) * (radius * 0.45) + math.sin(rotProgress * math.pi * 2 + i) * 6;
      final fogPaint = Paint()
        ..color = const Color(0xFFE2E8F0).withOpacity(0.35 + 0.1 * math.cos(i.toDouble()))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center + Offset(0, yOffset), width: radius * 1.8, height: radius * 0.35),
          const Radius.circular(20),
        ),
        fogPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherLivingHeroPainter oldDelegate) => true;
}
