import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../theme/pulse_colors.dart';
import '../core/app_router.dart';
import '../services/sound_service.dart';
import '../map/map_config.dart';

class MonitorSplashScreen extends StatefulWidget {
  const MonitorSplashScreen({super.key});

  @override
  State<MonitorSplashScreen> createState() => _MonitorSplashScreenState();
}

class _MonitorSplashScreenState extends State<MonitorSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final AnimationController _pulseController;
  late final AnimationController _marqueeController;
  late final AnimationController _fadeController;

  bool _ready = false;
  bool _exiting = false;

  // Fake news ticker items
  final List<String> _news = [
    'НОВОСТИ: НА НАБЕРЕЖНОЙ ОБИ ИДЕТ ФЕСТИВАЛЬ САМОТЛОРСКИЕ НОЧИ',
    'ЖКХ: ПЛАНОВОЕ ОТКЛЮЧЕНИЕ ГОРЯЧЕЙ ВОДЫ В 10Б МИКРОРАЙОНЕ',
    'СОБЫТИЯ: НА СТАДИОНЕ ЦЕНТРАЛЬНЫЙ ПРОХОДИТ ОТКРЫТИЕ ПРАЗДНИКА',
    'ЭКОЛОГИЯ: УРОВЕНЬ ВОДЫ В РЕКЕ ОБЬ В ПРЕДЕЛАХ НОРМЫ',
    'АЛЕРТ: ОЖИДАЕТСЯ УСИЛЕНИЕ ВЕТРА ДО 15 М/С В СТВОРЕ УЛИЦЫ МИРА',
  ];

  final List<Offset> _eventDots = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 24; i++) {
      _eventDots.add(Offset(_rng.nextDouble(), _rng.nextDouble()));
    }

    _scanController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _marqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fetchRealSignals();
    _simulateLoading();
    SoundService()
        .playSplashDesign('monitor'); // Using monitor voiceover
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    setState(() => _ready = true);
    _fadeController.forward();
    SoundService().playPulse();
    _onEnter();
  }

  void _onEnter() {
    if (!_ready || _exiting) return;
    HapticFeedback.heavyImpact();
    setState(() => _exiting = true);
    SoundService().stopSplash();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      unawaited(AppRouter.navigateAfterSplash(context));
    });
  }

  Future<void> _fetchRealSignals() async {
    try {
      final response = await http.get(
        Uri.parse('${MapConfig.backendApiBaseUrl}/map/feed?limit=10'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(response.bodyBytes));
        final markers = payload is Map<String, dynamic>
            ? (payload['markers'] as List<dynamic>? ?? [])
            : [];
        if (markers.isNotEmpty) {
          final List<String> fetchedNews = [];
          for (final marker in markers) {
            final title = marker['title']?.toString() ?? '';
            final category = marker['category']?.toString() ?? '';
            if (title.isNotEmpty) {
              fetchedNews.add('${category.toUpperCase()}: ${title.toUpperCase()}');
            }
          }
          if (mounted && fetchedNews.isNotEmpty) {
            setState(() {
              _news.clear();
              _news.addAll(fetchedNews);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch real signals for splash: $e");
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _marqueeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseColors.background,
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _exiting ? 0.0 : 1.0,
        child: Stack(
          children: [
            // Background interactive map-like grid
            Positioned.fill(
              child: CustomPaint(
                painter: _MonitorGridPainter(
                  scanProgress: _scanController.value,
                  pulseProgress: _pulseController.value,
                  dots: _eventDots,
                ),
                willChange: true,
              ),
            ),

            // Map scanning overlay
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return Positioned.fill(
                  child: CustomPaint(
                    painter: _RadarPainter(_scanController.value),
                  ),
                );
              },
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Top title
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [PulseColors.primary, PulseColors.success],
                    ).createShader(bounds),
                    child: Text(
                      'МОНИТОР НИЖНЕВАРТОВСКА',
                      style: GoogleFonts.exo2(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ПУЛЬС СОБЫТИЙ В РЕАЛЬНОМ ВРЕМЕНИ',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const Spacer(),

                   // Central interactive element
                  GestureDetector(
                    onTap: _onEnter,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulse = _pulseController.value;
                        final scale = _ready ? 1.0 + (pulse * 0.05) : 0.9;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.4),
                              border: Border.all(
                                color: PulseColors.primary.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: PulseColors.primary.withOpacity(0.12),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Rotating outer ring
                                AnimatedBuilder(
                                  animation: _scanController,
                                  builder: (context, _) {
                                    return Transform.rotate(
                                      angle: _scanController.value * 2 * math.pi,
                                      child: Container(
                                        width: 154,
                                        height: 154,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: PulseColors.primary.withOpacity(0.45),
                                            width: 2.0,
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              top: 10,
                                              left: 72,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Colors.yellowAccent,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.yellowAccent,
                                                      blurRadius: 6,
                                                      spreadRadius: 1,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Counter-rotating inner ring
                                AnimatedBuilder(
                                  animation: _scanController,
                                  builder: (context, _) {
                                    return Transform.rotate(
                                      angle: -_scanController.value * 4 * math.pi,
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: PulseColors.success.withOpacity(0.35),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Pulsing central glow and button text
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        PulseColors.primary.withOpacity(0.35 + pulse * 0.15),
                                        PulseColors.primary.withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _ready ? 'ЗАПУСК' : 'ЗАГРУЗКА',
                                      style: GoogleFonts.exo2(
                                        color: _ready ? Colors.white : PulseColors.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2.5,
                                        shadows: [
                                          Shadow(
                                            color: PulseColors.primary,
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Spacer(),

                  // Bottom mini-window info panel
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: PulseColors.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: PulseColors.primary.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PulseColors.primary.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: PulseColors.primary.withOpacity(0.15),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14)),
                              border: Border(
                                bottom: BorderSide(
                                  color: PulseColors.primary.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.satellite_alt_rounded,
                                    color: PulseColors.primary, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'СВОДКА СОБЫТИЙ',
                                  style: GoogleFonts.exo2(
                                    color: PulseColors.primary,
                                    fontSize: 11,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, _) => Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: PulseColors.negative.withOpacity(
                                          0.5 + _pulseController.value * 0.5),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: PulseColors.negative
                                              .withOpacity(0.6),
                                          blurRadius: 6,
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ЭФИР',
                                  style: GoogleFonts.manrope(
                                    color: PulseColors.negative,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ClipRect(
                              child: AnimatedBuilder(
                                  animation: _marqueeController,
                                  builder: (context, _) {
                                    // Simplified running text
                                    final fullText = _news.join('   •••   ');
                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        final textStyle = GoogleFonts.manrope(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        );
                                        // Calculate offset based on time
                                        return Transform.translate(
                                          offset: Offset(
                                              constraints.maxWidth -
                                                  (_marqueeController.value *
                                                      2000),
                                              16),
                                          child: Text(
                                            '$fullText   •••   $fullText',
                                            style: textStyle,
                                            maxLines: 1,
                                            overflow: TextOverflow.visible,
                                            softWrap: false,
                                          ),
                                        );
                                      },
                                    );
                                  }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorGridPainter extends CustomPainter {
  final double scanProgress;
  final double pulseProgress;
  final List<Offset> dots;

  _MonitorGridPainter({
    required this.scanProgress,
    required this.pulseProgress,
    required this.dots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw map grid
    final gridPaint = Paint()
      ..color = PulseColors.primary.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw glowing event dots
    final dotPaint = Paint()
      ..color = PulseColors.success
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = PulseColors.success.withOpacity(0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (int i = 0; i < dots.length; i++) {
      final dx = dots[i].dx * size.width;
      final dy = dots[i].dy * size.height;

      // Make them pulse individually a bit
      final localPulse = (math.sin(pulseProgress * math.pi * 2 + i) + 1) / 2;

      canvas.drawCircle(Offset(dx, dy), 2, dotPaint);
      if (localPulse > 0.3) {
        canvas.drawCircle(Offset(dx, dy), 4 + localPulse * 4, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MonitorGridPainter oldDelegate) => true;
}

class _RadarPainter extends CustomPainter {
  final double progress;

  _RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;

    final radius = progress * maxRadius;

    final paint = Paint()
      ..color = PulseColors.primary.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, paint);

    // Sweep gradient
    final sweepPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [
          PulseColors.primary.withOpacity(0.0),
          PulseColors.primary.withOpacity(0.15),
          PulseColors.primary.withOpacity(0.0),
        ],
        [0.0, 0.1, 0.2],
        TileMode.clamp,
        progress * math.pi * 2,
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
