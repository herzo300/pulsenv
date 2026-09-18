import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Высокопроизводительная анимированная кнопка-капля нефти (Samotlor Gold Oil Drop FAB)
/// со встроенной изоляцией перерисовок через ValueNotifier.
class MapOilDropFab extends StatelessWidget {
  final ValueNotifier<bool> isMapMovingNotifier;
  final AnimationController fabPulseController;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String activeCityId;
  final bool isNightMode;
  final int speechCount;

  const MapOilDropFab({
    super.key,
    required this.isMapMovingNotifier,
    required this.fabPulseController,
    required this.onTap,
    required this.onLongPress,
    required this.activeCityId,
    required this.isNightMode,
    this.speechCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFFFB300);
    const darkOil = Color(0xFF1A1208);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: fabPulseController,
        builder: (context, child) {
          final pulse = fabPulseController.value;
          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onTap();
            },
            onLongPress: () {
              HapticFeedback.heavyImpact();
              onLongPress();
            },
            child: SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow Ring
                  CustomPaint(
                    size: const Size(72, 72),
                    painter: OilDropGlowPainter(
                      pulse: pulse,
                      color: goldColor,
                    ),
                  ),
                  // Core Liquid Button
                  CustomPaint(
                    size: const Size(58, 58),
                    painter: OilDropButtonPainter(
                      pulse: pulse,
                      baseColor: darkOil,
                      accentColor: goldColor,
                    ),
                  ),
                  // Center Icon
                  Icon(
                    Icons.add_location_alt_rounded,
                    color: goldColor,
                    size: 28 + (pulse * 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class OilDropGlowPainter extends CustomPainter {
  final double pulse;
  final Color color;

  OilDropGlowPainter({required this.pulse, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * (0.8 + 0.2 * pulse);
    final paint = Paint()
      ..color = color.withOpacity((1.0 - pulse) * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + (pulse * 2.0)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant OilDropGlowPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.color != color;
}

class OilDropButtonPainter extends CustomPainter {
  final double pulse;
  final Color baseColor;
  final Color accentColor;

  OilDropButtonPainter({
    required this.pulse,
    required this.baseColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base dark gradient
    final baseGradient = RadialGradient(
      center: const Alignment(-0.2, -0.3),
      radius: 0.85,
      colors: [
        accentColor.withOpacity(0.35),
        baseColor,
        const Color(0xFF0A0703),
      ],
    );

    final bgPaint = Paint()
      ..shader = baseGradient.createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Golden liquid border
    final borderPaint = Paint()
      ..color = accentColor.withOpacity(0.75 + pulse * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, radius - 1, borderPaint);
  }

  @override
  bool shouldRepaint(covariant OilDropButtonPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
