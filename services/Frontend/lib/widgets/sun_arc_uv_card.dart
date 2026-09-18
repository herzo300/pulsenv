import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/city_weather_service.dart';
import 'app_ui.dart';

class SunArcPainter extends CustomPainter {
  final double progress; // 0.0 (sunrise) to 1.0 (sunset)
  final bool isDay;

  SunArcPainter({required this.progress, required this.isDay});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 15);
    final radius = math.min(size.width / 2 - 25, size.height - 25);

    // 1. Dotted background arc
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, math.pi, math.pi, false, bgPaint);

    // 2. Active gradient glow arc
    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFF8C00),
          Color(0xFFFFD700),
          Color(0xFF00E5FF),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final clampedProgress = progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, math.pi, math.pi * clampedProgress, false, activePaint);

    // 3. Horizon baseline
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - radius - 15, center.dy),
      Offset(center.dx + radius + 15, center.dy),
      linePaint,
    );

    // 4. Sun position math
    final angle = math.pi + (math.pi * clampedProgress);
    final sunX = center.dx + radius * math.cos(angle);
    final sunY = center.dy + radius * math.sin(angle);
    final sunCenter = Offset(sunX, sunY);

    if (isDay) {
      // --- SUN RENDERING (Top-grade Liquid Solar Graphics) ---
      
      // Outer atmospheric glow aura
      final outerAura = Paint()
        ..color = const Color(0xFFFF9500).withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      canvas.drawCircle(sunCenter, 24, outerAura);

      // Inner intense corona glow
      final coronaGlow = Paint()
        ..color = const Color(0xFFFFCC00).withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(sunCenter, 14, coronaGlow);

      // Rotating Solar Rays (8 rays)
      final rayPaint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(0.7)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      
      for (int i = 0; i < 8; i++) {
        final rayAngle = (i * math.pi / 4) + (progress * math.pi * 2);
        final innerRay = Offset(
          sunX + 11 * math.cos(rayAngle),
          sunY + 11 * math.sin(rayAngle),
        );
        final outerRay = Offset(
          sunX + 17 * math.cos(rayAngle),
          sunY + 17 * math.sin(rayAngle),
        );
        canvas.drawLine(innerRay, outerRay, rayPaint);
      }

      // Core Gradient Disc
      final corePaint = Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFEA79),
            Color(0xFFFF9500),
          ],
          stops: [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: 9));
      canvas.drawCircle(sunCenter, 9, corePaint);

      // Specular highlight sparkle
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(sunX - 2.5, sunY - 2.5), 2.5, highlightPaint);
    } else {
      // --- MOON RENDERING ---
      final moonAura = Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(sunCenter, 16, moonAura);

      final moonPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(sunCenter, 9, moonPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SunArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDay != isDay;
}

class SunArcUvCard extends StatelessWidget {
  final CityWeatherSnapshot snapshot;

  const SunArcUvCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final progress = snapshot.sunProgress.clamp(0.05, 0.95);
    final uv = snapshot.uvIndex ?? 2.5;

    return AppTouchBounce(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.15),
            blurRadius: 16,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sun Arc Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ПОЛОЖЕНИЕ СОЛНЦА И УФ-ИНДЕКС',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: Text(
                  'УФ: ${uv.toStringAsFixed(1)}',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Semicircular Sun Arc Canvas
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: SunArcPainter(
                progress: progress,
                isDay: snapshot.isDay,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Восход', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(snapshot.sunriseTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Закат', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(snapshot.sunsetTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // UV Recommendation Banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    snapshot.uvRecommendation,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
