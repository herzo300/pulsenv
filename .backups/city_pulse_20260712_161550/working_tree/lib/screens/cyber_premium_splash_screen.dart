import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/pulse_colors.dart';

class CyberPremiumSplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const CyberPremiumSplashScreen({super.key, this.onComplete});

  @override
  State<CyberPremiumSplashScreen> createState() => _CyberPremiumSplashScreenState();
}

class _CyberPremiumSplashScreenState extends State<CyberPremiumSplashScreen> with TickerProviderStateMixin {
  late final AnimationController _bgController; // Controls fog & grid
  late final AnimationController _logoController; // Controls VIP logo pulsing/scaling
  late final AnimationController _glitchController; // Controls glitch effects
  final AudioPlayer _audioPlayer = AudioPlayer();
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _playPremiumSound();

    // End splash after 4.5 seconds
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) {
        if (widget.onComplete != null) {
          widget.onComplete!();
        } else {
          context.go('/map');
        }
      }
    });
  }

  Future<void> _playPremiumSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/menu_welcome.mp3'), volume: 0.8);
    } catch (e) {
      debugPrint("Failed to play splash sound: $e");
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _glitchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030308),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Deep Nebula Background & Fog
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return CustomPaint(
                painter: _FogPainter(
                  progress: _bgController.value,
                  randomSeed: 42,
                ),
              );
            },
          ),

          // Layer 2: 3D Cyber Perspective Grid
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return CustomPaint(
                painter: _CyberGridPainter(progress: _bgController.value),
              );
            },
          ),

          // Layer 3: Scanner Laser Lines
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return Positioned(
                top: MediaQuery.of(context).size.height * _bgController.value,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F0FF).withOpacity(0.8),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFF00F0FF),
                        Color(0xFFFF007F),
                        Color(0xFF00F0FF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Layer 4: Main Cyber VIP HUD & Logo
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_logoController, _glitchController]),
              builder: (context, child) {
                final scale = 0.95 + (_logoController.value * 0.08);
                final glitchVal = _glitchController.value;
                final isGlitching = _random.nextDouble() > 0.85;
                final double glitchX = isGlitching ? (_random.nextDouble() - 0.5) * 15 : 0;
                final double glitchY = isGlitching ? (_random.nextDouble() - 0.5) * 8 : 0;

                return Transform.translate(
                  offset: Offset(glitchX, glitchY),
                  child: Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Holographic VIP Rings
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer rotating HUD Ring
                            Transform.rotate(
                              angle: _bgController.value * 2 * math.pi,
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00F0FF).withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(
                                    value: 0.75,
                                    strokeWidth: 1.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      const Color(0xFFFF007F).withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Inner pulsating glowing ring
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700).withOpacity(0.15 * _logoController.value),
                                    blurRadius: 30,
                                    spreadRadius: 10,
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFFFFD700).withOpacity(0.6),
                                  width: 2.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 75,
                                color: Color(0xFFFFD700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Premium Title Container
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF070714).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isGlitching ? const Color(0xFFFF007F) : const Color(0xFF00F0FF).withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F0FF).withOpacity(0.15),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'PREMIUM ACCESS INITIALIZED',
                                style: TextStyle(
                                  color: const Color(0xFFFFD700),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 5.0,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFFFFD700).withOpacity(0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'CITY PULSE • NEON',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'CYBERNETIC COGNITIVE SYSTEM',
                                style: TextStyle(
                                  color: const Color(0xFF00F0FF).withOpacity(0.7),
                                  fontSize: 9,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Layer 5: Foreground Fog passing in front of camera
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FogPainter(
                    progress: (_bgController.value + 0.5) % 1.0,
                    randomSeed: 99,
                    isForeground: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  final double progress;
  final int randomSeed;
  final bool isForeground;

  _FogPainter({
    required this.progress,
    required this.randomSeed,
    this.isForeground = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final double w = size.width;
    final double h = size.height;

    if (!isForeground) {
      final double offset1 = progress * w;
      paint.shader = RadialGradient(
        colors: [
          const Color(0xFF1E003A).withOpacity(0.45),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset((offset1) % (w * 1.5) - (w * 0.25), h * 0.3),
        radius: math.max(w * 0.7, 0.01),
      ));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

      final double offset2 = (progress * 1.3 * w);
      paint.shader = RadialGradient(
        colors: [
          const Color(0xFF002244).withOpacity(0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(w * 1.25 - (offset2 % (w * 1.5)), h * 0.75),
        radius: math.max(w * 0.6, 0.01),
      ));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
    } else {
      final double offset3 = progress * 1.7 * w;
      paint.shader = RadialGradient(
        colors: [
          const Color(0xFF00F0FF).withOpacity(0.08),
          const Color(0xFFFF007F).withOpacity(0.04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset((offset3) % (w * 1.6) - (w * 0.3), h * 0.5),
        radius: math.max(w * 0.45, 0.01),
      ));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FogPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CyberGridPainter extends CustomPainter {
  final double progress;

  _CyberGridPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double w = size.width;
    final double h = size.height;
    final double horizon = h * 0.55;

    final int linesCount = 18;
    for (int i = 0; i <= linesCount; i++) {
      final double xStart = w * 0.5;
      final double yStart = horizon;
      final double t = i / linesCount;
      final double xEnd = w * -0.5 + (w * 2.0 * t);
      final double yEnd = h;

      canvas.drawLine(Offset(xStart, yStart), Offset(xEnd, yEnd), paint);
    }

    final int horizontalLines = 10;
    for (int i = 0; i < horizontalLines; i++) {
      final double normPos = (i + progress) / horizontalLines;
      final double ratio = math.pow(normPos, 2.5).toDouble();
      final double y = horizon + (h - horizon) * ratio;
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
