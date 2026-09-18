// lib/widgets/space_weather_moon_card.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SpaceWeatherMoonCard extends StatelessWidget {
  const SpaceWeatherMoonCard({
    super.key,
    this.moonPhase = 0.48,
    this.moonPhaseName = 'Растущая Луна',
    this.moonPhaseDesc = 'Период накопления сил и повышенной концентрации.',
    this.moonInfluencePct = 45.0,
    this.kpIndex = 2.0,
    this.solarFlare = 'B1.4',
    this.solarWindKmS = '395',
  });

  final double moonPhase;
  final String moonPhaseName;
  final String moonPhaseDesc;
  final double moonInfluencePct;
  final double kpIndex;
  final String solarFlare;
  final String solarWindKmS;

  @override
  Widget build(BuildContext context) {
    final illuminationPct = (math.sin(moonPhase * math.pi) * 100).round();
    final moonAgeDays = (moonPhase * 29.53).toStringAsFixed(1);

    Color kpColor;
    String kpStatus;
    if (kpIndex < 3.0) {
      kpColor = const Color(0xFF00E676);
      kpStatus = 'Спокойный';
    } else if (kpIndex < 5.0) {
      kpColor = const Color(0xFFFFD54F);
      kpStatus = 'Слабое возмущение';
    } else if (kpIndex < 7.0) {
      kpColor = const Color(0xFFFF9100);
      kpStatus = 'Магнитная буря (G1-G2)';
    } else {
      kpColor = const Color(0xFFFF5252);
      kpStatus = 'Сильный шторм (G3-G5)';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB388FF).withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB388FF).withOpacity(0.08),
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
                        color: const Color(0xFFB388FF).withOpacity(0.15),
                        border: Border.all(color: const Color(0xFFB388FF).withOpacity(0.4)),
                      ),
                      child: const Icon(
                        Icons.nights_stay_rounded,
                        color: Color(0xFFB388FF),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ЛУНА И КОСМИЧЕСКАЯ ПОГОДА',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NOAA SWPC / NASA SDO / Лунный календарь',
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
                const SizedBox(height: 20),

                // Moon Visual and Phase Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      // Moon Sphere
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB388FF).withOpacity(0.25),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _MoonPainter(phase: moonPhase),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              moonPhaseName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Освещенность: $illuminationPct% • Возраст: $moonAgeDays дн.',
                              style: TextStyle(
                                color: const Color(0xFFB388FF).withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              moonPhaseDesc,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 10.5,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Space Weather Stats Grid (Kp Index, Solar Wind, Flare)
                Row(
                  children: [
                    // Kp Index
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kpColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Геомагнитный Kp',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  kpIndex.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: kpColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '/ 9',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              kpStatus,
                              style: TextStyle(
                                color: kpColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Solar Wind
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Солнечный ветер',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  solarWindKmS,
                                  style: const TextStyle(
                                    color: Color(0xFF80D8FF),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'км/с',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Норма: 350–450',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Solar Flare
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Вспышки (X-Ray)',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              solarFlare,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Фон GOES-16',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Aurora probability
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          kpIndex >= 4.0
                              ? 'Полярное сияние: высокая вероятность наблюдения на широте Нижневартовска (60.9° N).'
                              : 'Полярное сияние: вероятность в Нижневартовске низкая (Kp < 4.0). Магнитосфера спокойна.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 10.5,
                            height: 1.3,
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

class _MoonPainter extends CustomPainter {
  _MoonPainter({required this.phase});
  final double phase; // 0.0 to 1.0 (0=New, 0.25=First Q, 0.5=Full, 0.75=Last Q)

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dark base moon circle
    final darkPaint = Paint()
      ..color = const Color(0xFF1E2433)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, darkPaint);

    // Subtle craters
    final craterPaint = Paint()
      ..color = const Color(0xFF141A26)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 12, center.dy - 10), 8, craterPaint);
    canvas.drawCircle(Offset(center.dx + 10, center.dy + 14), 10, craterPaint);
    canvas.drawCircle(Offset(center.dx - 8, center.dy + 16), 6, craterPaint);
    canvas.drawCircle(Offset(center.dx + 16, center.dy - 8), 7, craterPaint);

    // Illuminated part
    final lightPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFE0E7FF), Color(0xFFC7D2FE)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final path = Path();
    if (phase <= 0.5) {
      // Waxing (right side lit)
      path.addArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, math.pi);
      final ovalWidth = (1.0 - 2 * phase) * radius;
      path.addArc(
        Rect.fromCenter(center: center, width: ovalWidth.abs() * 2, height: radius * 2),
        math.pi / 2,
        phase < 0.25 ? math.pi : -math.pi,
      );
    } else {
      // Waning (left side lit)
      path.addArc(Rect.fromCircle(center: center, radius: radius), math.pi / 2, math.pi);
      final ovalWidth = (2 * phase - 1.0) * radius;
      path.addArc(
        Rect.fromCenter(center: center, width: ovalWidth.abs() * 2, height: radius * 2),
        -math.pi / 2,
        phase < 0.75 ? math.pi : -math.pi,
      );
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawPath(path, lightPaint);
    canvas.restore();

    // Soft border ring
    final borderPaint = Paint()
      ..color = const Color(0xFFB388FF).withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _MoonPainter oldDelegate) => oldDelegate.phase != phase;
}
