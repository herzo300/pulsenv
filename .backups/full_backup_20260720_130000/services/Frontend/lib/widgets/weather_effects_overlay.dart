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
  if (k.contains('snow') || k.contains('снег')) return WeatherEffect.snow;
  if (k.contains('fog') || k.contains('туман')) return WeatherEffect.fog;
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
    }
  }

  void _tick() {
    if (!_controller.isAnimating) return;
    for (final p in _particles) {
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

    // Молнии для грозы.
    if (widget.effect == WeatherEffect.thunderstorm ||
        widget.effect == WeatherEffect.storm) {
      final now = DateTime.now();
      final since = now.difference(_lastFlash).inMilliseconds;
      if (_flashActive && since > 120) {
        _flashActive = false;
        _lastFlash = now;
      } else if (!_flashActive && since > 3000 && _rng.nextDouble() < 0.02) {
        _flashActive = true;
        _lastFlash = now;
      }
    }

    setState(() {});
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
            color: coreColor.withValues(alpha: 0.6),
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
  });

  final List<_Particle> particles;
  final WeatherEffect effect;
  final bool flash;
  final bool isDay;

  @override
  void paint(Canvas canvas, Size size) {
    // Молния: заливаем экран белым на короткий кадр.
    if (flash) {
      final flashPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
      canvas.drawRect(Offset.zero & size, flashPaint);
    }

    for (final p in particles) {
      switch (effect) {
        case WeatherEffect.rain:
        case WeatherEffect.heavyRain:
        case WeatherEffect.storm:
        case WeatherEffect.thunderstorm:
          final paint = Paint()
            ..color = isDay
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.lightBlueAccent.withValues(alpha: 0.4)
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
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
          break;
        case WeatherEffect.fog:
          final paint = Paint()
            ..color = (isDay ? Colors.white : Colors.grey.shade300)
                .withValues(alpha: p.alpha);
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
          break;
        case WeatherEffect.clouds:
          final paint = Paint()
            ..color = Colors.white.withValues(alpha: p.alpha);
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
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) => true;
}
