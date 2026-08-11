// lib/widgets/weather_effects_overlay.dart
//
// Движок спецэффектов погоды — ParticleSystem поверх любого экрана.
//
// Поддерживаемые эффекты:
//   • rain     — дождь (наклонные капли, брызги);
//   • snow     — снег (кружащиеся снежинки, разный размер);
//   • fog      — туман (полупрозрачные градиентные слои, дрейф);
//   • clear    — солнце (лучи + блики, лёгкое мерцание);
//   • storm    — гроза (молнии + усиленный дождь);
//   • clouds   — облака (медленный дрейф полупрозрачных пятен).
//
// Реализация: CustomPainter + AnimationController(60 FPS).
// Все частицы заранее сгенерированы в списке, painter только отрисовывает —
// это позволяет держать 60 FPS даже на бюджетных устройствах.
//
// NEW (запрос пользователя): экран погоды со спецэффектами погоды.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Тип погодного эффекта.
enum WeatherEffect {
  clear,
  clouds,
  fog,
  rain,
  heavyRain,
  snow,
  storm,
  thunderstorm,
  sakura,
  fireflies,
  cosmos,
  technoCivic,
  aurora,
  hail,
  windGust,
}

/// Преобразовать kind из CityWeatherSnapshot в WeatherEffect.
WeatherEffect weatherEffectFromKind(String kind) {
  final k = kind.toLowerCase();
  if (k.contains('thunder') || k.contains('гроз') || k.contains('storm')) {
    return WeatherEffect.thunderstorm;
  }
  if (k.contains('storm')) return WeatherEffect.storm;
  if (k.contains('heavy_rain') || k.contains('ливень')) return WeatherEffect.heavyRain;
  if (k.contains('rain') || k.contains('дожд')) return WeatherEffect.rain;
  if (k.contains('hail') || k.contains('град')) return WeatherEffect.hail;
  if (k.contains('snow') || k.contains('снег')) return WeatherEffect.snow;
  if (k.contains('fog') || k.contains('туман')) return WeatherEffect.fog;
  if (k.contains('aurora') || k.contains('сиян')) return WeatherEffect.aurora;
  if (k.contains('clear') || k.contains('ясн')) return WeatherEffect.clear;
  return WeatherEffect.clouds;
}

/// Полноэкранный оверлей спецэффектов погоды.
/// Используется как фон экрана погоды. Поверх кладётся контент.
class WeatherEffectsOverlay extends StatefulWidget {
  const WeatherEffectsOverlay({
    super.key,
    required this.effect,
    this.isDay = true,
    this.intensity = 1.0,
    this.showBackground = true,
    this.child,
  });

  final WeatherEffect effect;
  final bool isDay;
  final bool showBackground;

  /// Множитель количества частиц (0.5 — меньше, 2.0 — плотнее).
  final double intensity;

  /// Контент поверх эффектов.
  final Widget? child;

  @override
  State<WeatherEffectsOverlay> createState() => _WeatherEffectsOverlayState();
}

