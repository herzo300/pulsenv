import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_router.dart';
import '../services/sound_service.dart';

/// Высокохудожественный сплэш-экран «Самотлор Gold» (Нижневартовск):
/// - Атмосферный сибирский антураж (силуэт легендарной вышки Самотлора и монумента «Алёша»).
/// - Физика 3D золотых капель нефти: гравитационное падение, всплески, капли-слезинки с бликами.
/// - Всплывающие золотые микро-пузырьки и мерцающие золотые искры (эмберы).
/// - Центральная жидкая морфинг-капля чёрного золота с золотым ядром и сейсмическими волнами.
/// - Моментальный переход по тапу с тактильным откликом.
class OilSplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const OilSplashScreen({super.key, this.onComplete});

  @override
  State<OilSplashScreen> createState() => _OilSplashScreenState();
}

class _OilSplashScreenState extends State<OilSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _loadingController;
  late AnimationController _fadeController;

  final List<_FallingOilDrop> _fallingDrops = [];
  final List<_OilBubble> _bubbles = [];
  final List<_GoldSparkle> _sparkles = [];
  final List<_SplashRing> _splashRings = [];
  final math.Random _rng = math.Random();
  Timer? _tickerTimer;
  double _time = 0.0;
  bool _ready = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    // Инициализация золотых падающих капель нефти
    for (int i = 0; i < 14; i++) {
      _fallingDrops.add(_FallingOilDrop.random(_rng, initialRandomY: true));
    }

    // Инициализация всплывающих пузырьков
    for (int i = 0; i < 30; i++) {
      _bubbles.add(_OilBubble.random(_rng));
    }

    // Инициализация золотых мерцающих частиц
    for (int i = 0; i < 24; i++) {
      _sparkles.add(_GoldSparkle.random(_rng));
    }

    // Тикер физики и анимации
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      setState(() {
        _time += 0.016;

        // Обновление падающих капель нефти
        for (final drop in _fallingDrops) {
          drop.y += drop.speed;
          drop.x += math.sin(_time * 1.5 + drop.phase) * 0.0004;

          // Достигла низа или центральной зоны — создаём кольцо всплеска
          if (drop.y > 0.96) {
            if (_splashRings.length < 15) {
              _splashRings.add(_SplashRing(
                x: drop.x,
                y: 0.95,
                maxRadius: 18 + _rng.nextDouble() * 22,
                opacity: 0.8,
              ));
            }
            drop.reset(_rng);
          }
        }

        // Обновление колец всплесков
        _splashRings.removeWhere((ring) {
          ring.progress += 0.035;
          return ring.progress >= 1.0;
        });

        // Обновление всплывающих пузырьков
        for (final b in _bubbles) {
          b.y -= b.speed;
          b.x += math.sin(_time * b.wobbleSpeed) * 0.0005;
          if (b.y < -0.05) {
            b.y = 1.05;
            b.x = _rng.nextDouble();
          }
        }

        // Обновление мерцающих искр
        for (final s in _sparkles) {
          s.y -= s.speedY;
          s.x += math.cos(_time * s.freq + s.phase) * 0.0006;
          if (s.y < -0.05) {
            s.y = 1.05;
            s.x = _rng.nextDouble();
          }
        }
      });
    });

    _startLoading();
    SoundService().playSplashDesign('oil');
  }

  Future<void> _startLoading() async {
    await _loadingController.forward();
    if (!mounted) return;
    setState(() => _ready = true);
    _fadeController.forward();
    _onEnter();
  }

  void _onEnter() {
    if (!_ready || _exiting) return;
    HapticFeedback.heavyImpact();
    setState(() => _exiting = true);
    SoundService().stopSplash();

    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        unawaited(AppRouter.navigateAfterSplash(context));
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _loadingController.dispose();
    _fadeController.dispose();
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030408),
      body: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _onEnter();
        },
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          // Фон всё равно на весь экран (Stack рисуется поверх), но
          // контент (город/заголовок) не уезжает под системные панели
          bottom: false,
          child: Stack(
            clipBehavior: Clip.none,
          children: [
            // 1. Фоновый атмосферный сибирский градиент (Ночной Самотлор)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF020306),
                      Color(0xFF070912),
                      Color(0xFF140E04),
                      Color(0xFF030408),
                    ],
                    stops: [0.0, 0.45, 0.85, 1.0],
                  ),
                ),
              ),
            ),

            // 2. Золотое сияние горизонта (Аврора Самотлора)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 0.25),
                    radius: 0.9,
                    colors: [
                      const Color(0xFFD4AF37).withOpacity(0.14 + math.sin(_time * 1.2) * 0.03),
                      const Color(0xFF9A7B1C).withOpacity(0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Самотлорский антураж: Силуэт Нижневартовска + живой ЭКГ-пульс
            Positioned(
              left: 0,
              right: 0,
              bottom: 120,
              height: 240,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SamotlorSilhouettePainter(time: _time),
                ),
              ),
            ),

            // 3.5 ЖИВОЙ силуэт Нижневартовска: 3 слоя параллакса, мерцающие окна,
            // дым из труб, птицы — заставка дышит, а не статичная картинка
            Positioned(
              left: 0,
              right: 0,
              bottom: 118,
              height: 250,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => CustomPaint(
                    painter: LivingCitySilhouettePainter(time: _time),
                  ),
                ),
              ),
            ),

            // 4. Всплывающие золотые пузырьки и мерцающие искры
            Positioned.fill(
              child: CustomPaint(
                painter: _OilAtmospherePainter(
                  bubbles: _bubbles,
                  sparkles: _sparkles,
                  time: _time,
                ),
              ),
            ),

            // 5. Падающие 3D капли жидкого золота (нефти) и волны всплесков
            Positioned.fill(
              child: CustomPaint(
                painter: _FallingGoldDropsPainter(
                  drops: _fallingDrops,
                  splashRings: _splashRings,
                  time: _time,
                ),
              ),
            ),

                        // 6. Бьющийся пульс города: ECG-линия + силуэты высоток Нижневартовска.
            // Каждый удар сердца — здания «вздыхают», волна пульса бежит по крышам.
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return SizedBox(
                    width: 320,
                    height: 320,
                    child: CustomPaint(
                      painter: CityPulsePainter(
                        pulse: _pulseController.value,
                        time: _time,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 7. Типографика на русском языке: ПУЛЬС ГОРОДА + Стекающая золотая нефть
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Заголовок на русском с эффектом стекающей золотой нефти
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFFFFF),
                              Color(0xFFFFDF7D),
                              Color(0xFFD4AF37),
                              Color(0xFFFFF6D6),
                            ],
                            stops: [0.0, 0.35, 0.7, 1.0],
                          ).createShader(bounds),
                          child: Text(
                            'ПУЛЬС ГОРОДА',
                            style: GoogleFonts.exo2(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 6,
                            ),
                          ),
                        ),
                        // Капли золотой нефти, стекающие с букв названия
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _TitleDrippingOilPainter(time: _time),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 1.2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Color(0xFFD4AF37)],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'НИЖНЕВАРТОВСК',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFFFFD54F),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 1.2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFD4AF37), Colors.transparent],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Интерактивный Монитор • 1965 – 2026',
                      style: GoogleFonts.manrope(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Премиальный золотой прогресс-бар со светящейся головкой
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _loadingController,
                          builder: (context, child) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _loadingController.value,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700).withOpacity(0.85),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF8B7320),
                                      Color(0xFFD4AF37),
                                      Color(0xFFFFECB3),
                                      Color(0xFFFFFFFF),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 9. Затемнение при выходе
            if (_exiting)
              Positioned.fill(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Container(
                    color: const Color(0xFF030408),
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// МОДЕЛИ И ФИЗИКА ЧАСТИЦ
// ═══════════════════════════════════════════════════════════════

class _FallingOilDrop {
  _FallingOilDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.goldHue,
  });

  double x;
  double y;
  double length;
  double radius;
  double speed;
  double phase;
  double goldHue;

  factory _FallingOilDrop.random(math.Random rng, {bool initialRandomY = false}) {
    return _FallingOilDrop(
      x: rng.nextDouble(),
      y: initialRandomY ? rng.nextDouble() * 0.9 : -0.1 - rng.nextDouble() * 0.3,
      length: 10.0 + rng.nextDouble() * 18.0,
      radius: 2.2 + rng.nextDouble() * 2.8,
      speed: 0.0035 + rng.nextDouble() * 0.0055,
      phase: rng.nextDouble() * math.pi * 2,
      goldHue: rng.nextDouble(),
    );
  }

  void reset(math.Random rng) {
    x = rng.nextDouble();
    y = -0.08 - rng.nextDouble() * 0.25;
    length = 10.0 + rng.nextDouble() * 18.0;
    radius = 2.2 + rng.nextDouble() * 2.8;
    speed = 0.0035 + rng.nextDouble() * 0.0055;
    phase = rng.nextDouble() * math.pi * 2;
    goldHue = rng.nextDouble();
  }
}

