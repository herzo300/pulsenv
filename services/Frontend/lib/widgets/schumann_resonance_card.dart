// lib/widgets/schumann_resonance_card.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SchumannResonanceCard extends StatefulWidget {
  const SchumannResonanceCard({
    super.key,
    this.freqHz = 7.83,
    this.ampPt = 1.3,
    this.solarFlare = 'B1.4',
  });

  final double freqHz;
  final double ampPt;
  final String solarFlare;

  @override
  State<SchumannResonanceCard> createState() => _SchumannResonanceCardState();
}

class _SchumannResonanceCardState extends State<SchumannResonanceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final harmonics = [
      (1, widget.freqHz, 1.0),
      (2, widget.freqHz * 1.82, 0.65),
      (3, widget.freqHz * 2.65, 0.42),
      (4, widget.freqHz * 3.48, 0.28),
      (5, widget.freqHz * 4.31, 0.18),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.08),
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
                        color: const Color(0xFF00E5FF).withOpacity(0.15),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Color(0xFF00E5FF),
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
                                'РЕЗОНАНС ШУМАНА',
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
                                  color: const Color(0xFF00E5FF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'LIVE ЭМП',
                                  style: TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Глобальные электромагнитные волны Земли',
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

                // Main Stats Hero
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
                              'Базовая частота (1-я)',
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
                                  widget.freqHz.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Гц',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Эталон: 7.83 Гц (Альфа-ритм)',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
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
                              'Амплитуда сигнала',
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
                                  widget.ampPt.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'пТл',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Вспышечная активность: ${widget.solarFlare}',
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
                const SizedBox(height: 18),

                // Live Oscilloscope Wave
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF070E1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.25)),
                  ),
                  child: Stack(
                    children: [
                      // Grid background
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _OscilloscopeGridPainter(),
                        ),
                      ),
                      // Animated live harmonic wave
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(double.infinity, 110),
                            painter: _SchumannWavePainter(
                              progress: _animController.value,
                              freq: widget.freqHz,
                              amp: widget.ampPt,
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 8,
                        right: 10,
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
                            const SizedBox(width: 4),
                            Text(
                              'Ионосфера / 60 FPS',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
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
                const SizedBox(height: 16),

                // Harmonics Bar Breakdown
                const Text(
                  'Спектральные моды (гармоники Шумана)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: harmonics.map((h) {
                    final isBase = h.$1 == 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isBase
                            ? const Color(0xFF00E5FF).withOpacity(0.2)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isBase
                              ? const Color(0xFF00E5FF).withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${h.$1}-я мода',
                            style: TextStyle(
                              color: isBase ? const Color(0xFF00E5FF) : Colors.white60,
                              fontSize: 9,
                              fontWeight: isBase ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${h.$2.toStringAsFixed(1)} Гц',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Brainwave sync indicator
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_rounded, color: Color(0xFFB388FF), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Синхронизация с биоритмами человека',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Частота 7.83 Гц совпадает с альфа-ритмом головного мозга (7–13 Гц), способствуя медитации, восстановлению сил и креативному мышлению.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 10,
                                height: 1.3,
                              ),
                            ),
                          ],
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

class _OscilloscopeGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Center line
    final centerPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SchumannWavePainter extends CustomPainter {
  _SchumannWavePainter({
    required this.progress,
    required this.freq,
    required this.amp,
  });

  final double progress;
  final double freq;
  final double amp;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final path = Path();
    final glowPath = Path();

    final waveScale = (amp / 1.5).clamp(0.5, 2.5);

    for (double x = 0; x <= size.width; x += 2) {
      final normX = x / size.width;
      
      // Superposition of 1st, 2nd, and 3rd harmonics
      final wave1 = math.sin((normX * 4 * math.pi) + (progress * 2 * math.pi)) * 22.0 * waveScale;
      final wave2 = math.sin((normX * 8 * math.pi) + (progress * 4 * math.pi)) * 8.0 * waveScale;
      final wave3 = math.sin((normX * 12 * math.pi) + (progress * 6 * math.pi)) * 3.5 * waveScale;

      final y = midY + (wave1 + wave2 + wave3);

      if (x == 0) {
        path.moveTo(x, y);
        glowPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        glowPath.lineTo(x, y);
      }
    }

    // Outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.3)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(glowPath, glowPaint);

    // Main line
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00E5FF), Color(0xFF76FF03), Color(0xFF00E5FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SchumannWavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.freq != freq;
}
