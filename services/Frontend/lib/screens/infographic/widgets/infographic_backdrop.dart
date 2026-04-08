/// Infographic animated backdrop with blur blobs and grid.
///
/// Replaces the private `_InfographicBackdrop` from `infographic_screen.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme/pulse_colors.dart';
import '../../../widgets/app_ui.dart';

/// Thin wrapper around [AppScreenBackground] that adds animated aurora blobs.
///
/// **Deprecation notice**: prefer using [AppScreenBackground] directly when
/// animated blobs are not required. This widget exists for backward-compatibility
/// with the original infographic screen.
class InfographicBackdrop extends StatefulWidget {
  const InfographicBackdrop({super.key});

  @override
  State<InfographicBackdrop> createState() => _InfographicBackdropState();
}

class _InfographicBackdropState extends State<InfographicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF030711),
                Color(0xFF071123),
                Color(0xFF02050D)
              ]),
        ),
      ),
      Positioned.fill(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -100 + (30 * math.sin(t * math.pi * 2)),
                  right: -120 + (50 * math.cos(t * math.pi)),
                  child: _BlurBlob(
                      const Color(0x7000FF87), 380), // Aurora green 44%
                ),
                Positioned(
                  top: 240 + (40 * math.cos(t * math.pi * 1.5)),
                  left: -140 + (40 * math.sin(t * math.pi * 2)),
                  child: _BlurBlob(
                      const Color(0x6660EFFF), 420), // Aurora cyan 40%
                ),
                Positioned(
                  bottom: -150 + (60 * math.sin(t * math.pi)),
                  right: -40 + (80 * math.cos(t * math.pi * 2.5)),
                  child: _BlurBlob(
                      const Color(0x5CB100FF), 400), // Aurora violet 36%
                ),
                Positioned(
                  bottom: 120 + (50 * math.cos(t * math.pi * 1.2)),
                  left: -80 + (60 * math.sin(t * math.pi * 0.8)),
                  child: _BlurBlob(
                      const Color(0x5000FF87), 320), // Aurora green 31%
                ),
              ],
            );
          },
        ),
      ),
      Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
    ]);
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob(this.color, this.size);
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BlobPainter(color, size)),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter(this.color, this.diameter);
  final Color color;
  final double diameter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = diameter / 2;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [color, color.withOpacity(0)],
        [0.0, 1.0],
      )
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 42);
    canvas.drawCircle(center, radius * 0.88, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) =>
      old.color != color || old.diameter != diameter;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PulseColors.textPrimary.withOpacity(0.04)
      ..strokeWidth = 0.8;
    for (double y = 0; y < size.height; y += 72) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 72) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
