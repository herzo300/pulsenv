import 'dart:math' as math;
import 'package:flutter/material.dart';

enum TileWeather { clear, rain, snow, clouds }
enum TileTime { day, sunset, night }
enum TileCategory { pothole, trash, lighting, general }

class DynamicTileBackground extends StatelessWidget {
  final Widget child;
  final TileWeather weather;
  final TileTime timeOfDay;
  final TileCategory category;
  final double borderRadius;

  const DynamicTileBackground({
    super.key,
    required this.child,
    this.weather = TileWeather.clear,
    this.timeOfDay = TileTime.day,
    this.category = TileCategory.general,
    this.borderRadius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: _buildGradient(),
        boxShadow: _buildShadows(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Category texture accent
            if (category == TileCategory.pothole)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CrackedTexturePainter(),
                ),
              ),
            
            // Weather overlay effects
            if (weather == TileWeather.rain)
              Positioned.fill(
                child: CustomPaint(
                  painter: _RainDropsPainter(),
                ),
              ),

            if (timeOfDay == TileTime.night)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.2,
                      colors: [
                        const Color(0x3300F0FF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            child,
          ],
        ),
      ),
    );
  }

  LinearGradient _buildGradient() {
    if (timeOfDay == TileTime.night) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F172A), Color(0xFF020617)],
      );
    }
    if (weather == TileWeather.rain) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E1E2E), Color(0xFF181825)],
    );
  }

  List<BoxShadow> _buildShadows() {
    if (timeOfDay == TileTime.night) {
      return [
        BoxShadow(
          color: const Color(0xFF00F0FF).withOpacity(0.25),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

class _RainDropsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final rng = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + 10), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrackedTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.08)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(size.width * 0.8, 0), Offset(size.width * 0.6, size.height * 0.4), paint);
    canvas.drawLine(Offset(size.width * 0.6, size.height * 0.4), Offset(size.width * 0.9, size.height * 0.8), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
