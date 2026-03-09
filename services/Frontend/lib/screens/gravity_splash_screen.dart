import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import 'map_screen.dart';
import '../services/sound_service.dart';

/// Splash screen "Digital Gravity".
/// - Generative energy streams converge into the central Pulse mark.
/// - Floating glyphs create a zero-gravity data field behind the UI.
/// - A deep dark canvas and scanline keep the existing cinematic tone.
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
  static const Color _violet = Color(0xFF7C4DFF);

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
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.forward ||
            status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
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
    })
      ..start();

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

            Positioned.fill(
              child: CustomPaint(
                painter: _EnergyConvergencePainter(time: _time),
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
                              ? 0.6 +
                                  math.sin(_pulseController.value *
                                          math.pi *
                                          2) *
                                      0.4
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
                                '\u0426\u0418\u0424\u0420\u041E\u0412\u0410\u042F',
                                style: GoogleFonts.orbitron(
                                  color: _cyan.withOpacity(0.6),
                                  fontSize: 12,
                                  letterSpacing: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [_cyan, _teal, _blue, _violet],
                                  stops: [0.0, 0.35, 0.7, 1.0],
                                ).createShader(bounds),
                                child: Text(
                                  '\u041D\u0415\u0412\u0415\u0421\u041E\u041C\u041E\u0421\u0422\u042C',
                                  style: GoogleFonts.orbitron(
                                    color: Colors.white,
                                    fontSize: 29,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 5.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '\u0413\u043E\u0440\u043E\u0434\u0441\u043A\u0438\u0435 '
                                '\u0441\u0438\u0433\u043D\u0430\u043B\u044B '
                                '\u0441\u0445\u043E\u0434\u044F\u0442\u0441\u044F '
                                '\u0432 \u0435\u0434\u0438\u043D\u044B\u0439 '
                                '\u0446\u0438\u0444\u0440\u043E\u0432\u043E\u0439 '
                                '\u043F\u0443\u043B\u044C\u0441',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.68),
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '\u041F\u0423\u041B\u042C\u0421 \u00B7 '
                                '\u041D\u0418\u0416\u041D\u0415\u0412\u0410\u0420\u0422\u041E\u0412\u0421\u041A',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 11,
                                  letterSpacing: 3.2,
                                  fontWeight: FontWeight.w600,
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
                                ? math.sin(
                                        _pulseController.value * math.pi * 2) *
                                    0.1
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
                                    color:
                                        _cyan.withOpacity(_ready ? 0.8 : 0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: _ready
                                      ? [
                                          BoxShadow(
                                            color: _cyan
                                                .withOpacity(0.4 + heartbeat),
                                            blurRadius: 25,
                                            spreadRadius: 3,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Icon(
                                    _ready
                                        ? Icons.fingerprint
                                        : Icons.hourglass_empty_rounded,
                                    color:
                                        _cyan.withOpacity(_ready ? 1.0 : 0.4),
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
                            ? Text(
                                '\u0410\u041A\u0422\u0418\u0412\u0418\u0420\u041E\u0412\u0410\u0422\u042C '
                                '\u0421\u0418\u0421\u0422\u0415\u041C\u0423',
                                key: const ValueKey('ready'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  letterSpacing: 3.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : Text(
                                '\u041A\u0410\u041B\u0418\u0411\u0420\u041E\u0412\u041A\u0410 '
                                '\u0421\u0415\u041D\u0421\u041E\u0420\u041E\u0412...',
                                key: const ValueKey('loading'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: _cyan.withOpacity(0.5),
                                  fontSize: 12,
                                  letterSpacing: 3.0,
                                  fontWeight: FontWeight.w500,
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

// ==========================================
// Floating Glyph data
// ==========================================

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
    const chars =
        '01\u0410\u0411\u0412\u2211\u222B\u03BB\u03C0\u0394\u03A9\u2248\u2022\u25E6\u221E\u00D7\u00F7\u24C5\u24CA\u24C1\u24C8';
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

// ==========================================
// Painters
// ==========================================

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
      final color =
          const Color(0xFF00E5FF).withOpacity(alphaOsc.clamp(0.01, 0.25));

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

class _EnergyConvergencePainter extends CustomPainter {
  final double time;
  _EnergyConvergencePainter({required this.time});

  static const List<Color> _streamPalette = [
    Color(0xFF00E5FF),
    Color(0xFF1DE9B6),
    Color(0xFF448AFF),
    Color(0xFF7C4DFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.36);
    final radius = size.shortestSide * 0.56;
    final haloPulse = 0.88 + math.sin(time * 0.9) * 0.12;

    final halo = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius * 0.75,
        [
          const Color(0xFF00E5FF).withOpacity(0.12 * haloPulse),
          const Color(0xFF448AFF).withOpacity(0.08 * haloPulse),
          Colors.transparent,
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(center, radius * 0.75, halo);

    for (int i = 0; i < 18; i++) {
      final phase = i / 18;
      final startAngle = phase * math.pi * 2 + time * 0.12;
      final startRadius = radius * (0.9 + 0.18 * math.sin(time * 0.35 + i));
      final start = Offset(
        center.dx + math.cos(startAngle) * startRadius,
        center.dy + math.sin(startAngle) * startRadius * 0.82,
      );

      final bend = 0.2 + 0.08 * math.sin(time * 0.7 + i);
      final controlA = Offset.lerp(start, center, 0.28)! +
          Offset(
            math.cos(startAngle + math.pi / 2) * size.width * bend,
            math.sin(startAngle + math.pi / 2) * size.height * bend * 0.38,
          );
      final controlB = Offset.lerp(start, center, 0.72)! +
          Offset(
            math.cos(startAngle - math.pi / 2) * size.width * bend * 0.18,
            math.sin(startAngle - math.pi / 2) * size.height * bend * 0.12,
          );

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          controlA.dx,
          controlA.dy,
          controlB.dx,
          controlB.dy,
          center.dx,
          center.dy,
        );

      final streamOpacity =
          (0.22 + 0.06 * math.sin(time * 1.1 + i)).clamp(0.12, 0.32);
      final streamColor =
          _streamPalette[i % _streamPalette.length].withOpacity(streamOpacity);

      final glowPaint = Paint()
        ..color = streamColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12);
      canvas.drawPath(path, glowPaint);

      final linePaint = Paint()
        ..shader = ui.Gradient.linear(
          start,
          center,
          [
            streamColor.withOpacity(0.0),
            streamColor.withOpacity(0.7),
            const Color(0xFFECFEFF).withOpacity(0.9),
          ],
          const [0.0, 0.5, 1.0],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25 + (i % 3) * 0.45
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);

      final particleT = (time * (0.19 + (i % 4) * 0.025) + phase) % 1.0;
      final particle =
          _cubicPoint(start, controlA, controlB, center, particleT);
      final particlePaint = Paint()
        ..color = const Color(0xFFECFEFF).withOpacity(0.9)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
      canvas.drawCircle(particle, 2.8 + (i % 2) * 1.1, particlePaint);
    }

    for (int ring = 0; ring < 3; ring++) {
      final progress = ((time * 0.16) + ring * 0.26) % 1.0;
      final ringRadius = ui.lerpDouble(radius * 0.08, radius * 0.28, progress)!;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF00E5FF).withOpacity((1 - progress) * 0.18);
      canvas.drawCircle(center, ringRadius, ringPaint);
    }
  }

  Offset _cubicPoint(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
    final mt = 1 - t;
    final a = mt * mt * mt;
    final b = 3 * mt * mt * t;
    final c = 3 * mt * t * t;
    final d = t * t * t;
    return Offset(
      (a * p0.dx) + (b * p1.dx) + (c * p2.dx) + (d * p3.dx),
      (a * p0.dy) + (b * p1.dy) + (c * p2.dy) + (d * p3.dy),
    );
  }

  @override
  bool shouldRepaint(covariant _EnergyConvergencePainter old) => true;
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
