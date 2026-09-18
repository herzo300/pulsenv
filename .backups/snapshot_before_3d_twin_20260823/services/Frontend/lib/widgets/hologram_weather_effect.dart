import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// VIP-only holographic weather overlay widget using custom GLSL shader.
/// Renders holographic grid, neon scanners, wave distortion,
/// chromatic aberration, and iridescent glassmorphic effects.
class HologramWeatherEffect extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const HologramWeatherEffect({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<HologramWeatherEffect> createState() => _HologramWeatherEffectState();
}

class _HologramWeatherEffectState extends State<HologramWeatherEffect>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  ui.FragmentShader? _shader;
  bool _shaderLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      if (mounted && _shaderLoaded) {
        setState(() {
          _time = elapsed.inMilliseconds / 1000.0;
        });
      }
    });
    if (widget.enabled) _ticker.start();
  }

  Future<void> _loadShader() async {
    // Disabled to prevent GLSL shader crashes on devices.
    return;
  }

  @override
  void didUpdateWidget(HologramWeatherEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.enabled && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_shaderLoaded || _shader == null) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return RepaintBoundary(
          child: CustomPaint(
            painter: _HologramPainter(
              shader: _shader!,
              time: _time,
              size: size,
              child: widget.child,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _HologramPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final Size size;
  final Widget child;

  _HologramPainter({
    required this.shader,
    required this.time,
    required this.size,
    required this.child,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Set shader uniforms: u_time, u_resolution
    shader.setFloat(0, time);
    shader.setFloat(1, canvasSize.width);
    shader.setFloat(2, canvasSize.height);
    // u_texture will be set by Flutter automatically from the layer

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_HologramPainter old) =>
      old.time != time || old.size != size;
}

/// Simpler overlay version that uses decorative Canvas drawing
/// as a fallback or in addition to the shader.
class HologramOverlayPainter extends CustomPainter {
  final double time;
  final bool isEnabled;

  const HologramOverlayPainter({required this.time, this.isEnabled = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isEnabled) return;

    final w = size.width;
    final h = size.height;

    // 1. Holographic grid
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.07)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridCols = 20;
    const gridRows = 30;
    for (int i = 0; i <= gridCols; i++) {
      final x = w * i / gridCols;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (int j = 0; j <= gridRows; j++) {
      final y = h * j / gridRows;
      // Slight horizontal wave
      final wave = 3.0 * (0.5 + 0.5 * _sin(time * 2.0 + j * 0.3));
      canvas.drawLine(
        Offset(0, y + wave),
        Offset(w, y - wave),
        gridPaint,
      );
    }

    // 2. Neon scanner beam
    final scannerY = (time * 0.15 % 1.0) * h;
    final scannerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF00E5FF).withOpacity(0.5),
          const Color(0xFF00E5FF).withOpacity(0.8),
          const Color(0xFF00E5FF).withOpacity(0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, scannerY - 20, w, 40));
    canvas.drawRect(
      Rect.fromLTWH(0, scannerY - 20, w, 40),
      scannerPaint,
    );

    // 3. Corner brackets (HUD frame)
    final bracketPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const cs = 20.0;
    const margin = 12.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(margin + cs, margin)
        ..lineTo(margin, margin)
        ..lineTo(margin, margin + cs),
      bracketPaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - margin - cs, margin)
        ..lineTo(w - margin, margin)
        ..lineTo(w - margin, margin + cs),
      bracketPaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(margin + cs, h - margin)
        ..lineTo(margin, h - margin)
        ..lineTo(margin, h - margin - cs),
      bracketPaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - margin - cs, h - margin)
        ..lineTo(w - margin, h - margin)
        ..lineTo(w - margin, h - margin - cs),
      bracketPaint,
    );

    // 4. Iridescent shimmer overlay
    final shimmerPhase = _sin(time * 0.8) * 0.5 + 0.5;
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromARGB((shimmerPhase * 15).round(), 0, 200, 255),
          Color.fromARGB(((1 - shimmerPhase) * 12).round(), 100, 0, 255),
          Color.fromARGB((shimmerPhase * 10).round(), 0, 255, 200),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), shimmerPaint);
  }

  double _sin(double x) => (x % (2 * 3.14159)).abs() < 3.14159
      ? x - x * x * x / 6.0
      : -(x - x * x * x / 6.0);

  @override
  bool shouldRepaint(_) => true;
}

/// Drop-in holographic wrapper using canvas-based overlay (no shader compilation required)
class HologramCanvasEffect extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const HologramCanvasEffect({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<HologramCanvasEffect> createState() => _HologramCanvasEffectState();
}

class _HologramCanvasEffectState extends State<HologramCanvasEffect>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (mounted) setState(() => _time = elapsed.inMilliseconds / 1000.0);
    });
    if (widget.enabled) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.enabled)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: HologramOverlayPainter(
                  time: _time,
                  isEnabled: widget.enabled,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
