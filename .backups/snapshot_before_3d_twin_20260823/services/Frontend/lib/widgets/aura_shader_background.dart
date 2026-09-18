import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/pulse_colors.dart';

class AuraShaderBackground extends StatefulWidget {
  final Widget child;
  final Color primaryColor;
  final Color secondaryColor;
  final double pulseIndex; // 0.0 to 1.0

  const AuraShaderBackground({
    super.key,
    required this.child,
    this.primaryColor = const Color(0xFF2C10E8),
    this.secondaryColor = const Color(0xFF00FFCC),
    this.pulseIndex = 0.5,
  });

  @override
  State<AuraShaderBackground> createState() => _AuraShaderBackgroundState();
}

class _AuraShaderBackgroundState extends State<AuraShaderBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      setState(() {
        // Скорость зависит от пульса: чем выше пульс, тем быстрее Аура
        final speedMultiplier = 0.5 + (widget.pulseIndex * 2.5);
        _time += (0.016 * speedMultiplier);
      });
    });
  }

  Future<void> _loadShader() async {
    try {
      final program = await FragmentProgram.fromAsset('shaders/aura_theme.frag');
      setState(() {
        _shader = program.fragmentShader();
      });
      _ticker.start();
    } catch (e) {
      debugPrint('Error loading aura shader: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null) {
      return Container(
        color: PulseColors.background,
        child: widget.child,
      );
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuraShaderPainter(
          shader: _shader!,
          time: _time,
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
        ),
        child: widget.child,
      ),
    );
  }
}

class _AuraShaderPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;
  final Color primaryColor;
  final Color secondaryColor;

  _AuraShaderPainter({
    required this.shader,
    required this.time,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1: u_resolution
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    // 2: u_time
    shader.setFloat(2, time);
    // 3: u_color1
    shader.setFloat(3, primaryColor.red / 255);
    shader.setFloat(4, primaryColor.green / 255);
    shader.setFloat(5, primaryColor.blue / 255);
    // 4: u_color2
    shader.setFloat(6, secondaryColor.red / 255);
    shader.setFloat(7, secondaryColor.green / 255);
    shader.setFloat(8, secondaryColor.blue / 255);
    // 5: u_quality
    shader.setFloat(9, 1.0);
    // 6: u_touch
    shader.setFloat(10, 0.5);
    shader.setFloat(11, 0.5);
    // 7: u_energy
    shader.setFloat(12, 0.0);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _AuraShaderPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