class _OilBubble {
  _OilBubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.wobbleSpeed,
    required this.opacity,
  });

  double x;
  double y;
  double radius;
  double speed;
  double wobbleSpeed;
  double opacity;

  factory _OilBubble.random(math.Random rng) {
    return _OilBubble(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 1.8 + rng.nextDouble() * 4.0,
      speed: 0.0007 + rng.nextDouble() * 0.0014,
      wobbleSpeed: 1.2 + rng.nextDouble() * 2.2,
      opacity: 0.25 + rng.nextDouble() * 0.45,
    );
  }
}

class _GoldSparkle {
  _GoldSparkle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedY,
    required this.freq,
    required this.phase,
    required this.brightness,
  });

  double x;
  double y;
  double radius;
  double speedY;
  double freq;
  double phase;
  double brightness;

  factory _GoldSparkle.random(math.Random rng) {
    return _GoldSparkle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 1.0 + rng.nextDouble() * 2.2,
      speedY: 0.0004 + rng.nextDouble() * 0.0010,
      freq: 1.5 + rng.nextDouble() * 3.0,
      phase: rng.nextDouble() * math.pi * 2,
      brightness: 0.4 + rng.nextDouble() * 0.6,
    );
  }
}

class _SplashRing {
  _SplashRing({
    required this.x,
    required this.y,
    required this.maxRadius,
    required this.opacity,
  });

