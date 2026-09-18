/// 3D-styled marker for UK-managed houses on the map.
/// - Shows as a glossy "pills" with house number.
/// - Number label appears only when zoomed in (passed via showLabel).
/// - Has depth: shadow + gradient + inner highlight.
/// - Pulses on tap.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../theme/pulse_colors.dart';

class UkHouseMarker {
  /// Build a [Marker] for a single UK-managed house.
  ///
  /// [lat], [lon] — coordinates of the house.
  /// [houseNumber] — extracted from address ("ул. Ленина, 12" → "12").
  /// [ukName] — for tooltip.
  /// [showLabel] — if true, render house number; otherwise render compact dot.
  /// [onTap] — callback to show house / UK details.
  /// [pulseAnimation] — optional, drives subtle pulse.
  static Marker build({
    required double lat,
    required double lon,
    required String houseNumber,
    required String ukName,
    required bool showLabel,
    required bool isDayMode,
    VoidCallback? onTap,
    Animation<double>? pulseAnimation,
    int colorSeed = 0,
  }) {
    return Marker(
      point: LatLng(lat, lon),
      width: showLabel ? 60 : 26,
      height: showLabel ? 55 : 28,
      alignment: Alignment.center,
      child: _UkHouseView(
        houseNumber: houseNumber,
        ukName: ukName,
        showLabel: showLabel,
        isDayMode: isDayMode,
        onTap: onTap,
        pulseAnimation: pulseAnimation,
        colorSeed: colorSeed,
      ),
    );
  }

  /// Extract the house number from address like "ул. Ленина, 12" → "12".
  /// Returns null if no clear number.
  static String? extractHouseNumber(String address) {
    if (address.isEmpty) return null;
    final commaIdx = address.lastIndexOf(',');
    final candidate = commaIdx >= 0 ? address.substring(commaIdx + 1).trim() : address.trim();
    final m = RegExp(r'^(\d+[А-Яа-яA-Za-z]?(/\d+)?)').firstMatch(candidate);
    if (m != null) return m.group(1);
    final m2 = RegExp(r'(\d+[А-Яа-яA-Za-z]?(/\d+)?)').firstMatch(address);
    return m2?.group(1);
  }
}

class _UkHouseView extends StatelessWidget {
  final String houseNumber;
  final String ukName;
  final bool showLabel;
  final bool isDayMode;
  final VoidCallback? onTap;
  final Animation<double>? pulseAnimation;
  final int colorSeed;

  const _UkHouseView({
    required this.houseNumber,
    required this.ukName,
    required this.showLabel,
    required this.isDayMode,
    this.onTap,
    this.pulseAnimation,
    this.colorSeed = 0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = [
      PulseColors.primary,
      PulseColors.accentViolet,
      const Color(0xFFFFC857), // gold
      const Color(0xFF00E676), // success green
    ];
    final accent = palette[colorSeed.abs() % palette.length];

    final content = GestureDetector(
      onTap: onTap,
      child: showLabel ? _buildCombined(accent) : _build3DHouse(accent),
    );

    if (pulseAnimation == null) return content;

    return AnimatedBuilder(
      animation: pulseAnimation!,
      builder: (context, child) {
        final t = (pulseAnimation!.value * 2 * 3.14159);
        final scale = 1.0 + 0.05 * (0.5 + 0.5 * math.sin(t));
        return Transform.scale(scale: scale, child: child);
      },
      child: content,
    );
  }

  Widget _build3DHouse(Color accent) {
    return CustomPaint(
      size: const Size(20, 24),
      painter: _House3DPainter(baseColor: accent),
    );
  }

  Widget _buildCombined(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating house number plate
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(220),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withAlpha(200), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              )
            ],
          ),
          child: Text(
            houseNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 3),
        // 3D Isometric building marker under the label
        CustomPaint(
          size: const Size(22, 26),
          painter: _House3DPainter(baseColor: accent),
        ),
      ],
    );
  }
}

/// CustomPainter for drawing high-performance isometric 3D-house markers.
class _House3DPainter extends CustomPainter {
  final Color baseColor;

  _House3DPainter({required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2 - 2;

    // Face color variations
    final topColor1 = Color.lerp(baseColor, Colors.white, 0.40)!;
    final topColor2 = Color.lerp(baseColor, Colors.white, 0.20)!;
    final leftColor = baseColor;
    final rightColor = Color.lerp(baseColor, Colors.black, 0.35)!;

    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withAlpha(190)
      ..strokeWidth = 0.8;

    // 0. Base Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + h * 0.35), width: w * 0.9, height: h * 0.35),
      shadowPaint,
    );

    // 1. Top Face (Isometric rhombus)
    final topPath = Path()
      ..moveTo(cx, cy - h / 4)
      ..lineTo(cx + w / 2, cy - h / 8)
      ..lineTo(cx, cy)
      ..lineTo(cx - w / 2, cy - h / 8)
      ..close();
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [topColor1, topColor2],
    ).createShader(Rect.fromLTRB(cx - w / 2, cy - h / 4, cx + w / 2, cy));
    canvas.drawPath(topPath, paint);
    canvas.drawPath(topPath, strokePaint);

    // 2. Left Face
    final leftPath = Path()
      ..moveTo(cx - w / 2, cy - h / 8)
      ..lineTo(cx, cy)
      ..lineTo(cx, cy + h * 0.35)
      ..lineTo(cx - w / 2, cy + h * 0.23)
      ..close();
    paint.shader = null;
    paint.color = leftColor;
    canvas.drawPath(leftPath, paint);
    canvas.drawPath(leftPath, strokePaint);

    // 3. Right Face (Shadow side)
    final rightPath = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + w / 2, cy - h / 8)
      ..lineTo(cx + w / 2, cy + h * 0.23)
      ..lineTo(cx, cy + h * 0.35)
      ..close();
    paint.color = rightColor;
    canvas.drawPath(rightPath, paint);
    canvas.drawPath(rightPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
