import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'aurae_render_governor.dart';

/// Manages shader lifecycle: loading, caching, offscreen pausing, reduced motion.
class ShaderEngine extends WidgetsBindingObserver {
  static final ShaderEngine _instance = ShaderEngine._internal();
  factory ShaderEngine() => _instance;
  ShaderEngine._internal();

  final Map<String, ui.FragmentProgram> _cache = {};
  bool _isPaused = false;
  bool _reducedMotion = false;

  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  double gyroX = 0.0;
  double gyroY = 0.0;

  bool get isPaused => _isPaused;
  bool get reducedMotion => _reducedMotion;

  /// Initialize and start observing lifecycle
  void init() {
    WidgetsBinding.instance.addObserver(this);
    try {
      _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
        if (!_isPaused && !_reducedMotion) {
          // Accumulate and damp for smooth parallax drift
          gyroX = (gyroX + event.y * 0.01).clamp(-1.0, 1.0);
          gyroY = (gyroY + event.x * 0.01).clamp(-1.0, 1.0);

          gyroX *= 0.95; // damping
          gyroY *= 0.95;
        }
      });
    } catch (e) {
      debugPrint('[ShaderEngine] Gyroscope not available: $e');
    }
  }

  /// Dispose observer
  void dispose() {
    _gyroSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Lifecycle: pause shaders when app is backgrounded
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _isPaused = true;
      case AppLifecycleState.resumed:
        _isPaused = false;
    }
  }

  /// Check reduced motion accessibility setting
  void updateAccessibility(BuildContext context) {
    _reducedMotion = MediaQuery.of(context).accessibleNavigation;
  }

  /// Load and cache a fragment shader
  Future<ui.FragmentProgram?> loadShader(String assetPath) async {
    if (_cache.containsKey(assetPath)) return _cache[assetPath];
    try {
      final program = await ui.FragmentProgram.fromAsset(assetPath);
      _cache[assetPath] = program;
      return program;
    } catch (e) {
      debugPrint('[ShaderEngine] Failed to load $assetPath: $e');
      return null;
    }
  }

  /// Get cached shader (null if not loaded)
  ui.FragmentProgram? getShader(String assetPath) => _cache[assetPath];

  /// Clear all cached shaders (memory pressure)
  void clearCache() => _cache.clear();
}

/// A Ticker-based shader widget that auto-pauses offscreen and respects reduced motion.
class ShaderSceneWidget extends StatefulWidget {
  final String shaderAsset;
  final Widget Function(BuildContext, ui.FragmentShader, double time) builder;
  final Widget? fallback;
  final int targetFps;

  const ShaderSceneWidget({
    super.key,
    required this.shaderAsset,
    required this.builder,
    this.fallback,
    this.targetFps = 60,
  });

  @override
  State<ShaderSceneWidget> createState() => _ShaderSceneWidgetState();
}

class _ShaderSceneWidgetState extends State<ShaderSceneWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ui.FragmentProgram? _program;
  late Ticker _ticker;
  double _time = 0.0;
  Duration _lastPaintElapsed = Duration.zero;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadShader();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;
    final reduced = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    final interval = AuraeRenderGovernor.instance.frameInterval(
      reducedMotion: reduced,
      requestedFps: widget.targetFps,
      heavy: true,
    );
    if (elapsed - _lastPaintElapsed < interval) return;
    _lastPaintElapsed = elapsed;
    setState(() => _time = elapsed.inMilliseconds / 1000.0);
  }

  Future<void> _loadShader() async {
    final prog = await ShaderEngine().loadShader(widget.shaderAsset);
    if (mounted) {
      if (prog != null) {
        setState(() => _program = prog);
      } else {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _ticker.stop();
      case AppLifecycleState.resumed:
        _ticker.start();
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback ?? const SizedBox.shrink();
    if (_program == null) {
      return widget.fallback ?? const Center(child: CircularProgressIndicator(color: Colors.white24));
    }

    return RepaintBoundary(
      child: widget.builder(context, _program!.fragmentShader(), _time),
    );
  }
}
