import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/pulse_colors.dart';

/// Нейро-сплэш экран "Ядро Антигравити" (AI Core)
class AiCoreSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const AiCoreSplashScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<AiCoreSplashScreen> createState() => _AiCoreSplashScreenState();
}

class _AiCoreSplashScreenState extends State<AiCoreSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _masterController;
  late AnimationController _pulseController;
  late AnimationController _dataStreamController;

  late Animation<double> _coreFade;
  late Animation<double> _coreScale;
  late Animation<double> _titleFade;
  late Animation<double> _loaderWidth;

  @override
  void initState() {
    super.initState();

    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _dataStreamController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    _coreScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _coreFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeInOut),
      ),
    );

    _loaderWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _masterController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), widget.onComplete);
    });
  }

  @override
  void dispose() {
    _masterController.dispose();
    _pulseController.dispose();
    _dataStreamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    final primary = PulseColors.primary;
    final bg = PulseColors.background;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background Matrix / Data Stream
          AnimatedBuilder(
            animation: _dataStreamController,
            builder: (context, child) {
              return CustomPaint(
                painter: _DataStreamPainter(
                  progress: _dataStreamController.value,
                  color: primary.withOpacity(0.15),
                ),
                size: Size(mq.width, mq.height),
              );
            },
          ),
          
          // Core Engine
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_masterController, _pulseController]),
                builder: (context, _) {
                  final pulse = _pulseController.value;
                  return Opacity(
                    opacity: _coreFade.value,
                    child: Transform.scale(
                      scale: _coreScale.value + (pulse * 0.05),
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bg,
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.3 + (pulse * 0.3)),
                              blurRadius: 30 + (pulse * 20),
                              spreadRadius: 5 + (pulse * 10),
                            ),
                            BoxShadow(
                              color: primary.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: -2,
                            ),
                          ],
                          border: Border.all(
                            color: primary.withOpacity(0.8),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.rotate(
                                angle: _masterController.value * math.pi * 4,
                                child: Icon(
                                  Icons.data_usage_rounded,
                                  size: 80,
                                  color: primary.withOpacity(0.8),
                                ),
                              ),
                              Icon(
                                Icons.android_rounded,
                                size: 40,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 50),
              
              // Animated Title
              FadeTransition(
                opacity: _titleFade,
                child: Column(
                  children: [
                    Text(
                      'AI ENGINE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: primary,
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SOOBSHIO INTELLIGENCE',
                      style: TextStyle(
                        color: primary.withOpacity(0.8),
                        fontSize: 12,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 60),

              // Progress Bar
              AnimatedBuilder(
                animation: _loaderWidth,
                builder: (context, _) {
                  return Opacity(
                    opacity: _titleFade.value,
                    child: Container(
                      width: 200,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 200 * _loaderWidth.value,
                          height: 4,
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: primary,
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              AnimatedBuilder(
                animation: _masterController,
                builder: (context, _) {
                  return Opacity(
                    opacity: _titleFade.value,
                    child: Text(
                      _getLoadingText(_masterController.value),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLoadingText(double t) {
    if (t < 0.2) return "INITIALIZING CORE...";
    if (t < 0.4) return "CONNECTING NEURAL NETWORK...";
    if (t < 0.6) return "LOADING COMPUTER VISION...";
    if (t < 0.8) return "WAKING UP AGENTS...";
    return "SYSTEM ONLINE.";
  }
}

class _DataStreamPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DataStreamPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rand = math.Random(42); // Deterministic

    for (int i = 0; i < 40; i++) {
      final startX = rand.nextDouble() * size.width;
      final speed = 0.5 + rand.nextDouble();
      final length = 20 + rand.nextDouble() * 80;

      // Calculate falling Y using progress
      double y = (progress * size.height * speed * 3) + (rand.nextDouble() * size.height);
      y = y % (size.height + length) - length;

      canvas.drawLine(
        Offset(startX, y),
        Offset(startX, y + length),
        p..color = color.withOpacity((1 - (y / size.height)).clamp(0.0, 1.0) * rand.nextDouble()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DataStreamPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