class _WeatherEffectsOverlayState extends State<WeatherEffectsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  late final Random _rng;
  Size _size = Size.zero;
  DateTime _lastFlash = DateTime.fromMillisecondsSinceEpoch(0);
  bool _flashActive = false;
  // Fractal lightning bolt segments
  List<Offset> _lightningBolt = [];
  double _lightningAlpha = 0.0;

  @override
  void initState() {
    super.initState();
    _rng = math.Random();
    _particles = [];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _controller.addListener(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _size = MediaQuery.sizeOf(context);
    _seedParticles();
  }

  @override
  void didUpdateWidget(covariant WeatherEffectsOverlay old) {
    super.didUpdateWidget(old);
    if (old.effect != widget.effect || old.intensity != widget.intensity) {
      _seedParticles();
    }
  }

  void _seedParticles() {
    _particles.clear();
    if (_size == Size.zero) return;
    final area = _size.width * _size.height;
    final intensity = widget.intensity.clamp(0.2, 3.0);

    switch (widget.effect) {
      case WeatherEffect.rain:
        final count = (area / 6000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -1.5 * intensity,
            vy: 12 * intensity + _rng.nextDouble() * 4,
            size: 1.0 + _rng.nextDouble() * 1.5,
          ));
        }
        break;
      case WeatherEffect.heavyRain:
        final count = (area / 3000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -3 * intensity,
            vy: 18 * intensity + _rng.nextDouble() * 6,
            size: 1.2 + _rng.nextDouble() * 2,
          ));
        }
        break;
      case WeatherEffect.snow:
        final count = (area / 12000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: (_rng.nextDouble() - 0.5) * 1.2,
            vy: 1.0 + _rng.nextDouble() * 1.8,
            size: 2 + _rng.nextDouble() * 4,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.02 + _rng.nextDouble() * 0.03,
          ));
        }
        break;
      case WeatherEffect.storm:
      case WeatherEffect.thunderstorm:
        // Дождь + редкие молнии (молнии рендерятся отдельно в _tick).
        final count = (area / 2500 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -4 * intensity,
            vy: 20 * intensity + _rng.nextDouble() * 8,
            size: 1.5 + _rng.nextDouble() * 2,
          ));
        }
        break;
      case WeatherEffect.fog:
        final count = (area / 40000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: 0.3 + _rng.nextDouble() * 0.5,
            vy: 0,
            size: 80 + _rng.nextDouble() * 120,
            alpha: 0.04 + _rng.nextDouble() * 0.08,
          ));
        }
        break;
      case WeatherEffect.clouds:
        final count = (area / 60000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height * 0.5,
            vx: 0.2 + _rng.nextDouble() * 0.4,
            vy: 0,
            size: 100 + _rng.nextDouble() * 180,
            alpha: 0.05 + _rng.nextDouble() * 0.1,
          ));
        }
        break;
      case WeatherEffect.clear:
        // Лучи солнца рисуются статично в painter, частицы не нужны.
        break;
      case WeatherEffect.sakura:
        final count = (area / 15000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -0.8 - _rng.nextDouble() * 0.8,
            vy: 1.0 + _rng.nextDouble() * 1.5,
            size: 6.0 + _rng.nextDouble() * 6.0,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.02 + _rng.nextDouble() * 0.04,
          ));
        }
        break;
      case WeatherEffect.fireflies:
        final count = (area / 18000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: (_rng.nextDouble() - 0.5) * 0.6,
            vy: (_rng.nextDouble() - 0.5) * 0.6,
            size: 3.5 + _rng.nextDouble() * 4.0,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.02 + _rng.nextDouble() * 0.03,
          ));
        }
        break;
      case WeatherEffect.cosmos:
        final count = (area / 8000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: 0,
            vy: 0.05 + _rng.nextDouble() * 0.15,
            size: 1.2 + _rng.nextDouble() * 2.5,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.04 + _rng.nextDouble() * 0.06,
          ));
        }
        break;
      case WeatherEffect.technoCivic:
        final count = (area / 12000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: (_rng.nextDouble() - 0.5) * 0.5,
            vy: (_rng.nextDouble() - 0.5) * 0.5,
            size: 2.5 + _rng.nextDouble() * 3.5,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.015 + _rng.nextDouble() * 0.02,
          ));
        }
        break;
      case WeatherEffect.aurora:
        // Aurora borealis shimmer bands
        final count = (area / 20000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _size.height * 0.1 + _rng.nextDouble() * _size.height * 0.35,
            vx: 0.15 + _rng.nextDouble() * 0.25,
            vy: (_rng.nextDouble() - 0.5) * 0.08,
            size: 60 + _rng.nextDouble() * 120,
            alpha: 0.03 + _rng.nextDouble() * 0.06,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.008 + _rng.nextDouble() * 0.012,
          ));
        }
        break;
      case WeatherEffect.hail:
        // Hail: white bouncing orbs + rain streaks
        final hailCount = (area / 10000 * intensity).round();
        final rainCount = (area / 5000 * intensity).round();
        for (var i = 0; i < hailCount; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -2.0 * intensity + _rng.nextDouble() * 1.0,
            vy: 10 * intensity + _rng.nextDouble() * 8,
            size: 3.0 + _rng.nextDouble() * 4.0,
            wobble: 0, // 0 = hail particle marker
          ));
        }
        for (var i = 0; i < rainCount; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -2.5 * intensity,
            vy: 14 * intensity + _rng.nextDouble() * 4,
            size: 1.0 + _rng.nextDouble() * 1.0,
            wobble: 1, // 1 = rain particle marker
          ));
        }
        break;
      case WeatherEffect.windGust:
        // Horizontal speed-lines + dust
        final count = (area / 6000 * intensity).round();
        for (var i = 0; i < count; i++) {
          final isHorizontal = _rng.nextDouble() > 0.35;
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: isHorizontal ? (8 + _rng.nextDouble() * 12) * intensity : (_rng.nextDouble() - 0.5) * 1.5,
            vy: isHorizontal ? (_rng.nextDouble() - 0.5) * 0.8 : (0.3 + _rng.nextDouble() * 0.6),
            size: isHorizontal ? (1.0 + _rng.nextDouble() * 1.5) : (1.5 + _rng.nextDouble() * 3.0),
            alpha: isHorizontal ? (0.2 + _rng.nextDouble() * 0.35) : (0.15 + _rng.nextDouble() * 0.2),
          ));
        }
        break;
    }
  }

  void _tick() {
    if (!_controller.isAnimating) return;
    for (final p in _particles) {
      if (widget.effect == WeatherEffect.fireflies || widget.effect == WeatherEffect.technoCivic) {
        p.vx += (_rng.nextDouble() - 0.5) * 0.06;
        p.vy += (_rng.nextDouble() - 0.5) * 0.06;
        p.vx = p.vx.clamp(-0.8, 0.8);
        p.vy = p.vy.clamp(-0.8, 0.8);
      }
      p.x += p.vx;
      p.y += p.vy;
      if (p.wobbleSpeed > 0) {
        p.wobble += p.wobbleSpeed;
        p.x += math.sin(p.wobble) * 0.6;
      }
      // Wrap-around.
      if (p.y > _size.height + 20) {
        p.y = -20;
        p.x = _rng.nextDouble() * _size.width;
      }
      if (p.x < -p.size) {
        p.x = _size.width + p.size;
      } else if (p.x > _size.width + p.size) {
        p.x = -p.size;
      }
    }

    // Fractal lightning for storm/thunderstorm.
    if (widget.effect == WeatherEffect.thunderstorm ||
        widget.effect == WeatherEffect.storm) {
      final now = DateTime.now();
      final since = now.difference(_lastFlash).inMilliseconds;
      if (_flashActive && since > 180) {
        _flashActive = false;
        _lightningAlpha = 0.0;
        _lastFlash = now;
      } else if (!_flashActive && since > 2500 && _rng.nextDouble() < 0.025) {
        _flashActive = true;
        _lastFlash = now;
        _lightningAlpha = 1.0;
        // Generate fractal lightning bolt
        _lightningBolt = _generateFractalLightning(
          Offset(_rng.nextDouble() * _size.width, 0),
          Offset(_rng.nextDouble() * _size.width, _size.height * (0.5 + _rng.nextDouble() * 0.4)),
          6, // depth
        );
      } else if (_flashActive) {
        _lightningAlpha = (1.0 - since / 180.0).clamp(0.0, 1.0);
      }
    }

    setState(() {});
  }
  /// Generate fractal lightning bolt using midpoint displacement
  List<Offset> _generateFractalLightning(Offset start, Offset end, int depth) {
    if (depth <= 0) return [start, end];
    final mid = Offset(
      (start.dx + end.dx) / 2 + (_rng.nextDouble() - 0.5) * (end.dy - start.dy) * 0.3,
      (start.dy + end.dy) / 2 + (_rng.nextDouble() - 0.5) * 20,
    );
    final left = _generateFractalLightning(start, mid, depth - 1);
    final right = _generateFractalLightning(mid, end, depth - 1);
    return [...left, ...right.skip(1)];
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Градиент-фон неба.
        if (widget.showBackground)
          Container(
            decoration: BoxDecoration(
              gradient: _skyGradient(),
            ),
          ),
        // Атмосферный фоновый слой
        Positioned.fill(
          child: CustomPaint(
            painter: _AmbientAtmospherePainter(
              isDay: widget.isDay,
              effect: widget.effect,
              animProgress: _controller.value,
            ),
          ),
        ),
        // Солнце/луна для ясной погоды.
        if (widget.effect == WeatherEffect.clear)
          Positioned(
            top: _size.height * 0.08,
            right: _size.width * 0.12,
            child: _SunMoon(isDay: widget.isDay),
          ),
        // Слой частиц.
        Positioned.fill(
          child: CustomPaint(
            painter: _WeatherPainter(
              particles: _particles,
              effect: widget.effect,
              flash: _flashActive,
              isDay: widget.isDay,
              lightningBolt: _lightningBolt,
              lightningAlpha: _lightningAlpha,
            ),
          ),
        ),
        // Контент поверх.
        if (widget.child != null) widget.child!,
      ],
    );
  }

  LinearGradient _skyGradient() {
    final isDay = widget.isDay;
    switch (widget.effect) {
      case WeatherEffect.clear:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF4A90D9), const Color(0xFF87CEEB), const Color(0xFFB8E0F6)]
              : [const Color(0xFF0B1026), const Color(0xFF1A1F3A), const Color(0xFF2C3E5A)],
        );
      case WeatherEffect.clouds:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF6B7B8C), const Color(0xFF95A5B5), const Color(0xFFB0C0D0)]
              : [const Color(0xFF1C2333), const Color(0xFF2D3848), const Color(0xFF3A4A5C)],
        );
      case WeatherEffect.fog:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF9CA8B5), const Color(0xFFB5BFC9), const Color(0xFFCED5DC)]
              : [const Color(0xFF2A3038), const Color(0xFF383F47), const Color(0xFF454D55)],
        );
      case WeatherEffect.rain:
      case WeatherEffect.heavyRain:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF4A5568), const Color(0xFF606E82), const Color(0xFF7B8A9E)]
              : [const Color(0xFF141A24), const Color(0xFF1F2632), const Color(0xFF2A3340)],
        );
      case WeatherEffect.snow:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF8FA8C2), const Color(0xFFB0C4DE), const Color(0xFFD6E4F0)]
              : [const Color(0xFF1A2438), const Color(0xFF2B3850), const Color(0xFF3D4D68)],
        );
      case WeatherEffect.storm:
      case WeatherEffect.thunderstorm:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF2D3748), const Color(0xFF3B4759), const Color(0xFF4E5B6F)]
              : [const Color(0xFF0A0E16), const Color(0xFF161B26), const Color(0xFF222934)],
        );
      case WeatherEffect.sakura:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFFFFF0F5), const Color(0xFFFFD1DC)]
              : [const Color(0xFF1A0F24), const Color(0xFF32143F)],
        );
      case WeatherEffect.fireflies:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF14241C), const Color(0xFF1F382B)]
              : [const Color(0xFF030708), const Color(0xFF0D1B2A)],
        );
      case WeatherEffect.cosmos:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF020208), const Color(0xFF0F0A1E)],
        );
      case WeatherEffect.technoCivic:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050811), const Color(0xFF0E1A2F)],
        );
      case WeatherEffect.aurora:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF000428), const Color(0xFF004E40), const Color(0xFF000428)],
        );
      case WeatherEffect.hail:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF3B4859), const Color(0xFF536878), const Color(0xFF6E8098)]
              : [const Color(0xFF0D1117), const Color(0xFF161B26), const Color(0xFF222934)],
        );
      case WeatherEffect.windGust:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF5B7083), const Color(0xFF8BA0B0), const Color(0xFFB5C8D8)]
              : [const Color(0xFF1A2030), const Color(0xFF2A3545), const Color(0xFF3C4D5E)],
        );
    }
  }
}