  double x;
  double y;
  double maxRadius;
  double opacity;
  double progress = 0.0;
}

// ═══════════════════════════════════════════════════════════════
// КАСТОМНЫЕ ПЕЙНТЕРЫ
// ═══════════════════════════════════════════════════════════════

/// Пейнтер сибирского антуража Самотлора (Вышки, монумент «Алёша», буровые станки)
class _SamotlorSilhouettePainter extends CustomPainter {
  final double time;
  _SamotlorSilhouettePainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Туманная подложка
    final mistPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.3),
        Offset(0, h),
        [
          Colors.transparent,
          const Color(0xFFD4AF37).withOpacity(0.04),
          const Color(0xFF1B1405).withOpacity(0.25),
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), mistPaint);

    final silPaint = Paint()
      ..color = const Color(0xFF06080E).withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Холмистый рельеф Самотлора
    final groundPath = Path();
    groundPath.moveTo(0, h);
    groundPath.lineTo(0, h * 0.72);
    groundPath.quadraticBezierTo(w * 0.25, h * 0.65, w * 0.5, h * 0.70);
    groundPath.quadraticBezierTo(w * 0.75, h * 0.75, w, h * 0.68);
    groundPath.lineTo(w, h);
    groundPath.close();
    canvas.drawPath(groundPath, silPaint);

    // 1. Живой неоновый ЭКГ-пульс города (Cyan & Gold Pulse Wave)
    final pulsePath = Path();
    final pulseY = h * 0.62;
    pulsePath.moveTo(0, pulseY);

    final numWavePoints = 60;
    for (int i = 0; i <= numWavePoints; i++) {
      final x = (w / numWavePoints) * i;
      final progress = (x / w + time * 0.4) % 1.0;
      double dy = 0.0;

      // Сигнал сердцебиения
      if (progress > 0.45 && progress < 0.55) {
        final p = (progress - 0.45) / 0.10;
        if (p < 0.2) {
          dy = -8.0;
        } else if (p < 0.5) {
          dy = 32.0; // PQR spike
        } else if (p < 0.8) {
          dy = -48.0; // S-wave peak
        } else {
          dy = 12.0;
        }
      } else {
        dy = math.sin(time * 3.0 + x * 0.05) * 2.5;
      }

      pulsePath.lineTo(x, pulseY + dy);
    }

    final pulseGlow = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawPath(pulsePath, pulseGlow);

    final pulseLine = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(pulsePath, pulseLine);

    // 2. Силуэт легендарной буровой вышки Самотлора (слева)
    final derrickX = w * 0.18;
    final derrickBottom = h * 0.68;
    final derrickHeight = 90.0;
    final derrickTop = derrickBottom - derrickHeight;
    final derrickHalfWidth = 16.0;

    final derrickPath = Path();
    derrickPath.moveTo(derrickX - derrickHalfWidth, derrickBottom);
    derrickPath.lineTo(derrickX - 5, derrickTop);
    derrickPath.lineTo(derrickX + 5, derrickTop);
    derrickPath.lineTo(derrickX + derrickHalfWidth, derrickBottom);
    derrickPath.close();

    final rigPaint = Paint()
      ..color = const Color(0xFF0A0D16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(derrickPath, rigPaint);

    // Распорки вышки
    for (int i = 1; i <= 4; i++) {
      final yLevel = derrickBottom - (derrickHeight / 5) * i;
      final span = derrickHalfWidth * (1.0 - (i / 5.0) * 0.6);
      canvas.drawLine(Offset(derrickX - span, yLevel), Offset(derrickX + span, yLevel), rigPaint);
    }

    // Красный/золотой маячок на вышке
    final beaconPaint = Paint()
      ..color = const Color(0xFFFF3333).withOpacity(0.6 + math.sin(time * 4.0) * 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(derrickX, derrickTop - 2), 2.5, beaconPaint);

    // 3. Силуэт высоток Нижневартовска в центре (проспект Победы)
    final cityX = w * 0.48;
    final cityBottom = h * 0.69;
    final cityPath = Path();
    cityPath.moveTo(cityX - 45, cityBottom);
    cityPath.lineTo(cityX - 45, cityBottom - 35);
    cityPath.lineTo(cityX - 30, cityBottom - 35);
    cityPath.lineTo(cityX - 30, cityBottom - 55); // Высотка
    cityPath.lineTo(cityX - 10, cityBottom - 55);
    cityPath.lineTo(cityX - 10, cityBottom - 40);
    cityPath.lineTo(cityX + 15, cityBottom - 40);
    cityPath.lineTo(cityX + 15, cityBottom - 62); // Дворец Искусств / башня
    cityPath.lineTo(cityX + 35, cityBottom - 62);
    cityPath.lineTo(cityX + 35, cityBottom);
    cityPath.close();
    canvas.drawPath(cityPath, silPaint);

    // 4. Силуэт монумента «Покорителям Самотлора» (Алёша) справа
    final monX = w * 0.82;
    final monBottom = h * 0.70;
    final monHeight = 65.0;

    final monPath = Path();
    monPath.moveTo(monX - 10, monBottom);
    monPath.lineTo(monX - 7, monBottom - monHeight * 0.6);
    monPath.lineTo(monX - 3, monBottom - monHeight * 0.85);
    monPath.lineTo(monX, monBottom - monHeight); // Факел/рука
    monPath.lineTo(monX + 4, monBottom - monHeight * 0.85);
    monPath.lineTo(monX + 8, monBottom - monHeight * 0.5);
    monPath.lineTo(monX + 12, monBottom);
    monPath.close();
    canvas.drawPath(monPath, silPaint);

    // Огонёк факела над монументом
    final torchPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.7 + math.sin(time * 3.5) * 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(monX, monBottom - monHeight - 2), 3.0, torchPaint);
  }

  @override
  bool shouldRepaint(covariant _SamotlorSilhouettePainter oldDelegate) => true;
}

