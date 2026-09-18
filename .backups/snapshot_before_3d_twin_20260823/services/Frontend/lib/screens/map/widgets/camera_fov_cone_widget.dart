// lib/screens/map/widgets/camera_fov_cone_widget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class CameraFovConeWidget extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  final double azimuthDegrees; // 0 to 360 deg (0 = North, 90 = East, 180 = South, 270 = West)
  final double fovDegrees; // typically 60 to 90 degrees
  final bool showFovCone; // true when map zoom >= 14.0
  final bool isFavorite;
  final bool isAlarm;

  const CameraFovConeWidget({
    super.key,
    required this.color,
    required this.icon,
    this.size = 52.0,
    this.azimuthDegrees = 45.0,
    this.fovDegrees = 75.0,
    this.showFovCone = true,
    this.isFavorite = false,
    this.isAlarm = false,
  });

  @override
  Widget build(BuildContext context) {
    final coneRadius = size * 1.35;
    final totalWidgetSize = showFovCone ? (size + coneRadius * 2) : size;

    return SizedBox(
      width: totalWidgetSize,
      height: totalWidgetSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Semi-transparent illuminated FOV Light Cone (Visible when zoomed in)
          if (showFovCone)
            CustomPaint(
              size: Size(totalWidgetSize, totalWidgetSize),
              painter: _CameraFovConePainter(
                color: color,
                azimuthRad: (azimuthDegrees - 90) * math.pi / 180.0,
                fovRad: fovDegrees * math.pi / 180.0,
                radius: coneRadius,
              ),
            ),

          // 2. Camera Core Icon Circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F172A).withOpacity(0.92),
              border: Border.all(
                color: color.withOpacity(0.95),
                width: isFavorite || isAlarm ? 2.5 : 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: size * 0.48,
              ),
            ),
          ),

          // 3. Live Green Pulsing Indicator Dot
          Positioned(
            top: showFovCone ? (coneRadius + 3) : 3,
            right: showFovCone ? (coneRadius + 3) : 3,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAlarm ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: isAlarm ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraFovConePainter extends CustomPainter {
  final Color color;
  final double azimuthRad;
  final double fovRad;
  final double radius;

  _CameraFovConePainter({
    required this.color,
    required this.azimuthRad,
    required this.fovRad,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final startAngle = azimuthRad - (fovRad / 2);
    final sweepAngle = fovRad;

    final path = Path();
    path.moveTo(center.dx, center.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
    );
    path.close();

    // 1. Volumetric Light Cone Fill
    final conePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          color.withOpacity(0.42),
          color.withOpacity(0.20),
          color.withOpacity(0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, conePaint);

    // 2. Light Ray Edge Lines
    final edgePaint = Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final leftRayEnd = center + Offset(math.cos(startAngle) * radius, math.sin(startAngle) * radius);
    final rightRayEnd = center + Offset(math.cos(startAngle + sweepAngle) * radius, math.sin(startAngle + sweepAngle) * radius);

    canvas.drawLine(center, leftRayEnd, edgePaint);
    canvas.drawLine(center, rightRayEnd, edgePaint);

    // 3. Perimeter Arc
    final arcPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraFovConePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.azimuthRad != azimuthRad ||
      oldDelegate.fovRad != fovRad ||
      oldDelegate.radius != radius;
}