/// Частица эффекта.
class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    this.alpha = 1.0,
    this.wobble = 0,
    this.wobbleSpeed = 0,
  });

  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  double wobble;
  double wobbleSpeed;
}

typedef Random = math.Random;

/// Солнце/Луна для ясной погоды — с мягким свечением.
class _SunMoon extends StatelessWidget {
  const _SunMoon({required this.isDay});
  final bool isDay;

  @override
  Widget build(BuildContext context) {
    final coreColor = isDay ? const Color(0xFFFFD54F) : const Color(0xFFE0E0E0);
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: coreColor,
        boxShadow: [
          BoxShadow(
            color: coreColor.withOpacity(0.6),
            blurRadius: 50,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

/// Painter, отрисовывающий частицы по типу эффекта.
class _WeatherPainter extends CustomPainter {
  const _WeatherPainter({
    required this.particles,
    required this.effect,
    required this.flash,
    required this.isDay,
    this.lightningBolt = const [],
    this.lightningAlpha = 0.0,
  });

  final List<_Particle> particles;
  final WeatherEffect effect;
  final bool flash;
  final bool isDay;
  final List<Offset> lightningBolt;
  final double lightningAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    // Молния: вспышка фона + fractal bolt
    if (flash) {
      final flashPaint = Paint()..color = Colors.white.withOpacity(0.35 * lightningAlpha);
      canvas.drawRect(Offset.zero & size, flashPaint);
      
      // Draw fractal lightning bolt
      if (lightningBolt.length >= 2 && lightningAlpha > 0.1) {
        // Main bolt
        final boltPaint = Paint()
          ..color = Colors.white.withOpacity(0.95 * lightningAlpha)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final boltPath = Path()..moveTo(lightningBolt.first.dx, lightningBolt.first.dy);
        for (final pt in lightningBolt.skip(1)) {
          boltPath.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(boltPath, boltPaint);
        
        // Glow around bolt
        final glowPaint = Paint()
          ..color = const Color(0xFF80D8FF).withOpacity(0.4 * lightningAlpha)
          ..strokeWidth = 8.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawPath(boltPath, glowPaint);
        
        // Outer bloom
        final bloomPaint = Paint()
          ..color = const Color(0xFFB3E5FC).withOpacity(0.15 * lightningAlpha)
          ..strokeWidth = 18.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
        canvas.drawPath(boltPath, bloomPaint);
      }
    }

    for (final p in particles) {
      switch (effect) {
        case WeatherEffect.rain:
        case WeatherEffect.heavyRain:
        case WeatherEffect.storm:
        case WeatherEffect.thunderstorm:
          final paint = Paint()
            ..color = isDay
                ? Colors.white.withOpacity(0.5)
                : Colors.lightBlueAccent.withOpacity(0.4)
            ..strokeWidth = p.size
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(p.x, p.y),
            Offset(p.x - p.vx * 2, p.y - p.vy * 1.2),
            paint,
          );
          break;
        case WeatherEffect.snow:
          final paint = Paint()
            ..color = Colors.white.withOpacity(0.9)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
          break;
        case WeatherEffect.fog:
          final paint = Paint()
            ..color = (isDay ? Colors.white : Colors.grey.shade300)
                .withOpacity(p.alpha);
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
          break;
        case WeatherEffect.clouds:
          final paint = Paint()
            ..color = Colors.white.withOpacity(p.alpha);
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(p.x, p.y),
                width: p.size * 1.6,
                height: p.size),
            paint,
          );
          break;
        case WeatherEffect.clear:
          break; // солнце рисуется виджетом, не частицами
        case WeatherEffect.sakura:
          final paint = Paint()
            ..color = const Color(0xFFFFB7C5).withOpacity(0.8)
            ..style = PaintingStyle.fill;
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.wobble); // rotate based on wobble phase
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint,
          );
          canvas.restore();
          break;
        case WeatherEffect.fireflies:
          final intensityVal = (0.3 + 0.7 * math.sin(p.wobble)).clamp(0.0, 1.0);
          final paint = Paint()
            ..color = const Color(0xFFCCFF00).withOpacity(0.5 * intensityVal)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.4);
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
          // Central core
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size * 0.35,
            Paint()..color = Colors.white.withOpacity(0.95 * intensityVal),
          );
          break;
        case WeatherEffect.cosmos:
          final intensityVal = (0.2 + 0.8 * math.sin(p.wobble)).clamp(0.0, 1.0);
          final color = (p.size > 2.2) 
              ? (p.wobbleSpeed > 0.05 ? const Color(0xFF00FFFF) : const Color(0xFFFF00FF)) 
              : Colors.white;
          final paint = Paint()
            ..color = color.withOpacity(intensityVal)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(p.x, p.y), p.size * 0.8, paint);
          // Large star flare
          if (p.size > 2.2 && intensityVal > 0.7) {
            final linePaint = Paint()
              ..color = color.withOpacity(0.3)
              ..strokeWidth = 0.5;
            canvas.drawLine(Offset(p.x - 4, p.y), Offset(p.x + 4, p.y), linePaint);
            canvas.drawLine(Offset(p.x, p.y - 4), Offset(p.x, p.y + 4), linePaint);
          }
          break;
        case WeatherEffect.technoCivic:
          final paint = Paint()
            ..color = const Color(0xFF00E5FF).withOpacity(0.6)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(p.x, p.y), p.size * 0.6, paint);
          // Connect to nearby nodes
          for (final other in particles) {
            if (other != p && other.x > p.x) {
              final distSq = (p.x - other.x) * (p.x - other.x) + (p.y - other.y) * (p.y - other.y);
              if (distSq < 3600) {
                final dist = math.sqrt(distSq);
                final alpha = (1.0 - dist / 60.0) * 0.15;
                canvas.drawLine(
                  Offset(p.x, p.y),
                  Offset(other.x, other.y),
                  Paint()
                    ..color = const Color(0xFF00E5FF).withOpacity(alpha)
                    ..strokeWidth = 0.5,
                );
              }
            }
          }
          break;
        case WeatherEffect.aurora:
          // Aurora borealis: translucent gradient bands with wave distortion
          final waveY = math.sin(p.wobble) * 15.0;
          final auroraGreen = Color.lerp(
            const Color(0xFF00FF87),
            const Color(0xFF00BFFF),
            (math.sin(p.wobble * 0.7) * 0.5 + 0.5),
          )!;
          final aurPaint = Paint()
            ..color = auroraGreen.withOpacity(p.alpha * (0.6 + 0.4 * math.sin(p.wobble)))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.3);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(p.x, p.y + waveY),
              width: p.size * 2.2,
              height: p.size * 0.35,
            ),
            aurPaint,
          );
          break;
        case WeatherEffect.hail:
          if (p.wobble == 0) {
            // Hail stone: white sphere with specular highlight
            final hailPaint = Paint()
              ..shader = RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  const Color(0xFFB0D4F1).withOpacity(0.7),
                  const Color(0xFF7EB3D4).withOpacity(0.4),
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(Rect.fromCircle(center: Offset(p.x, p.y), radius: p.size));
            canvas.drawCircle(Offset(p.x, p.y), p.size, hailPaint);
            // Specular dot
            canvas.drawCircle(
              Offset(p.x - p.size * 0.25, p.y - p.size * 0.25),
              p.size * 0.2,
              Paint()..color = Colors.white.withOpacity(0.9),
            );
          } else {
            // Rain streak alongside hail
            final rPaint = Paint()
              ..color = Colors.lightBlueAccent.withOpacity(0.35)
              ..strokeWidth = p.size
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(
              Offset(p.x, p.y),
              Offset(p.x - p.vx * 1.5, p.y - p.vy * 1.0),
              rPaint,
            );
          }
          break;
        case WeatherEffect.windGust:
          // Horizontal speed lines
          if (p.vx.abs() > 3) {
            final lineLen = p.vx.abs() * 1.8;
            final windPaint = Paint()
              ..color = (isDay ? Colors.white : const Color(0xFF80D8FF)).withOpacity(p.alpha)
              ..strokeWidth = p.size * 0.5
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(
              Offset(p.x, p.y),
              Offset(p.x - lineLen, p.y),
              windPaint,
            );
          } else {
            // Dust/debris particle
            final dustPaint = Paint()
              ..color = (isDay ? const Color(0xFFD4A76A) : const Color(0xFF8B7355)).withOpacity(p.alpha)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(Offset(p.x, p.y), p.size, dustPaint);
          }
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) => true;
}