/// Пейнтер стекающей золотой нефти с букв русского заголовка «ПУЛЬС ГОРОДА»
class _TitleDrippingOilPainter extends CustomPainter {
  final double time;
  _TitleDrippingOilPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 8 фиксированных позиций капель под буквами «П У Л Ь С   Г О Р О Д А»
    final dripOffsets = [0.08, 0.20, 0.32, 0.44, 0.58, 0.70, 0.82, 0.92];

    for (int i = 0; i < dripOffsets.length; i++) {
      final dx = dripOffsets[i] * w;
      final phase = i * 1.35;
      final cycle = (time * 0.6 + phase) % 2.5;

      if (cycle < 1.8) {
        // Вытягивающаяся капля нефти
        final dripProgress = cycle / 1.8;
        final len = 4.0 + dripProgress * 22.0;
        final radius = (2.2 - dripProgress * 0.8).clamp(1.0, 3.0);
        final startY = h - 2;

        final path = Path();
        path.moveTo(dx - radius, startY);
        path.quadraticBezierTo(dx, startY + len * 0.7, dx, startY + len);
        path.arcToPoint(
          Offset(dx - radius * 0.5, startY + len),
          radius: Radius.circular(radius),
          clockwise: true,
        );
        path.quadraticBezierTo(dx + radius, startY + len * 0.7, dx + radius, startY);
        path.close();

        final dripPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(dx, startY),
            Offset(dx, startY + len),
            [
              const Color(0xFFFFD700),
              const Color(0xFFB8860B),
              const Color(0xFF3E2723),
            ],
          );

        canvas.drawPath(path, dripPaint);

        // Светящаяся золотая головка капли
        final headPaint = Paint()
          ..color = const Color(0xFFFFF59D).withOpacity(0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(dx, startY + len), radius, headPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TitleDrippingOilPainter oldDelegate) => true;
}

/// Пейнтер падающих 3D золотых капель нефти и волн всплесков
class _FallingGoldDropsPainter extends CustomPainter {
  final List<_FallingOilDrop> drops;
  final List<_SplashRing> splashRings;
  final double time;

