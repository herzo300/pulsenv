import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'map_screen.dart';

/// Новый стильный сплэш-экран «Cyber City Pulse»
class CyberSplashScreen extends StatefulWidget {
  const CyberSplashScreen({super.key});

  @override
  State<CyberSplashScreen> createState() => _CyberSplashScreenState();
}

class _CyberSplashScreenState extends State<CyberSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Ticker _ticker;

  final List<_RingData> _rings = [];
  double _time = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(seconds: 1));

    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
        _updateRings(elapsed.inMilliseconds / 1000.0);
      });
    })..start();

    _initRings();
    _simulateLoading();
  }

  void _initRings() {
    final rnd = math.Random();
    for (int i = 0; i < 5; i++) {
      _rings.add(_RingData(
        baseRadius: 60.0 + i * 40.0,
        speed: (rnd.nextDouble() - 0.5) * 2.0,
        phase: rnd.nextDouble() * math.pi * 2,
        color: _getRingColor(i),
        segments: 8 + rnd.nextInt(12),
        width: 1.0 + rnd.nextDouble() * 3.0,
      ));
    }
  }

  Color _getRingColor(int index) {
    const colors = [
      Color(0xFF00E5FF),
      Color(0xFF1DE9B6),
      Color(0xFF448AFF),
      Color(0xFF00E676),
      Color(0xFFB388FF),
    ];
    return colors[index % colors.length];
  }

  void _updateRings(double time) {
    for (var r in _rings) {
      r.rotation = time * r.speed + r.phase;
    }
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _ready = true);
    _fadeController.forward();
  }

  void _onEnter() {
    if (!_ready) return;
    HapticFeedback.heavyImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, anim, secAnim) => const MapScreen(),
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B14),
      body: Stack(
        children: [
          // Background Rings
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberPulsePainter(rings: _rings, time: _time),
            ),
          ),

          // Central Button
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: _onEnter,
              child: MouseRegion(
                cursor: _ready
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = _ready
                        ? 1.0 + math.sin(_pulseController.value * math.pi * 2) * 0.05
                        : 0.8;
                    final outlineOpacity = _ready ? 0.8 : 0.3;

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00E5FF).withAlpha(30),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withOpacity(outlineOpacity),
                            width: 2,
                          ),
                          boxShadow: [
                            if (_ready)
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius:
                                    math.sin(_pulseController.value * math.pi) * 10,
                              ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00E5FF),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Icon(
                              _ready ? Icons.power_settings_new : Icons.hourglass_empty,
                              color: const Color(0xFF050B14),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Text UI
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                const SizedBox(height: 160),
                const Spacer(),
                const Text(
                  'ИНИЦИАЛИЗАЦИЯ',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 12,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ПУЛЬС ДАННЫХ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: AnimatedBuilder(
                    animation: _fadeController,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _ready ? _fadeController.value : 0.5,
                        child: Text(
                          _ready ? 'НАЖМИТЕ ДЛЯ ВХОДА' : 'ПОДКЛЮЧЕНИЕ К ЯДРУ...',
                          style: TextStyle(
                            color: _ready ? Colors.white : const Color(0xFF00E5FF),
                            fontSize: 12,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingData {
  final double baseRadius;
  final double speed;
  final double phase;
  final Color color;
  final int segments;
  final double width;
  double rotation = 0;

  _RingData({
    required this.baseRadius,
    required this.speed,
    required this.phase,
    required this.color,
    required this.segments,
    required this.width,
  });
}

class _CyberPulsePainter extends CustomPainter {
  final List<_RingData> rings;
  final double time;

  _CyberPulsePainter({required this.rings, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background glow
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        size.width / 2,
        [
          const Color(0xFF00E5FF).withOpacity(0.15),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(center, size.width / 1.5, glowPaint);

    for (var r in rings) {
      final dynRadius = r.baseRadius + math.sin(time * 2 + r.phase) * 5;
      final paint = Paint()
        ..color = r.color.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width;

      final gap = (math.pi * 2) / r.segments;
      for (int i = 0; i < r.segments; i++) {
        // Leave some empty space to look like dashed/segmented sci-fi rings
        if (i % 3 == 0) continue;
        final startAngle = r.rotation + i * gap;
        final sweepAngle = gap * 0.7;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: dynRadius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyberPulsePainter old) => true;
}