class _AmbientAtmospherePainter extends CustomPainter {
  const _AmbientAtmospherePainter({
    required this.isDay,
    required this.effect,
    required this.animProgress,
  });

  final bool isDay;
  final WeatherEffect effect;
  final double animProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final hour = now.hour;

    if (isDay && (effect == WeatherEffect.clear || effect == WeatherEffect.clouds)) {
      // 1. Day Sunbeams / Sunburst rotating light shafts
      final sunOrigin = Offset(size.width * 0.85, size.height * 0.12);
      final rayCount = 8;
      final rayPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE082).withOpacity(0.18),
            const Color(0xFFFFD54F).withOpacity(0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: sunOrigin, radius: size.height * 0.8));

      canvas.save();
      canvas.translate(sunOrigin.dx, sunOrigin.dy);
      canvas.rotate(animProgress * 2 * math.pi * 0.05);

      for (int i = 0; i < rayCount; i++) {
        final angle = (i * 2 * math.pi) / rayCount;
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(math.cos(angle - 0.15) * size.height * 0.9, math.sin(angle - 0.15) * size.height * 0.9)
          ..lineTo(math.cos(angle + 0.15) * size.height * 0.9, math.sin(angle + 0.15) * size.height * 0.9)
          ..close();
        canvas.drawPath(path, rayPaint);
      }
      canvas.restore();
    } else if (hour >= 17 && hour < 22) {
      // 2. Twilight Sunset / Evening Glow with warm ember particles
      final twilightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFF7043).withOpacity(0.25),
            const Color(0xFFAB47BC).withOpacity(0.15),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), twilightPaint);
    } else if (!isDay) {
      // 3. Night Starfield Constellations with twinkling stars
      final rng = math.Random(1337);
      for (int i = 0; i < 40; i++) {
        final sx = rng.nextDouble() * size.width;
        final sy = rng.nextDouble() * (size.height * 0.65);
        final starSize = 0.8 + rng.nextDouble() * 1.6;
        final twinkle = 0.3 + 0.7 * math.sin((animProgress * 2 * math.pi * (1.0 + rng.nextDouble())) + i);
        
        final starPaint = Paint()
          ..color = (i % 5 == 0 ? const Color(0xFF80D8FF) : Colors.white).withOpacity(twinkle.clamp(0.1, 0.95))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(sx, sy), starSize, starPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientAtmospherePainter oldDelegate) =>
      oldDelegate.animProgress != animProgress || oldDelegate.isDay != isDay || oldDelegate.effect != effect;
}