  _FallingGoldDropsPainter({
    required this.drops,
    required this.splashRings,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Отрисовка колец всплесков
    for (final ring in splashRings) {
      final ringRadius = ring.maxRadius * ring.progress;
      final ringOpacity = (1.0 - ring.progress) * ring.opacity;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * (1.0 - ring.progress * 0.5)
        ..color = const Color(0xFFFFD700).withOpacity(ringOpacity.clamp(0.0, 1.0));

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ring.x * w, ring.y * h),
          width: ringRadius * 2,
          height: ringRadius * 0.7,
        ),
        ringPaint,
      );
    }

    // 2. Отрисовка падающих капель-слезинок жидкого золота
    for (final d in drops) {
      final cx = d.x * w;
      final cy = d.y * h;
      final r = d.radius;
      final len = d.length;

      final dropPath = Path();
      dropPath.moveTo(cx, cy - len); // Вершина капли
      dropPath.quadraticBezierTo(cx + r * 1.2, cy - len * 0.2, cx + r, cy);
      dropPath.arcToPoint(
        Offset(cx - r, cy),
        radius: Radius.circular(r),
        clockwise: true,
      );
      dropPath.quadraticBezierTo(cx - r * 1.2, cy - len * 0.2, cx, cy - len);
      dropPath.close();

      // Золотой объёмный градиент для капли
      final dropShader = ui.Gradient.linear(
        Offset(cx, cy - len),
        Offset(cx, cy + r),
        [
          const Color(0xFFFFF4C2),
          const Color(0xFFFFD700),
          const Color(0xFF8C6D14),
          const Color(0xFF1E1604),
        ],
        [0.0, 0.4, 0.75, 1.0],
      );

      final dropPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = dropShader;

      canvas.drawPath(dropPath, dropPaint);

      // Блик на капле
      final specularPaint = Paint()
        ..color = Colors.white.withOpacity(0.65)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx - r * 0.35, cy - r * 0.35), r * 0.3, specularPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FallingGoldDropsPainter oldDelegate) => true;
}

