import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart' as sensors_plus;

/// Drop-in replacement for HologramEffect.
/// Renders GLSL shader effects (grid, wave, chromatic aberration) for VIP subscription,
/// with a fully decorated Canvas-drawn HUD frame fallback.
class HologramEffect extends StatefulWidget {
  final Widget child;
  final bool isEnabled;
  final bool showScanLine;
  final bool onceAMinute;
  final bool showGrid;

  const HologramEffect({
    super.key,
    required this.child,
    this.isEnabled = true,
    this.showScanLine = true,
    this.onceAMinute = false,
    this.showGrid = true,
  });

  @override
  State<HologramEffect> createState() => _HologramEffectState();
}

class _HologramEffectState extends State<HologramEffect>
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
      if (mounted) {
        setState(() {
          _time = elapsed.inMilliseconds / 1000.0;
        });
      }
    });
    if (widget.isEnabled) _ticker.start();
  }

  Future<void> _loadShader() async {
    // Disabled to prevent GLSL shader crashes on devices. Safe canvas fallback is used.
    return;
  }

  @override
  void didUpdateWidget(HologramEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.isEnabled && _ticker.isActive) {
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
    if (!widget.isEnabled) return widget.child;

    Widget shaderContent = const SizedBox.shrink();

    // Apply the custom GLSL shader if loaded
    if (_shaderLoaded && _shader != null) {
      shaderContent = LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return CustomPaint(
            painter: _HologramShaderPainter(
              shader: _shader!,
              time: _time,
              size: size,
            ),
          );
        },
      );
    }

    // Wrap the hologram overlays with a StreamBuilder for Gyro Parallax
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: StreamBuilder(
              stream: sensors_plus.gyroscopeEventStream(),
              builder: (context, AsyncSnapshot<sensors_plus.GyroscopeEvent> snapshot) {
                double xOffset = 0;
                double yOffset = 0;
                if (snapshot.hasData) {
                  // Basic low-pass filter logic by limiting and scaling gyroscope rotation
                  xOffset = (snapshot.data!.y * 5).clamp(-15.0, 15.0);
                  yOffset = (snapshot.data!.x * 5).clamp(-15.0, 15.0);
                }
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(xOffset, yOffset, 0),
                  child: Stack(
                    children: [
                      shaderContent,
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _HologramCanvasOverlayPainter(
                            time: _time,
                            showScanLine: widget.showScanLine,
                            onceAMinute: widget.onceAMinute,
                            showGrid: widget.showGrid,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HologramShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final Size size;

  _HologramShaderPainter({
    required this.shader,
    required this.time,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    shader.setFloat(0, time);
    shader.setFloat(1, canvasSize.width);
    shader.setFloat(2, canvasSize.height);

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_HologramShaderPainter old) =>
      old.time != time || old.size != size;
}

class _HologramCanvasOverlayPainter extends CustomPainter {
  final double time;
  final bool showScanLine;
  final bool onceAMinute;
  final bool showGrid;

  const _HologramCanvasOverlayPainter({
    required this.time,
    required this.showScanLine,
    required this.onceAMinute,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Grid
    if (showGrid) {
      final gridPaint = Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.06)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;

      const gridCols = 15;
      const gridRows = 20;
      for (int i = 0; i <= gridCols; i++) {
        final x = w * i / gridCols;
        canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
      }
      for (int j = 0; j <= gridRows; j++) {
        final y = h * j / gridRows;
        canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      }
    }

    // 2. Scanline bar
    if (showScanLine) {
      double? scannerY;
      if (onceAMinute) {
        final cycleTime = time % 60.0;
        if (cycleTime < 3.0) {
          scannerY = (cycleTime / 3.0) * h;
        }
      } else {
        scannerY = ((time * 0.25) % 1.0) * h;
      }

      if (scannerY != null) {
        // Draw a glowing horizontal scanline with a sine-wave warp/vibration!
        final path = Path();
        path.moveTo(0, scannerY);
        for (double x = 0; x <= w; x += 5) {
          final wave = math.sin((x / 12.0) + (time * 15.0)) * 2.5;
          path.lineTo(x, scannerY + wave);
        }

        final glowPaint = Paint()
          ..color = const Color(0xFF00E5FF).withOpacity(0.25)
          ..strokeWidth = 8.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final midPaint = Paint()
          ..color = const Color(0xFF00E5FF).withOpacity(0.60)
          ..strokeWidth = 4.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final corePaint = Paint()
          ..color = const Color(0xFFE0F7FA).withOpacity(0.95)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawPath(path, glowPaint);
        canvas.drawPath(path, midPaint);
        canvas.drawPath(path, corePaint);
      }
    }

    // 3. Corner brackets
    final bracketPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const cs = 16.0;
    const margin = 8.0;

    canvas.drawPath(Path()..moveTo(margin + cs, margin)..lineTo(margin, margin)..lineTo(margin, margin + cs), bracketPaint);
    canvas.drawPath(Path()..moveTo(w - margin - cs, margin)..lineTo(w - margin, margin)..lineTo(w - margin, margin + cs), bracketPaint);
    canvas.drawPath(Path()..moveTo(margin + cs, h - margin)..lineTo(margin, h - margin)..lineTo(margin, h - margin - cs), bracketPaint);
    canvas.drawPath(Path()..moveTo(w - margin - cs, h - margin)..lineTo(w - margin, h - margin)..lineTo(w - margin, h - margin - cs), bracketPaint);
  }

  @override
  bool shouldRepaint(_HologramCanvasOverlayPainter old) => old.time != time;
}
