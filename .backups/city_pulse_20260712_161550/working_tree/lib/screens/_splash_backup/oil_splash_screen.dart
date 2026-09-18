import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_router.dart';
import '../services/sound_service.dart';

/// Oil-themed splash screen "Siberian Gold" (Самотлор).
/// - Pulsating liquid black-gold droplet CustomPainter.
/// - Concentric seismic waves representing the city energy pulses.
/// - Ambient rising micro-bubbles and gold neon loading bar.
class OilSplashScreen extends StatefulWidget {
  const OilSplashScreen({super.key});

  @override
  State<OilSplashScreen> createState() => _OilSplashScreenState();
}

class _OilSplashScreenState extends State<OilSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _loadingController;
  late AnimationController _fadeController;
  
  final List<_OilBubble> _bubbles = [];
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
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Populate rising oil bubbles
    for (int i = 0; i < 35; i++) {
      _bubbles.add(_OilBubble.random(_rng));
    }

    // Periodic time update for CustomPainter animations
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (mounted) {
        setState(() {
          _time += 0.016;
          // Update bubble positions
          for (final b in _bubbles) {
            b.y -= b.speed;
            b.x += math.sin(_time * b.wobbleSpeed) * 0.2;
            if (b.y < -20) {
              b.y = 800 + _rng.nextDouble() * 100;
              b.x = _rng.nextDouble() * 400;
            }
          }
        });
      }
    });

    _startLoading();
    SoundService().playSplashDesign('oil'); // Voiceover for Oil splash screen
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

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      unawaited(AppRouter.navigateAfterSplash(context));
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
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF020306), // Ultra dark backdrop
      body: Stack(
        children: [
          // 1. Ambient Golden Radial Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    const Color(0xFFC59B27).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. Rising Micro-Bubbles of Black Gold
          Positioned.fill(
            child: CustomPaint(
              painter: _OilBubblesPainter(_bubbles),
            ),
          ),

          // 3. Central Pulsing Drop & Expanding Seismic Rings
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: _OilDropPainter(
                      pulse: _pulseController.value,
                      time: _time,
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. Logo, City Tag, and Progress Bar
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CITY PULSE',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'САМОТЛОР • СИБИРЬ',
                    style: GoogleFonts.roboto(
                      color: const Color(0xFFD4AF37), // Metallic Gold
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  
                  // Gold Neon Progress Bar
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
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
                              height: 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37).withOpacity(0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B7320),
                                    Color(0xFFD4AF37),
                                    Color(0xFFFFF6D6),
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
          
          // Shutter Fade Overlay on exit
          if (_exiting)
            Positioned.fill(
              child: FadeTransition(
                opacity: _fadeController,
                child: Container(
                  color: const Color(0xFF020306),
                ),
              ),
            ),
        ],
      ),
    );
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
  final double radius;
  final double speed;
  final double wobbleSpeed;
  final double opacity;

  factory _OilBubble.random(math.Random rng) {
    return _OilBubble(
      x: rng.nextDouble() * 380,
      y: rng.nextDouble() * 800,
      radius: 1.5 + rng.nextDouble() * 3.5,
      speed: 0.4 + rng.nextDouble() * 1.1,
      wobbleSpeed: 1.0 + rng.nextDouble() * 2.0,
      opacity: 0.15 + rng.nextDouble() * 0.35,
    );
  }
}

class _OilBubblesPainter extends CustomPainter {
  final List<_OilBubble> bubbles;
  _OilBubblesPainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final b in bubbles) {
      paint.color = const Color(0xFFD4AF37).withOpacity(b.opacity);
      canvas.drawCircle(Offset(b.x, b.y), b.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _OilDropPainter extends CustomPainter {
  final double pulse;
  final double time;

  _OilDropPainter({required this.pulse, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 1. Draw Expanding Seismic gold rings (Pulse)
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
      
    for (int i = 0; i < 3; i++) {
      final ringProgress = (pulse + i / 3.0) % 1.0;
      final radius = 50.0 + ringProgress * 75.0;
      final opacity = (1.0 - ringProgress) * 0.28;
      
      ringPaint.color = const Color(0xFFD4AF37).withOpacity(opacity);
      canvas.drawCircle(center, radius, ringPaint);
    }

    // 2. Draw outer ambient golden particles swirling around the drop
    final swirlPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = time * 0.8 + (i * math.pi / 4);
      final dist = 48.0 + math.sin(time * 2.0 + i) * 6.0;
      final sx = center.dx + math.cos(angle) * dist;
      final sy = center.dy + math.sin(angle) * dist;
      final r = 2.0 + math.sin(time + i).abs() * 1.5;
      
      swirlPaint.color = const Color(0xFFFFF0B8).withOpacity(0.45);
      canvas.drawCircle(Offset(sx, sy), r, swirlPaint);
    }

    // 3. Draw liquid oil drop (Bezier morphing path)
    final path = Path();
    
    // We calculate drop radius and construct points deformed by sine waves to look liquid
    final baseRadius = 38.0 + pulse * 4.0;
    const numPoints = 8;
    final points = <Offset>[];
    
    for (int i = 0; i < numPoints; i++) {
      final angle = i * 2 * math.pi / numPoints;
      // Add liquid wobbling deformation
      final wave = math.sin(time * 3.0 + angle * 2.5) * 3.5;
      final r = baseRadius + wave;
      
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      points.add(Offset(x, y));
    }
    
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < numPoints; i++) {
      final nextIdx = (i + 1) % numPoints;
      final xc = (points[i].dx + points[nextIdx].dx) / 2;
      final yc = (points[i].dy + points[nextIdx].dy) / 2;
      path.quadraticBezierTo(points[i].dx, points[i].dy, xc, yc);
    }
    path.close();

    // 4. Fill drop with a high-end radial liquid gold gradient (gold core, black-gold edges)
    final dropGradient = ui.Gradient.radial(
      center,
      baseRadius * 1.2,
      [
        const Color(0xFFFFF6D6), // Shiny golden core
        const Color(0xFFD4AF37), // Gold body
        const Color(0xFF2C240E), // Dark golden transition
        const Color(0xFF050503), // Liquid black gold edge
      ],
      [0.0, 0.4, 0.75, 1.0],
    );

    final dropPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = dropGradient;
      
    // Draw drop shadow
    canvas.drawShadow(path, const Color(0xFFD4AF37).withOpacity(0.3), 12, true);
    
    canvas.drawPath(path, dropPaint);
    
    // Draw inner glossy highlight to make it look like a 3D liquid droplet
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    // A small crescent highlight in the top-left portion of the drop
    canvas.drawOval(
      Rect.fromLTWH(center.dx - 18, center.dy - 22, 10, 6),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
