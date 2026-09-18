import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../engine/aurae_render_governor.dart';
import '../engine/shader_engine.dart';

/// Universal GPU shader background.
/// Loads [shaderAsset] (e.g. 'shaders/liquid.frag') and calls [onSetUniforms]
/// each frame so the caller can push float uniforms to the shader.
class GpuShaderBackground extends StatefulWidget {
  final String shaderAsset;
  final void Function(ui.FragmentShader shader, double time, Size size)
      onSetUniforms;
  final Widget? child;
  final Color fallbackColor;

  const GpuShaderBackground({
    super.key,
    required this.shaderAsset,
    required this.onSetUniforms,
    this.child,
    this.fallbackColor = const Color(0xFF06080F),
  });

  @override
  State<GpuShaderBackground> createState() => _GpuShaderBackgroundState();
}

class _GpuShaderBackgroundState extends State<GpuShaderBackground> {
  ui.FragmentProgram? _program;
  late Ticker _ticker;
  double _time = 0.0;
  Duration _lastPaintElapsed = Duration.zero;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Ticker((elapsed) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      final reduced =
          MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
      final interval = AuraeRenderGovernor.instance.frameInterval(
        reducedMotion: reduced,
        requestedFps: 60,
        heavy: true,
      );
      if (elapsed - _lastPaintElapsed < interval) return;
      _lastPaintElapsed = elapsed;
      setState(() => _time = elapsed.inMilliseconds / 1000.0);
    })
      ..start();
  }

  Future<void> _load() async {
    final p = await ShaderEngine().loadShader(widget.shaderAsset);
    if (!mounted) return;
    if (p == null) {
      setState(() => _failed = true);
    } else {
      setState(() => _program = p);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(builder: (ctx, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        Widget bg;
        if (_failed || _program == null) {
          bg = ColoredBox(color: widget.fallbackColor);
        } else {
          final shader = _program!.fragmentShader();
          widget.onSetUniforms(shader, _time, size);
          bg = CustomPaint(
            size: size,
            painter: _ShaderPainter(shader: shader),
          );
        }

        if (widget.child == null) return bg;
        return Stack(
          children: [Positioned.fill(child: bg), widget.child!],
        );
      }),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  _ShaderPainter({required this.shader});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_ShaderPainter old) => true;
}
