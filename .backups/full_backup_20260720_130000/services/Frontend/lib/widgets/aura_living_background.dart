import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/living/aura_circadian.dart';
import '../core/living/aura_living_engine.dart';
import '../engine/aurae_render_governor.dart';
import '../engine/shader_engine.dart';
import 'native_3d_engine.dart';

class AuraLivingBackground extends StatefulWidget {
  final AuraLivingScene scene;
  final Widget child;
  final bool interactive;
  final bool showSignatureObject;
  final bool showConstellationVeil;
  final ValueChanged<Offset>? onFieldPulse;

  const AuraLivingBackground({
    super.key,
    required this.scene,
    required this.child,
    this.interactive = true,
    this.showSignatureObject = false,
    this.showConstellationVeil = true,
    this.onFieldPulse,
  });

  @override
  State<AuraLivingBackground> createState() => _AuraLivingBackgroundState();
}

class _AuraLivingBackgroundState extends State<AuraLivingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final List<_AuraRipple> _ripples = [];
  final List<double> _tapMoments = [];
  double _gyroX = 0;
  double _gyroY = 0;
  double _touchEnergy = 0;
  Offset? _fogTouch;
  double _secretBornAt = -100;
  Offset _lastTouchNorm = const Offset(0.5, 0.5); // normalized touch
  bool _reduceMotion = false;
  DateTime _lastGyro = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRipple = DateTime.fromMillisecondsSinceEpoch(0);

  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _loadVipStatus();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
    _startGyro();
  }

  Future<void> _loadVipStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isVip = prefs.getBool('is_vip') ?? false;
        });
      }
    } catch (_) {}
  }

  void _startGyro() {
    try {
      _gyroSub = gyroscopeEventStream().listen((event) {
        if (!mounted || _reduceMotion) {
          return;
        }
        final now = DateTime.now();
        if (now.difference(_lastGyro) < const Duration(milliseconds: 180)) {
          return;
        }
        _lastGyro = now;
        final nextX = (_gyroX * 0.985 + event.y * 0.006).clamp(-0.12, 0.12);
        final nextY = (_gyroY * 0.985 + event.x * 0.006).clamp(-0.12, 0.12);
        if ((nextX - _gyroX).abs() + (nextY - _gyroY).abs() < 0.026) {
          return;
        }
        _gyroX = nextX;
        _gyroY = nextY;
      }, onError: (_) {});
    } catch (_) {
      // Sensors are optional on desktop and web.
    }
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _addRipple(Offset position) {
    if (!widget.interactive) return;
    final wallClock = DateTime.now();
    if (wallClock.difference(_lastRipple) < const Duration(milliseconds: 140)) {
      return;
    }
    _lastRipple = wallClock;
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    widget.onFieldPulse?.call(position);
    setState(() {
      _touchEnergy = (_touchEnergy + 0.28).clamp(0.0, 1.0);
      _fogTouch = position;
      _ripples.add(_AuraRipple(position: position, bornAt: now));
      // Сохраняем нормализованную позицию пальца для шейдера
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final s = renderBox.size;
        _lastTouchNorm = Offset(
          (position.dx / s.width).clamp(0.0, 1.0),
          (position.dy / s.height).clamp(0.0, 1.0),
        );
      }
      _tapMoments
        ..add(now)
        ..removeWhere((moment) => now - moment > 3.2);
      if (_tapMoments.length >= 7) {
        _secretBornAt = now;
        _tapMoments.clear();
      }
      if (_ripples.length > 8) {
        _ripples.removeRange(0, _ripples.length - 8);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = !_isVip || MediaQuery.of(context).accessibleNavigation;
    _reduceMotion = reducedMotion;
    final governor = AuraeRenderGovernor.instance;
    final scene = widget.scene.copyWith(
      particleDensity: widget.scene.particleDensity *
          governor.particleScale(
            reducedMotion: reducedMotion,
          ),
    );
    final tickersEnabled = governor.appVisible;
    final nightDim = AuraCircadian.nightDimStrength();

    return TickerMode(
      enabled: tickersEnabled,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => _addRipple(event.localPosition),
        onPointerMove: (event) {
          if (_ripples.length < 8) {
            _addRipple(event.localPosition);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: _baseColor(scene)),
            ),
            // ─── Ken Burns фото-фон (пользовательское фото) ─────────────
            // Если задано backgroundImage — рендерим как нижний слой с
            // медленным zoom/pan (Ken Burns), шейдеры поверх сохраняют
            // живой эффект AuraLiving.
            if (scene.backgroundImage != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.85,
                  child: _KenBurnsImage(imageSrc: scene.backgroundImage!),
                ),
              ),
            Positioned.fill(
              child: ShaderSceneWidget(
                shaderAsset: AuraLivingEngine.shaderAssetFor(scene.weather),
                targetFps: reducedMotion ? 24 : 60,
                fallback: CustomPaint(
                  painter: _AuraFallbackPainter(
                    scene: scene,
                    time: 0,
                    gyro: Offset(_gyroX, _gyroY),
                    ripples: const [],
                    clock: 0,
                    secretBornAt: _secretBornAt,
                    showConstellationVeil: widget.showConstellationVeil,
                  ),
                ),
                builder: (context, shader, time) {
                  final scaledTime = reducedMotion ? 0.0 : time * scene.speed;
                  return CustomPaint(
                    painter: _AuraShaderPainter(
                      shader: shader,
                      scene: scene,
                      time: scaledTime,
                      touchEnergy: _touchEnergy,
                      lastTouch: _lastTouchNorm,
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final clock = DateTime.now().millisecondsSinceEpoch / 1000.0;
                  final activeRipples = _ripples
                      .where((ripple) => clock - ripple.bornAt < 2.1)
                      .toList(growable: false);
                  _touchEnergy = math.max(0, _touchEnergy * 0.992);
                  return Transform.translate(
                    offset: reducedMotion
                        ? Offset.zero
                        : Offset(
                            _gyroX * 2 * scene.depth, _gyroY * 2 * scene.depth),
                    child: CustomPaint(
                      painter: _AuraFallbackPainter(
                        scene: scene,
                        time: reducedMotion ? 0 : _ctrl.value * math.pi * 2,
                        gyro: Offset(_gyroX, _gyroY),
                        ripples: activeRipples,
                        clock: clock,
                        secretBornAt: _secretBornAt,
                        fogTouch: _fogTouch,
                        touchEnergy: _touchEnergy,
                        showConstellationVeil: widget.showConstellationVeil,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.showSignatureObject &&
                scene.premiumSignature &&
                !reducedMotion)
              Positioned(
                right: -52,
                top: 56,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.16,
                    child: Transform.rotate(
                      angle: -0.18,
                      child: Native3DEngine(
                        shape: _shapeFor(scene),
                        color: scene.secondary,
                        size: 260,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.32),
                      radius: 1.18,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF05070D)
                            .withValues(alpha: 0.08 + nightDim * 0.10),
                        const Color(0xFF010207)
                            .withValues(alpha: 0.52 + nightDim * 0.28),
                      ],
                      stops: const [0.0, 0.68, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(0, -1),
                      end: const Alignment(0, 1),
                      colors: [
                        scene.secondary.withValues(
                          alpha: reducedMotion ? 0.045 : 0.07,
                        ),
                        Colors.transparent,
                        scene.primary.withValues(
                          alpha: reducedMotion ? 0.02 : 0.04,
                        ),
                      ],
                      stops: const [0.0, 0.24, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            if (nightDim > 0.02)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF02040A)
                              .withValues(alpha: nightDim * 0.20),
                          Colors.transparent,
                          const Color(0xFF000000)
                              .withValues(alpha: nightDim * 0.28),
                        ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            widget.child,
          ],
        ),
      ),
    );
  }

  Color _baseColor(AuraLivingScene scene) {
    return Color.lerp(const Color(0xFF020409), scene.primary, 0.08)!;
  }

  PracticeShape _shapeFor(AuraLivingScene scene) {
    switch (scene.weather) {
      case AuraWeather.cosmos:
      case AuraWeather.aurora:
      case AuraWeather.dawn:
      case AuraWeather.sunset:
        return PracticeShape.lotus;
      case AuraWeather.water:
      case AuraWeather.rain:
        return PracticeShape.torus;
      case AuraWeather.candle:
        return PracticeShape.pyramid;
      case AuraWeather.breath:
        return PracticeShape.sphere;
      case AuraWeather.fog:
        return PracticeShape.cube;
      case AuraWeather.aura:
      case AuraWeather.tropical:
      case AuraWeather.sakura:
      case AuraWeather.fireflies:
      case AuraWeather.incense:
        return PracticeShape.lotus;
      case AuraWeather.snow:
        return PracticeShape.sphere;
      case AuraWeather.ocean:
      case AuraWeather.fluid:
      case AuraWeather.waveFunc:
        return PracticeShape.torus;
      case AuraWeather.fractal:
      case AuraWeather.voronoi:
      case AuraWeather.inkDiffuse:
      case AuraWeather.starfield:
      case AuraWeather.nebula:
      case AuraWeather.blackHole:
      case AuraWeather.supernova:
      case AuraWeather.cyberpunk:
      case AuraWeather.neon:
      case AuraWeather.matrix:
      case AuraWeather.glitch:
      case AuraWeather.hologram:
      case AuraWeather.technoCivic:
        return PracticeShape.sphere;
    }
  }
}

class _AuraShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final AuraLivingScene scene;
  final double time;
  final double touchEnergy;
  final Offset lastTouch; // normalized 0..1

  const _AuraShaderPainter({
    required this.shader,
    required this.scene,
    required this.time,
    required this.touchEnergy,
    this.lastTouch = const Offset(0.5, 0.5),
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (scene.weather) {
      case AuraWeather.candle:
        shader.setFloat(0, size.width);
        shader.setFloat(1, size.height);
        shader.setFloat(2, time);
        shader.setFloat(3, touchEnergy);
        shader.setFloat(4, scene.depth.clamp(0.25, 1.0));
        break;
      case AuraWeather.breath:
        final cycle = (time / 7.2) % 1.0;
        final phase = cycle < 0.38
            ? 0.18
            : cycle < 0.56
                ? 0.50
                : 0.88;
        final progress = cycle < 0.38
            ? cycle / 0.38
            : cycle < 0.56
                ? 1.0
                : ((cycle - 0.56) / 0.44).clamp(0.0, 1.0);
        shader.setFloat(0, size.width);
        shader.setFloat(1, size.height);
        shader.setFloat(2, time);
        shader.setFloat(3, phase);
        shader.setFloat(4, progress);
        _setColor(shader, 5, scene.secondary);
        _setColor(shader, 8, scene.tertiary);
        shader.setFloat(11, scene.depth.clamp(0.25, 1.0));
        break;
      case AuraWeather.aura:
        // aura_theme.frag now has u_touch (vec2) + u_energy
        shader.setFloat(0, size.width);
        shader.setFloat(1, size.height);
        shader.setFloat(2, time);
        _setColor(shader, 3, scene.primary);
        _setColor(shader, 6, scene.secondary);
        shader.setFloat(9, scene.depth.clamp(0.25, 1.0));
        // touch position (normalized)
        shader.setFloat(10, lastTouch.dx.clamp(0.0, 1.0));
        shader.setFloat(11, lastTouch.dy.clamp(0.0, 1.0));
        shader.setFloat(12, touchEnergy);
        break;
      case AuraWeather.cosmos:
        shader.setFloat(0, size.width);
        shader.setFloat(1, size.height);
        shader.setFloat(2, time);
        _setColor(shader, 3, scene.primary);
        _setColor(shader, 6, scene.secondary);
        shader.setFloat(9, scene.depth.clamp(0.25, 1.0));
        shader.setFloat(10, lastTouch.dx.clamp(0.0, 1.0));
        shader.setFloat(11, lastTouch.dy.clamp(0.0, 1.0));
        shader.setFloat(12, touchEnergy);
        break;
      default:
        shader.setFloat(0, size.width);
        shader.setFloat(1, size.height);
        shader.setFloat(2, time);
        _setColor(shader, 3, scene.primary);
        _setColor(shader, 6, scene.secondary);
        shader.setFloat(9, scene.depth.clamp(0.25, 1.0));
        break;
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  static void _setColor(ui.FragmentShader shader, int index, Color color) {
    shader.setFloat(index, color.r);
    shader.setFloat(index + 1, color.g);
    shader.setFloat(index + 2, color.b);
  }

  @override
  bool shouldRepaint(covariant _AuraShaderPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.scene != scene ||
        oldDelegate.time != time ||
        oldDelegate.touchEnergy != touchEnergy ||
        oldDelegate.lastTouch != lastTouch;
  }
}

class _AuraFallbackPainter extends CustomPainter {
  final AuraLivingScene scene;
  final double time;
  final Offset gyro;
  final List<_AuraRipple> ripples;
  final double clock;
  final double secretBornAt;
  final Offset? fogTouch;
  final double touchEnergy;
  final bool showConstellationVeil;

  const _AuraFallbackPainter({
    required this.scene,
    required this.time,
    required this.gyro,
    required this.ripples,
    required this.clock,
    required this.secretBornAt,
    this.fogTouch,
    this.touchEnergy = 0,
    this.showConstellationVeil = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.48);
    final phase = time;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scene.primary.withValues(alpha: 0.14),
            const Color(0xFF020409).withValues(alpha: 0.18),
            scene.tertiary.withValues(alpha: 0.10),
          ],
        ).createShader(rect),
    );

    _drawBloomFields(canvas, size, phase);
    if (showConstellationVeil && scene.particleDensity > 0.04) {
      _drawConstellationVeil(canvas, size, phase);
    }
    _drawTouchFog(canvas, size, phase);
    _drawRipples(canvas, size);
    _drawSecretSeal(canvas, size, phase);
    _drawGrain(canvas, size, clock);
    _drawReadableVignette(canvas, size, center);
  }

  void _drawTouchFog(Canvas canvas, Size size, double phase) {
    final touch = fogTouch;
    if (touch == null || touchEnergy <= 0.01) return;
    final radius = size.shortestSide * (0.22 + touchEnergy * 0.26);
    final paint = Paint()
      ..color = scene.secondary.withValues(alpha: 0.055 * touchEnergy)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.26);
    final drift = Offset(
      math.sin(phase * 0.7) * radius * 0.08,
      math.cos(phase * 0.5) * radius * 0.06,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: touch + drift,
        width: radius * 1.65,
        height: radius * 0.92,
      ),
      paint,
    );
  }

  void _drawBloomFields(Canvas canvas, Size size, double phase) {
    final paint = Paint()..isAntiAlias = true;
    final colors = [scene.primary, scene.secondary, scene.tertiary];
    for (var i = 0; i < colors.length; i++) {
      final local = phase + i * math.pi * 2 / colors.length;
      final cx = size.width *
          (0.5 + math.sin(local * (0.7 + i * 0.12)) * 0.34 + gyro.dx * 0.04);
      final cy = size.height *
          (0.5 + math.cos(local * (0.55 + i * 0.10)) * 0.32 + gyro.dy * 0.04);
      final radius = size.shortestSide *
          (0.46 + scene.bloom * 0.34 + math.sin(local * 1.6) * 0.06);
      paint
        ..color = colors[i].withValues(alpha: 0.10 + scene.bloom * 0.11)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.28);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  void _drawConstellationVeil(Canvas canvas, Size size, double phase) {
    final count = (24 + scene.particleDensity * 64).round();
    final points = <Offset>[];
    final rng = math.Random(9001 + scene.weather.index * 17);
    final drift =
        Offset(gyro.dx * 22 * scene.depth, gyro.dy * 22 * scene.depth);

    for (var i = 0; i < count; i++) {
      final seedX = rng.nextDouble();
      final seedY = rng.nextDouble();
      final angle = phase * (0.18 + (i % 7) * 0.012) + i * 0.77;
      final p = Offset(
            seedX * size.width + math.sin(angle) * 22,
            seedY * size.height + math.cos(angle * 0.9) * 18,
          ) +
          drift;
      points.add(p);
    }

    final linePaint = Paint()
      ..color = scene.secondary.withValues(alpha: 0.035 + scene.depth * 0.035)
      ..strokeWidth = 0.55;
    for (var i = 0; i < points.length - 1; i++) {
      if (i % 3 == 0) {
        final a = points[i];
        final b = points[(i + 5).clamp(0, points.length - 1)];
        if ((a - b).distance < size.shortestSide * 0.34) {
          canvas.drawLine(a, b, linePaint);
        }
      }
    }

    for (var i = 0; i < points.length; i++) {
      final pulse = 0.5 + 0.5 * math.sin(phase * 2.2 + i);
      final color = Color.lerp(scene.primary, scene.secondary, pulse)!;
      canvas.drawCircle(
        points[i],
        0.8 + (i % 4) * 0.35 + scene.audioEnergy * 1.5,
        Paint()
          ..color = color.withValues(alpha: 0.12 + pulse * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  void _drawRipples(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      final age = (clock - ripple.bornAt).clamp(0.0, 2.1);
      final t = age / 2.1;
      final radius = size.shortestSide * (0.05 + t * 0.55);
      final alpha = (1.0 - t) * 0.20;
      canvas.drawCircle(
        ripple.position,
        radius,
        Paint()
          ..color = scene.secondary.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + t * 2.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        ripple.position,
        radius * 0.32,
        Paint()
          ..color = scene.primary.withValues(alpha: alpha * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  void _drawGrain(Canvas canvas, Size size, double clock) {
    final rng = math.Random(4100 + scene.weather.index * 97);
    final paint = Paint()
      ..color = const Color(0xFFEDE8DF).withValues(alpha: 0.009);
    for (var i = 0; i < 180; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height,
          1.0,
          1.0,
        ),
        paint,
      );
    }
  }

  void _drawSecretSeal(Canvas canvas, Size size, double phase) {
    final age = clock - secretBornAt;
    if (age < 0 || age > 6.2) {
      return;
    }
    final appear = age < 1.2 ? Curves.easeOutCubic.transform(age / 1.2) : 1.0;
    final fade = age > 4.6 ? (1.0 - ((age - 4.6) / 1.6)).clamp(0.0, 1.0) : 1.0;
    final alpha = appear * fade;
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.shortestSide * (0.18 + appear * 0.12);
    const nodeCount = 12;
    final points = <Offset>[];
    final rotation = phase * 0.16;
    for (var i = 0; i < nodeCount; i++) {
      final angle = rotation + math.pi * 2 * i / nodeCount;
      final pulse = 1.0 + math.sin(phase * 2.0 + i) * 0.055;
      points.add(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * pulse,
      );
    }

    final glowPaint = Paint()
      ..color = scene.secondary.withValues(alpha: 0.12 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(center, radius * 1.18, glowPaint);

    final linePaint = Paint()
      ..color = scene.secondary.withValues(alpha: 0.34 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    final accentPaint = Paint()
      ..color = scene.primary.withValues(alpha: 0.24 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (var i = 0; i < points.length; i++) {
      canvas.drawLine(points[i], points[(i + 5) % points.length], accentPaint);
      canvas.drawLine(points[i], points[(i + 1) % points.length], linePaint);
      canvas.drawCircle(
        points[i],
        2.2 + math.sin(phase * 2.4 + i) * 0.6,
        Paint()..color = scene.secondary.withValues(alpha: 0.72 * alpha),
      );
    }

    final inner = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + rotation * -1.4 + math.pi * 2 * i / 6;
      final p =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.45;
      i == 0 ? inner.moveTo(p.dx, p.dy) : inner.lineTo(p.dx, p.dy);
    }
    inner.close();
    canvas.drawPath(
      inner,
      Paint()
        ..color = scene.tertiary.withValues(alpha: 0.22 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawCircle(
      center,
      radius * 0.08,
      Paint()
        ..color = const Color(0xFFF7F1E8).withValues(alpha: 0.72 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _drawReadableVignette(Canvas canvas, Size size, Offset center) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.18),
          radius: 1.24,
          colors: [
            Colors.transparent,
            const Color(0xFF05070D).withValues(alpha: 0.18),
            const Color(0xFF010207).withValues(alpha: 0.66),
          ],
          stops: const [0.0, 0.64, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AuraFallbackPainter oldDelegate) {
    return oldDelegate.scene != scene ||
        oldDelegate.time != time ||
        oldDelegate.gyro != gyro ||
        oldDelegate.ripples != ripples ||
        oldDelegate.clock != clock ||
        oldDelegate.secretBornAt != secretBornAt ||
        oldDelegate.fogTouch != fogTouch ||
        oldDelegate.touchEnergy != touchEnergy ||
        oldDelegate.showConstellationVeil != showConstellationVeil;
  }
}

class _AuraRipple {
  final Offset position;
  final double bornAt;

  const _AuraRipple({
    required this.position,
    required this.bornAt,
  });
}

/// Ken Burns эффект для пользовательского фонового фото.
///
/// Медленный zoom (1.0 → 1.12 → 1.0) + плавный pan в течение ~30 сек.
/// Поверх фото идут шейдеры AuraLiving — сохраняют живой характер движка.
/// Поддерживает http(s) URL, asset-path и локальные file:// пути.
class _KenBurnsImage extends StatefulWidget {
  const _KenBurnsImage({required this.imageSrc});
  final String imageSrc;

  @override
  State<_KenBurnsImage> createState() => _KenBurnsImageState();
}

class _KenBurnsImageState extends State<_KenBurnsImage>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _zoom;
  late final Animation<Offset> _pan;

  @override
  void initState() {
    super.initState();
    // Цикл ~30 сек — медленный, не отвлекает.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);

    // Zoom 1.0 → 1.12 (мягкий, не агрессивный).
    _zoom = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));

    // Pan от центра к краю и обратно.
    _pan = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.04, -0.03),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    final src = widget.imageSrc;

    if (src.startsWith('file://')) {
      imageWidget = Image.file(
        File(src.replaceFirst('file://', '')),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (src.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => const ColoredBox(color: Colors.black),
        errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    } else {
      // asset path
      imageWidget = Image.asset(
        src,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.scale(
          scale: _zoom.value,
          child: FractionalTranslation(
            translation: _pan.value,
            child: child,
          ),
        );
      },
      child: imageWidget,
    );
  }
}