/// Пейнтер атмосферных пузырьков и мерцающих золотых искр
class _OilAtmospherePainter extends CustomPainter {
  final List<_OilBubble> bubbles;
  final List<_GoldSparkle> sparkles;
  final double time;

  _OilAtmospherePainter({
    required this.bubbles,
    required this.sparkles,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Отрисовка всплывающих золотых пузырьков
    final bubblePaint = Paint()..style = PaintingStyle.fill;
    for (final b in bubbles) {
      bubblePaint.color = const Color(0xFFFFD700).withOpacity(b.opacity);
      canvas.drawCircle(Offset(b.x * w, b.y * h), b.radius, bubblePaint);

      // Микро-блик на пузырьке
      final glint = Paint()
        ..color = Colors.white.withOpacity(b.opacity * 0.7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(b.x * w - b.radius * 0.3, b.y * h - b.radius * 0.3), b.radius * 0.25, glint);
    }

    // Отрисовка мерцающих золотых искр
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (final s in sparkles) {
      final flicker = (s.brightness + math.sin(time * s.freq + s.phase) * 0.3).clamp(0.0, 1.0);
      sparkPaint.color = const Color(0xFFFFF2B2).withOpacity(flicker);
      canvas.drawCircle(Offset(s.x * w, s.y * h), s.radius, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OilAtmospherePainter oldDelegate) => true;
}

class CityPulsePainter extends CustomPainter {
  final double pulse; // 0..1 цикл удара
  final double time;
  CityPulsePainter({required this.pulse, required this.time});

  double get _beat {
    final t = pulse;
    if (t < 0.12) return Curves.easeOutCubic.transform(t / 0.12) * 0.35;
    if (t < 0.18) return 0.35 - (t - 0.12) / 0.06 * 0.25;
    if (t < 0.26) return 0.10 + Curves.easeOutCubic.transform((t - 0.18) / 0.08) * 0.90;
    if (t < 0.32) return 1.0 - Curves.easeInCubic.transform((t - 0.26) / 0.06) * 1.05;
    if (t < 0.38) return -0.05 + (t - 0.32) / 0.06 * 0.22;
    if (t < 0.46) return 0.17 - (t - 0.38) / 0.08 * 0.17;
    return 0.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final beat = _beat.clamp(-0.1, 1.0).toDouble();
    final beatAbs = beat.abs();
    final baseY = h * 0.62;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.2),
        radius: 1.0,
        colors: [
          Color.lerp(const Color(0x33D4A537), const Color(0x88D4A537), beatAbs)!,
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);

    final cityPaint = Paint()..color = const Color(0xFF0B1626);
    final edgePaint = Paint()
      ..color = Color.lerp(
          const Color(0xFF1E3A5F), const Color(0xFFD4A537), beatAbs * 0.9)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final towers = <double>[0.34, 0.58, 0.42, 0.75, 0.5, 0.95, 0.62, 0.8, 0.45, 0.68, 0.38];
    final n = towers.length;
    const cityWidthFactor = 0.92;
    final towerW = w * cityWidthFactor / n;
    final x0 = w * (1 - cityWidthFactor) / 2;

    for (int i = 0; i < n; i++) {
      final wave = math.sin(time * 1.4 + i * 0.55);
      final lift = beat * towers[i] * (0.55 + 0.45 * math.sin(i * 1.7 + time * 0.8));
      final th = h * towers[i] * (0.72 + 0.28 * wave * 0.3) * (1.0 + lift * 0.16);
      final tx = x0 + i * towerW;
      final rect = Rect.fromLTRB(tx + 1.5, baseY - th, tx + towerW - 1.5, baseY);
      final rrect = RRect.fromRectAndCorners(rect,
          topLeft: const Radius.circular(3), topRight: const Radius.circular(3));
      canvas.drawRRect(rrect, cityPaint);
      canvas.drawRRect(rrect, edgePaint);

      if (beatAbs > 0.25) {
        final winPaint = Paint()
          ..color = const Color(0xFFD4A537).withOpacity(((beatAbs - 0.25) * 1.4).clamp(0.0, 0.9));
        final rng = math.Random(i * 97);
        for (int f = 0; f < 5; f++) {
          for (int c = 0; c < 2; c++) {
            if (rng.nextDouble() > 0.62) continue;
            final wx = rect.left + 4 + c * (rect.width - 8) / 2;
            final wy = rect.top + 8 + f * (rect.height - 14) / 5;
            if (wy < rect.bottom - 8) {
              canvas.drawRRect(
                RRect.fromRectAndRadius(
                    Rect.fromCenter(
                        center: Offset(wx, wy), width: rect.width * 0.22, height: 4),
                    const Radius.circular(1)),
                winPaint);
            }
          }
        }
      }
    }

    final ecg = Path();
    final segW = w * 0.8;
    final ex0 = (w - segW) / 2;
    const steps = 120;
    for (int s = 0; s <= steps; s++) {
      final t = s / steps;
      double y = 0.0;
      final p2 = (time * 0.35 + t) % 1.0;
      if (p2 > 0.40 && p2 < 0.46) {
        y = -0.12;
      } else if (p2 >= 0.46 && p2 < 0.50) {
        y = 0.28;
      } else if (p2 >= 0.50 && p2 < 0.54) {
        y = -0.95;
      } else if (p2 >= 0.54 && p2 < 0.58) {
        y = 0.34;
      } else if (p2 > 0.70 && p2 < 0.80) {
        y = -0.18;
      }
      final px = ex0 + t * segW;
      final py = baseY + y * h * 0.34;
      if (s == 0) {
        ecg.moveTo(px, py);
      } else {
        ecg.lineTo(px, py);
      }
    }
    canvas.drawPath(
      ecg,
      Paint()
        ..color = const Color(0xFFD4A537).withOpacity(0.25 + beatAbs * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(
      ecg,
      Paint()
        ..color = const Color(0xFFFFE9B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round);

    if (beatAbs > 0.3) {
      final ringPhase = ((pulse - 0.26) / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(w / 2, baseY),
        40 + ringPhase * w * 0.55,
        Paint()
          ..color = const Color(0xFFD4A537)
              .withOpacity((1 - ringPhase) * beatAbs * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(CityPulsePainter old) => old.pulse != pulse || old.time != time;
}

/// Живой силуэт города: 3 слоя параллакса (дальний/средний/ближний),
/// мерцающие окна, дым из труб, пролетающие птицы. Полностью процедурный.
class LivingCitySilhouettePainter extends CustomPainter {
  final double time;
  LivingCitySilhouettePainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ─── Слой 1: дальний план (тёмно-синий, медленный дрейф) ───
    _drawLayer(canvas, size,
        color: const Color(0xFF14243C),
        speed: 4,
        yBase: h * 0.55,
        maxH: h * 0.45,
        seedBase: 11,
        opacity: 0.8,
        windows: false);

    // ─── Слой 2: средний план (глубокий синий, окна мерцают) ───
    _drawLayer(canvas, size,
        color: const Color(0xFF0B1830),
        speed: 8,
        yBase: h * 0.75,
        maxH: h * 0.62,
        seedBase: 37,
        opacity: 0.92,
        windows: true);

    // ─── Слой 3: ближний план (почти чёрный + золотые окна + дым) ───
    _drawLayer(canvas, size,
        color: const Color(0xFF060D1A),
        speed: 14,
        yBase: h * 0.95,
        maxH: h * 0.8,
        seedBase: 73,
        opacity: 1.0,
        windows: true,
        smoke: true);

    // ─── Птицы: 5 силуэтов летят across ───
    final birdPaint = Paint()
      ..color = const Color(0xFF0A1626)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int b = 0; b < 5; b++) {
      final t = (time * 0.05 + b * 0.23) % 1.3;
      final bx = t * w * 1.2 - w * 0.1;
      final by = h * 0.18 + math.sin(time * 1.2 + b * 2) * 8 + b * 6.0;
      final flap = math.sin(time * 6 + b * 3) * 4;
      canvas.drawLine(Offset(bx - 5, by + flap * 0.3), Offset(bx, by), birdPaint);
      canvas.drawLine(Offset(bx, by), Offset(bx + 5, by + flap * 0.3), birdPaint);
    }
  }

  void _drawLayer(Canvas canvas, Size size,
      {required Color color,
      required double speed,
      required double yBase,
      required double maxH,
      required int seedBase,
      required double opacity,
      required bool windows,
      bool smoke = false}) {
    final w = size.width;
    final paint = Paint()..color = color.withOpacity(opacity);

    // Дрейф слоя туда-сюда (параллакс)
    final drift = math.sin(time * speed * 0.05 + seedBase) * 6;

    final rng = math.Random(seedBase);
    var path = Path();
    path.moveTo(-20, size.height + 20);

    final towers = <Rect>[];
    double x = -20 + drift;
    while (x < w + 20) {
      final tw = 14.0 + rng.nextDouble() * 22;
      // Вышки Самотлора тонкие + панельки широкие
      final isDerrick = seedBase == 73 && rng.nextDouble() > 0.72;
      final th = isDerrick
          ? maxH * (0.9 + rng.nextDouble() * 0.1)
          : maxH * (0.35 + rng.nextDouble() * 0.65);
      final top = yBase - th;
      if (isDerrick) {
        // Вышка: пирамида-силуэт
        path.lineTo(x + tw * 0.2, top);
        path.lineTo(x + tw * 0.5, top - 6);
        path.lineTo(x + tw * 0.8, top);
      } else {
        path.lineTo(x, top);
        path.lineTo(x + tw, top);
        towers.add(Rect.fromLTRB(x, top, x + tw, yBase));
      }
      x += tw + 3 + rng.nextDouble() * 10;
    }
    path.lineTo(w + 20, size.height + 20);
    path.close();
    canvas.drawPath(path, paint);

    // Мерцающие золотые окна
    if (windows) {
      for (final r in towers) {
        final rngW = math.Random(r.left.toInt() * 31 + seedBase);
        final cols = (r.width / 6).floor();
        final rows = (r.height / 9).floor();
        for (int c = 0; c < cols; c++) {
          for (int rr = 0; rr < rows; rr++) {
            if (rngW.nextDouble() > 0.24) continue;
            final tw2 = 0.5 + 0.5 * math.sin(time * 0.9 + c * 1.7 + rr * 2.3 + r.left);
            final alpha = (0.14 + 0.30 * tw2).clamp(0.0, 0.6);
            if (alpha < 0.1) continue;
            canvas.drawRect(
              Rect.fromLTWH(r.left + 3 + c * 6, r.top + 4 + rr * 9, 2.5, 3.5),
              Paint()..color = const Color(0xFFD4A537).withOpacity(alpha),
            );
          }
        }
      }
    }

    // Дым из труб (только ближний слой)
    if (smoke) {
      final smokePaint = Paint()
        ..color = const Color(0x30445566)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      for (final r in towers.take(4)) {
        for (int p = 0; p < 3; p++) {
          final ph = (time * 0.3 + p * 0.33 + r.left * 0.01) % 1.0;
          final sy = r.top - ph * 30;
          final sx = r.left + r.width * 0.3 + math.sin(time + p) * 4;
          canvas.drawCircle(Offset(sx, sy), 3 + ph * 5, smokePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(LivingCitySilhouettePainter old) => old.time != time;
}
