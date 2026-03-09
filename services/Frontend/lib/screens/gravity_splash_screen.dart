import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'map_screen.dart';
import '../services/sound_service.dart';

/// Splash Screen «Цифровая Невесомость»
/// - Горизонтальная сканирующая линия бежит сверху вниз
/// - Плавающие невесомые данные (буквы/цифры) всплывают как в космосе
/// - Глубокий темный фон с мягким градиентом
class GravitySplashScreen extends StatefulWidget {
  const GravitySplashScreen({super.key});

  @override
  State<GravitySplashScreen> createState() => _GravitySplashScreenState();
}

class _GravitySplashScreenState extends State<GravitySplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Ticker _ticker;

  final List<_FloatingGlyph> _glyphs = [];
  final math.Random _rng = math.Random();
  double _time = 0;
  bool _ready = false;
  bool _exiting = false;

  // Palette
  static const Color _deep = Color(0xFF020814);
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _teal = Color(0xFF1DE9B6);
  static const Color _blue = Color(0xFF448AFF);

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.forward || status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          if (status == AnimationStatus.forward) {
            // Pulsar beat trigger
            if (_ready && !_exiting) {
               SoundService().playPulse();
            }
          }
        }
    })
    ..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Init floating glyphs
    for (int i = 0; i < 60; i++) {
      _glyphs.add(_FloatingGlyph.random(_rng));
    }

    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    })..start();

    _simulateLoading();
    SoundService().playSplash();
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    setState(() => _ready = true);
    _fadeController.forward();
  }

  void _onEnter() {
    if (!_ready || _exiting) return;
    HapticFeedback.heavyImpact();
    setState(() => _exiting = true);

    SoundService().stopSplash();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, anim, secAnim) => const MapScreen(),
          transitionsBuilder: (context, anim, secAnim, child) {
            return FadeTransition(opacity: anim, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _deep,
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _exiting ? 0.0 : 1.0,
        child: Stack(
          children: [
            // 1. Deep radial gradient background
            Positioned.fill(
              child: CustomPaint(
                painter: _DeepSpacePainter(time: _time),
              ),
            ),

            // 2. Floating data glyphs
            Positioned.fill(
              child: CustomPaint(
                painter: _GlyphPainter(glyphs: _glyphs, time: _time),
              ),
            ),

            // 3. Scanning line
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, _) {
                final scanY = _scanController.value * (size.height + 80) - 40;
                return Positioned(
                  left: 0,
                  right: 0,
                  top: scanY,
                  child: _buildScanLine(size.width),
                );
              },
            ),

            // 4. Central UI
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo / Title
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final glow = _ready
                              ? 0.6 + math.sin(_pulseController.value * math.pi * 2) * 0.4
                              : 0.3;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _cyan.withOpacity(glow),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cyan.withOpacity(glow * 0.5),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.radar_rounded,
                                  color: _cyan.withOpacity(glow),
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'ЦИФРОВАЯ',
                                style: TextStyle(
                                  color: _cyan.withOpacity(0.6),
                                  fontSize: 11,
                                  letterSpacing: 10,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [_cyan, _teal, _blue],
                                ).createShader(bounds),
                                child: const Text(
                                  'НЕВЕСОМОСТЬ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ПУЛЬС · НИЖНЕВАРТОВСК',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 10,
                                  letterSpacing: 5,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 48),

                      // Core button
                      GestureDetector(
                        onTap: _onEnter,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final heartbeat = _ready
                                ? math.sin(_pulseController.value * math.pi * 2) * 0.1
                                : 0.0;
                            final scale = _ready ? 1.0 + heartbeat : 0.85;

                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _cyan.withOpacity(_ready ? 0.3 : 0.08),
                                      _deep,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: _cyan.withOpacity(_ready ? 0.8 : 0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: _ready
                                      ? [
                                          BoxShadow(
                                            color: _cyan.withOpacity(0.4 + heartbeat),
                                            blurRadius: 25,
                                            spreadRadius: 3,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Icon(
                                    _ready ? Icons.fingerprint : Icons.hourglass_empty_rounded,
                                    color: _cyan.withOpacity(_ready ? 1.0 : 0.4),
                                    size: 30,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Status text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: _ready
                            ? const Text(
                                'АКТИВИРОВАТЬ СИСТЕМУ',
                                key: ValueKey('ready'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : Text(
                                'КАЛИБРОВКА СЕНСОРОВ...',
                                key: const ValueKey('loading'),
                                style: TextStyle(
                                  color: _cyan.withOpacity(0.5),
                                  fontSize: 11,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Thin horizontal grid lines (ambient)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GridOverlayPainter(time: _time),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanLine(double width) {
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          // Glow behind the line
          Positioned(
            left: 0,
            right: 0,
            top: 15,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _cyan.withOpacity(0.15),
                    _teal.withOpacity(0.25),
                    _cyan.withOpacity(0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),
          // The scan line itself
          Positioned(
            left: 0,
            right: 0,
            top: 19,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _cyan.withOpacity(0.6),
                    _teal,
                    _cyan.withOpacity(0.6),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _cyan.withOpacity(0.8),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Trail above the line
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _cyan.withOpacity(0.04),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// Floating Glyph data
// ════════════════════════════════════════════

class _FloatingGlyph {
  double x, y;
  double vx, vy;
  String char;
  double size;
  double alpha;
  double phase;

  _FloatingGlyph({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.char,
    required this.size,
    required this.alpha,
    required this.phase,
  });

  factory _FloatingGlyph.random(math.Random rng) {
    const chars = '01АБВ∑∫λπΔΩ≈•◦∞×÷ⓅⓊⓁⓈ';
    return _FloatingGlyph(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      vx: (rng.nextDouble() - 0.5) * 0.008,
      vy: (rng.nextDouble() - 0.5) * 0.006 - 0.003, // slight upward drift
      char: chars[rng.nextInt(chars.length)],
      size: 8 + rng.nextDouble() * 14,
      alpha: 0.05 + rng.nextDouble() * 0.15,
      phase: rng.nextDouble() * math.pi * 2,
    );
  }
}

// ════════════════════════════════════════════
// Painters
// ════════════════════════════════════════════

class _DeepSpacePainter extends CustomPainter {
  final double time;
  _DeepSpacePainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle radial gradient in center
    final center = Offset(size.width * 0.5, size.height * 0.45);
    final radius = size.height * 0.6;
    final pulse = 0.08 + math.sin(time * 0.5) * 0.03;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          const Color(0xFF00E5FF).withOpacity(pulse),
          const Color(0xFF1DE9B6).withOpacity(pulse * 0.4),
          Colors.transparent,
        ],
        [0.0, 0.4, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _DeepSpacePainter old) => true;
}

class _GlyphPainter extends CustomPainter {
  final List<_FloatingGlyph> glyphs;
  final double time;
  _GlyphPainter({required this.glyphs, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in glyphs) {
      // Update position (drift in zero-g)
      g.x += g.vx;
      g.y += g.vy;

      // Wrap around
      if (g.x < -0.05) g.x = 1.05;
      if (g.x > 1.05) g.x = -0.05;
      if (g.y < -0.05) g.y = 1.05;
      if (g.y > 1.05) g.y = -0.05;

      // Pulsating alpha
      final alphaOsc = g.alpha * (0.5 + 0.5 * math.sin(time * 1.5 + g.phase));
      final color = const Color(0xFF00E5FF).withOpacity(alphaOsc.clamp(0.01, 0.25));

      final tp = TextPainter(
        text: TextSpan(
          text: g.char,
          style: TextStyle(
            color: color,
            fontSize: g.size,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w300,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(g.x * size.width, g.y * size.height));
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => true;
}

class _GridOverlayPainter extends CustomPainter {
  final double time;
  _GridOverlayPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

    // Horizontal lines with very low opacity
    for (double y = 0; y < size.height; y += 60) {
      final alpha = 0.03 + 0.02 * math.sin(time * 0.3 + y * 0.01);
      paint.color = const Color(0xFF00E5FF).withOpacity(alpha);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridOverlayPainter old) => true;
}
