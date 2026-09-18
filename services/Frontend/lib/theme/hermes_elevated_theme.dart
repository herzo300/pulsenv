import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Enhanced visual configuration for the assistant's elevated runtime mode.
/// Provides holographic cyber aesthetic: neon cyan, scanning grid lines,
/// glitch text effects, and matrix rain background particles.
class HermesElevatedTheme {
  HermesElevatedTheme._();

  // ─── Core palette ───
  static const Color bgDeep = Color(0xFF020A14);
  static const Color bgPanel = Color(0xFF051020);
  static const Color bgCard = Color(0xFF0A1628);

  static const Color neonCyan = Color(0xFF00FFEA);
  static const Color neonCyanDim = Color(0xFF00B8A9);
  static const Color neonViolet = Color(0xFF9D4EDD);
  static const Color neonMagenta = Color(0xFFFF006E);
  static const Color neonAmber = Color(0xFFFFBE0B);

  static const Color scanLine = Color(0x1800FFEA);
  static const Color gridLine = Color(0x0C00FFEA);

  static const Color textPrimary = Color(0xFFE0FFF8);
  static const Color textSecondary = Color(0xFF7ECCBF);
  static const Color textDim = Color(0xFF3D7A6E);

  static const Color borderGlow = Color(0x4400FFEA);
  static const Color borderStrong = Color(0x8800FFEA);

  /// Gradient used for the elevated mode appbar / header area.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF020A14), Color(0xFF0D1B2A), Color(0xFF1B2838)],
  );

  /// Panel decoration with neon border glow.
  static BoxDecoration panelDecoration({double borderRadius = 20}) {
    return BoxDecoration(
      color: bgPanel,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderGlow, width: 1),
      boxShadow: [
        BoxShadow(
          color: neonCyan.withOpacity(0.08),
          blurRadius: 24,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: neonViolet.withOpacity(0.04),
          blurRadius: 40,
          spreadRadius: 4,
        ),
      ],
    );
  }

  /// Elevated message bubble for AI responses.
  static BoxDecoration aiBubbleDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0A1628), Color(0xFF0D2137)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(20),
      ),
      border: Border.all(color: borderGlow, width: 0.8),
      boxShadow: [
        BoxShadow(
          color: neonCyan.withOpacity(0.06),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ],
    );
  }

  /// Neon accent button style.
  static ButtonStyle neonButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: neonCyan.withOpacity(0.15),
      foregroundColor: neonCyan,
      side: const BorderSide(color: neonCyan, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    );
  }

  /// Input field decoration for the elevated questionnaire.
  static InputDecoration inputDecoration(String hint, String icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textDim, fontSize: 14),
      prefixText: '$icon  ',
      prefixStyle: const TextStyle(fontSize: 18),
      filled: true,
      fillColor: const Color(0xFF071424),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderGlow, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: neonCyan, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

/// Scan-line overlay painter for holographic aesthetic.
class ScanLinePainter extends CustomPainter {
  final double phase;

  ScanLinePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HermesElevatedTheme.scanLine
      ..strokeWidth = 1;

    // Horizontal scan lines
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Moving scan beam
    final beamY = (phase * size.height) % size.height;
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          HermesElevatedTheme.neonCyan.withOpacity(0),
          HermesElevatedTheme.neonCyan.withOpacity(0.12),
          HermesElevatedTheme.neonCyan.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, beamY - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, beamY - 40, size.width, 80), beamPaint);
  }

  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) => oldDelegate.phase != phase;
}

/// Grid overlay painter for hexagonal cyber background.
class HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HermesElevatedTheme.gridLine
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Matrix rain particle for background effect.
class MatrixRainParticle {
  double x;
  double y;
  double speed;
  String char;
  double opacity;

  MatrixRainParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.char,
    required this.opacity,
  });
}

/// Widget that renders the matrix rain + scan lines as a stack overlay.
class ElevatedBackgroundOverlay extends StatefulWidget {
  final Widget child;

  const ElevatedBackgroundOverlay({super.key, required this.child});

  @override
  State<ElevatedBackgroundOverlay> createState() => _ElevatedBackgroundOverlayState();
}

class _ElevatedBackgroundOverlayState extends State<ElevatedBackgroundOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep background
        Container(color: HermesElevatedTheme.bgDeep),
        // Hex grid
        CustomPaint(
          painter: HexGridPainter(),
          size: Size.infinite,
        ),
        // Scan line overlay
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: ScanLinePainter(phase: _controller.value),
              size: Size.infinite,
            );
          },
        ),
        // Content
        widget.child,
      ],
    );
  }
}
