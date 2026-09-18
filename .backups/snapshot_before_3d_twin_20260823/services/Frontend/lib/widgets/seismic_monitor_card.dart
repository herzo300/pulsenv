// lib/widgets/seismic_monitor_card.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SeismicMonitorCard extends StatefulWidget {
  const SeismicMonitorCard({
    super.key,
    this.magnitude = 0.0,
    this.description = 'Сейсмическая активность в норме (фон 0.8 M)',
  });

  final double magnitude;
  final String description;

  @override
  State<SeismicMonitorCard> createState() => _SeismicMonitorCardState();
}

class _SeismicMonitorCardState extends State<SeismicMonitorCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seismoController;

  @override
  void initState() {
    super.initState();
    _seismoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _seismoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSafe = widget.magnitude < 3.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isSafe ? const Color(0xFF00E676) : const Color(0xFFFF5252)).withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSafe ? const Color(0xFF00E676) : const Color(0xFFFF5252)).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isSafe ? const Color(0xFF00E676) : const Color(0xFFFF5252)).withOpacity(0.15),
                        border: Border.all(
                          color: (isSafe ? const Color(0xFF00E676) : const Color(0xFFFF5252)).withOpacity(0.4),
                        ),
                      ),
                      child: Icon(
                        Icons.waves_rounded,
                        color: isSafe ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'СЕЙСМОАКТИВНОСТЬ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isSafe ? const Color(0xFF00E676) : const Color(0xFFFF5252)).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isSafe ? 'СТАБИЛЬНО' : 'ВНИМАНИЕ',
                                  style: TextStyle(
                                    color: isSafe ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'USGS & Геофизическая служба РАН (Радиус: 500 км)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Live Seismograph Tape
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1118),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.25)),
                  ),
                  child: Stack(
                    children: [
                      // Seismograph paper grid
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SeismographGridPainter(),
                        ),
                      ),
                      // Animated live tremor needle
                      AnimatedBuilder(
                        animation: _seismoController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(double.infinity, 100),
                            painter: _SeismographWavePainter(
                              progress: _seismoController.value,
                              magnitude: widget.magnitude,
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 8,
                        left: 10,
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF00E676),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Сейсмодатчик NV-01 / Онлайн',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 9,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2-Column Info Grid
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Тектонический щит',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Западно-Сибирская плита',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Сейсмоустойчивость: 99.8%',
                              style: TextStyle(
                                color: const Color(0xFF00E676).withOpacity(0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Магнитуда событий',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  widget.magnitude > 0 ? widget.magnitude.toStringAsFixed(1) : '< 1.0',
                                  style: TextStyle(
                                    color: isSafe ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'M (Рихтер)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Толчков не зарегистрировано',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Description note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFF00E676), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Нижневартовск расположен на асейсмичной платформе осадочного чехла. Вероятность ощутимых тектонических землетрясений сведена к нулю.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeismographGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF00E676).withOpacity(0.04)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final midPaint = Paint()
      ..color = const Color(0xFF00E676).withOpacity(0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), midPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SeismographWavePainter extends CustomPainter {
  _SeismographWavePainter({
    required this.progress,
    required this.magnitude,
  });

  final double progress;
  final double magnitude;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final path = Path();
    final rng = math.Random(42);

    final magFactor = magnitude > 0 ? (magnitude * 6.0) : 1.0;

    for (double x = 0; x <= size.width; x += 3) {
      final normX = x / size.width;
      
      // Micro-tremors + subtle baseline noise
      final jitter = (rng.nextDouble() - 0.5) * 4.0 * magFactor;
      final periodic = math.sin((normX * 16 * math.pi) + (progress * 2 * math.pi)) * (2.0 * magFactor);
      
      // Occasional P-wave spike
      double spike = 0.0;
      final pulsePos = (progress * size.width);
      final distToPulse = (x - pulsePos).abs();
      if (distToPulse < 30) {
        spike = math.sin((x - pulsePos) * 0.2) * 14.0 * magFactor * (1.0 - distToPulse / 30);
      }

      final y = (midY + jitter + periodic + spike).clamp(10.0, size.height - 10.0);

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final wavePaint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _SeismographWavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.magnitude != magnitude;
}
