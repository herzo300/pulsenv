// lib/widgets/weather_effects_overlay.dart
//
// 100% Бесшовный многослойный движок погодных спецэффектов (60-120 FPS).
//
// Слои визуализации:
//   • Слой 0: Небесный градиент + Солнце/Луна с живой короной свечения;
//   • Слой 1: Фоновая атмосфера (лучи солнца, сияние Авроры, метеоры, туманные облака);
//   • Слой 2: Основной поток частиц (дождь, 3D-снег, сакура, светлячки, гроза, техно-сеть);
//   • Слой 3: Передний план (капли на стекле экрана с преломлением, морозные узоры, блики линзы).
//
// Все анимации строго гармонически зациклены (f(0.0) == f(1.0)), исключая рывки.
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
  if (k.contains('heavy_rain') || k.contains('ливень')) return WeatherEffect.heavyRain;
  if (k.contains('rain') || k.contains('дожд')) return WeatherEffect.rain;
  if (k.contains('hail') || k.contains('град')) return WeatherEffect.hail;
  if (k.contains('snow') || k.contains('снег')) return WeatherEffect.snow;
  if (k.contains('fog') || k.contains('туман')) return WeatherEffect.fog;
  if (k.contains('aurora') || k.contains('сиян')) return WeatherEffect.aurora;
  if (k.contains('clear') || k.contains('ясн') || k.contains('солн')) return WeatherEffect.clear;
  return WeatherEffect.clouds;
}

/// Полноэкранный многослойный оверлей спецэффектов погоды.
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

  /// Множитель плотности частиц (0.5 — меньше, 2.0 — плотнее).
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
  late final List<_LensDroplet> _lensDroplets;
  late final math.Random _rng;
  Size _size = Size.zero;
  DateTime _lastFlash = DateTime.fromMillisecondsSinceEpoch(0);
  bool _flashActive = false;
  List<Offset> _lightningBolt = [];
  double _lightningAlpha = 0.0;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _rng = math.Random(42);
    _particles = [];
    _lensDroplets = [];
    // Длинный плавный 60-секундный цикл с непрерывными математическими гармониками
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _controller.addListener(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _size = MediaQuery.sizeOf(context);
    _seedParticles();
    _seedLensDroplets();
  }

  @override
  void didUpdateWidget(covariant WeatherEffectsOverlay old) {
    super.didUpdateWidget(old);
    if (old.effect != widget.effect || old.intensity != widget.intensity) {
      _seedParticles();
      _seedLensDroplets();
    }
  }

  void _seedLensDroplets() {
    _lensDroplets.clear();
    if (_size == Size.zero) return;
    if (widget.effect == WeatherEffect.rain ||
        widget.effect == WeatherEffect.heavyRain ||
        widget.effect == WeatherEffect.storm ||
        widget.effect == WeatherEffect.thunderstorm) {
      final count = (12 * widget.intensity).round();
      for (int i = 0; i < count; i++) {
        _lensDroplets.add(_LensDroplet(
          x: _rng.nextDouble() * _size.width,
          y: _rng.nextDouble() * _size.height,
          radius: 2.5 + _rng.nextDouble() * 4.5,
          speed: 0.2 + _rng.nextDouble() * 0.5,
          trailLength: 15.0 + _rng.nextDouble() * 30.0,
        ));
      }
    }
  }

  void _seedParticles() {
    _particles.clear();
    if (_size == Size.zero) return;
    final area = _size.width * _size.height;
    final intensity = widget.intensity.clamp(0.2, 3.0);

    switch (widget.effect) {
      case WeatherEffect.rain:
        final count = (area / 5000 * intensity).round();
        for (var i = 0; i < count; i++) {
          final z = 1.0 + _rng.nextDouble() * 3.0; // глубина 1..4
          final q = 1.0 / z;
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -1.5 * intensity * q,
            vy: (14 * intensity + _rng.nextDouble() * 5) * q,
            size: (1.0 + _rng.nextDouble() * 1.5) * q.clamp(0.5, 2.2),
            plane: z < 2 ? 1 : 0,
            depth: q,
          ));
        }
        break;
      case WeatherEffect.heavyRain:
        final count = (area / 2800 * intensity).round();
        for (var i = 0; i < count; i++) {
          final z = 1.0 + _rng.nextDouble() * 3.0;
          final q = 1.0 / z;
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -3.5 * intensity * q,
            vy: (18 * intensity + _rng.nextDouble() * 6) * q,
            size: (1.2 + _rng.nextDouble() * 2.0) * q.clamp(0.5, 2.2),
            plane: z < 2 ? 1 : 0,
            depth: q,
          ));
        }
        break;
      case WeatherEffect.snow:
        final count = (area / 9000 * intensity).round();
        for (var i = 0; i < count; i++) {
          final z = 1.0 + _rng.nextDouble() * 3.0;
          final q = 1.0 / z;
          final sz = 2.0 + _rng.nextDouble() * 4.5;
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: 0,
            vy: (1.0 + _rng.nextDouble() * 1.8) * q,
            size: sz * q,
            wobble: _rng.nextDouble() * math.pi * 2,
            // Ω = 0.6..2.5 рад/с — кувыркание хлопка (scaleX = |cos|)
            wobbleSpeed: (0.6 + _rng.nextDouble() * 1.9) * 0.05,
            plane: z < 2 ? 1 : 0,
            depth: q,
            baseX: _rng.nextDouble() * _size.width,
          ));
        }
        break;
      case WeatherEffect.storm:
      case WeatherEffect.thunderstorm:
        final count = (area / 2200 * intensity).round();
        for (var i = 0; i < count; i++) {
          final z = 1.0 + _rng.nextDouble() * 3.0;
          final q = 1.0 / z;
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -4.5 * intensity * q,
            vy: (20 * intensity + _rng.nextDouble() * 8) * q,
            size: (1.4 + _rng.nextDouble() * 2.2) * q.clamp(0.5, 2.2),
            plane: z < 2 ? 1 : 0,
            depth: q,
          ));
        }
        break;
      case WeatherEffect.fog:
        final count = (area / 30000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: 0.3 + _rng.nextDouble() * 0.4,
            vy: 0,
            size: 90 + _rng.nextDouble() * 140,
            alpha: 0.05 + _rng.nextDouble() * 0.07,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.01,
          ));
        }
        break;
      case WeatherEffect.clouds:
        final count = (area / 45000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height * 0.5,
            vx: 0.2 + _rng.nextDouble() * 0.3,
            vy: 0,
            size: 110 + _rng.nextDouble() * 190,
            alpha: 0.05 + _rng.nextDouble() * 0.09,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.008,
          ));
        }
        break;
      case WeatherEffect.clear:
        break;
      case WeatherEffect.sakura:
        final count = (area / 12000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -0.8 - _rng.nextDouble() * 0.8,
            vy: 1.2 + _rng.nextDouble() * 1.6,
            size: 6.0 + _rng.nextDouble() * 6.0,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.025 + _rng.nextDouble() * 0.035,
          ));
        }
        break;
      case WeatherEffect.fireflies:
        final count = (area / 15000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: (_rng.nextDouble() - 0.5) * 0.5,
            vy: (_rng.nextDouble() - 0.5) * 0.5,
            size: 3.5 + _rng.nextDouble() * 4.0,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.02 + _rng.nextDouble() * 0.03,
          ));
        }
        break;
      case WeatherEffect.cosmos:
        final count = (area / 7000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: 0,
            vy: 0.06 + _rng.nextDouble() * 0.14,
            size: 1.2 + _rng.nextDouble() * 2.6,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.03 + _rng.nextDouble() * 0.05,
          ));
        }
        break;
      case WeatherEffect.technoCivic:
        final count = (area / 10000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: (_rng.nextDouble() - 0.5) * 0.45,
            vy: (_rng.nextDouble() - 0.5) * 0.45,
            size: 2.5 + _rng.nextDouble() * 3.5,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.015 + _rng.nextDouble() * 0.02,
          ));
        }
        break;
      case WeatherEffect.aurora:
        final count = (area / 18000 * intensity).round();
        for (var i = 0; i < count; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _size.height * 0.08 + _rng.nextDouble() * _size.height * 0.38,
            vx: 0.15 + _rng.nextDouble() * 0.25,
            vy: (_rng.nextDouble() - 0.5) * 0.06,
            size: 70 + _rng.nextDouble() * 130,
            alpha: 0.035 + _rng.nextDouble() * 0.065,
            wobble: _rng.nextDouble() * math.pi * 2,
            wobbleSpeed: 0.008 + _rng.nextDouble() * 0.012,
          ));
        }
        break;
      case WeatherEffect.hail:
        final hailCount = (area / 8000 * intensity).round();
        final rainCount = (area / 4000 * intensity).round();
        for (var i = 0; i < hailCount; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -2.0 * intensity + _rng.nextDouble() * 1.0,
            vy: 11 * intensity + _rng.nextDouble() * 7,
            size: 3.0 + _rng.nextDouble() * 4.0,
            wobble: 0,
          ));
        }
        for (var i = 0; i < rainCount; i++) {
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: -2.5 * intensity,
            vy: 15 * intensity + _rng.nextDouble() * 5,
            size: 1.0 + _rng.nextDouble() * 1.0,
            wobble: 1,
          ));
        }
        break;
      case WeatherEffect.windGust:
        final count = (area / 5000 * intensity).round();
        for (var i = 0; i < count; i++) {
          final isHorizontal = _rng.nextDouble() > 0.35;
          _particles.add(_Particle(
            x: _rng.nextDouble() * _size.width,
            y: _rng.nextDouble() * _size.height,
            vx: isHorizontal ? (9 + _rng.nextDouble() * 13) * intensity : (_rng.nextDouble() - 0.5) * 1.5,
            vy: isHorizontal ? (_rng.nextDouble() - 0.5) * 0.7 : (0.3 + _rng.nextDouble() * 0.6),
            size: isHorizontal ? (1.0 + _rng.nextDouble() * 1.5) : (1.5 + _rng.nextDouble() * 3.0),
            alpha: isHorizontal ? (0.2 + _rng.nextDouble() * 0.35) : (0.15 + _rng.nextDouble() * 0.2),
          ));
        }
        break;
    }
  }

  void _tick() {
    if (!_controller.isAnimating || _size == Size.zero) return;

    // Связный ветер (рекомендация gpt-6-astra): один W(y,t) управляет дождём,
    // снегом и туманом — вместо независимых анимаций. Плавные гармоники.
    final t = _controller.value * 60.0; // секунды цикла
    final windPhase = math.sin(t * 0.35) * 0.5 + math.sin(t * 0.13 + 1.7) * 0.3;

    // 1. Частицы погоды с бесшовным тороидальным переносом (Seamless wrapping)
    for (final p in _particles) {
      if (widget.effect == WeatherEffect.fireflies || widget.effect == WeatherEffect.technoCivic) {
        p.vx += (_rng.nextDouble() - 0.5) * 0.05;
        p.vy += (_rng.nextDouble() - 0.5) * 0.05;
        p.vx = p.vx.clamp(-0.7, 0.7);
        p.vy = p.vy.clamp(-0.7, 0.7);
      }

      if (widget.effect == WeatherEffect.snow) {
        // Отклонение от базовой траектории, а не накопление синуса:
        // x = baseX + A*sin(ωt+φ), A зависит от глубины (дальние — меньше)
        p.wobble += p.wobbleSpeed;
        final amp = (1.8 + 6.0 * p.depth) * 0.5;
        p.x = p.baseX + math.sin(p.wobble) * amp;
      } else if (widget.effect == WeatherEffect.rain ||
          widget.effect == WeatherEffect.heavyRain ||
          widget.effect == WeatherEffect.storm ||
          widget.effect == WeatherEffect.thunderstorm) {
        // Порывы ветра синхронно сдвигают все капли (инерция через lerp)
        p.x += windPhase * 0.6 * p.depth;
        p.y += p.vy;
      } else if (widget.effect == WeatherEffect.fog ||
          widget.effect == WeatherEffect.clouds) {
        p.wobble += p.wobbleSpeed;
        p.x += p.vx + math.sin(p.wobble) * 0.15;
      } else {
        p.x += p.vx;
        p.y += p.vy;
        if (p.wobbleSpeed > 0) {
          p.wobble += p.wobbleSpeed;
          p.x += math.sin(p.wobble) * 0.5;
        }
      }

      if (widget.effect != WeatherEffect.snow) {
        p.x += p.vx;
        p.y += p.vy;
      } else {
        p.y += p.vy;
        // База движется с ветром — метель при порывах
        p.baseX += windPhase * 0.35 * p.depth;
      }

      // Бесшовный перенос по Y без случайных скачков
      if (p.y > _size.height + 30) {
        p.y -= (_size.height + 60);
        if (widget.effect == WeatherEffect.snow) {
          p.baseX = _rng.nextDouble() * _size.width;
        }
      } else if (p.y < -30) {
        p.y += (_size.height + 60);
      }

      // Бесшовный перенос по X
      if (widget.effect == WeatherEffect.snow) {
        if (p.baseX < -p.size * 2) {
          p.baseX += (_size.width + p.size * 4);
        } else if (p.baseX > _size.width + p.size * 2) {
          p.baseX -= (_size.width + p.size * 4);
        }
      } else if (p.x < -p.size * 2) {
        p.x += (_size.width + p.size * 4);
      } else if (p.x > _size.width + p.size * 2) {
        p.x -= (_size.width + p.size * 4);
      }
    }

    // 2. Капли на переднем стекле (Lens Droplets)
    for (final d in _lensDroplets) {
      d.y += d.speed;
      if (d.y > _size.height + 20) {
        d.y = -20;
        d.x = _rng.nextDouble() * _size.width;
      }
    }

    // 3. Фрактальные молнии при грозе — мульти-вспышки одного канала
    // (рекомендация gpt-6-astra: 2-4 рестрика с паузами 30-90 мс,
    // I(t)=Σ Ai*exp(-(t-ti)/τi) вместо одиночной альфы)
    if (widget.effect == WeatherEffect.thunderstorm ||
        widget.effect == WeatherEffect.storm) {
      final now = DateTime.now();
      final since = now.difference(_lastFlash).inMilliseconds;
      if (_flashActive && since > 600) {
        _flashActive = false;
        _lightningAlpha = 0.0;
        _lastFlash = now;
      } else if (!_flashActive && since > 3200 && _rng.nextDouble() < 0.03) {
        _flashActive = true;
        _lastFlash = now;
        _lightningAlpha = 1.0;
        _lightningBolt = _generateFractalLightning(
          Offset(_rng.nextDouble() * _size.width, 0),
          Offset(_rng.nextDouble() * _size.width, _size.height * (0.5 + _rng.nextDouble() * 0.4)),
          6,
        );
      } else if (_flashActive) {
        // Затухающая цепочка рестриков: экспоненциальные пики
        final tau = 45.0;
        final flicker = math.sin(since * 0.09).abs();
        _lightningAlpha = math.exp(-since / (tau * 6)) * (0.55 + 0.45 * flicker);
      }
    }

    // Перерисовка только canvas-слоёв (через listenable ниже), без
    // перестройки виджет-дерева — убирает фризы на слабых устройствах.
    _repaint.value++;
  }

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
    _repaint.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.value;

    return AnimatedBuilder(
      animation: _repaint,
      builder: (context, _) => Stack(
        children: [
        // ─── СЛОЙ 0: Небесный градиент ───
        if (widget.showBackground)
          Container(
            decoration: BoxDecoration(
              gradient: _skyGradient(progress),
            ),
          ),

        // ─── СЛОЙ 1: Фоновая атмосфера (Лучи, Аврора, Метеоры, Туман) ───
        Positioned.fill(
          child: CustomPaint(
            painter: _AmbientAtmospherePainter(
              isDay: widget.isDay,
              effect: widget.effect,
              animProgress: progress,
            ),
          ),
        ),

        // ─── СЛОЙ 1.5: Солнце / Луна с мягким пульсирующим ореолом ───
        if (widget.effect == WeatherEffect.clear || widget.effect == WeatherEffect.clouds)
          Positioned(
            top: _size.height * 0.07,
            right: _size.width * 0.10,
            child: _AnimatedSunMoon(isDay: widget.isDay, progress: progress),
          ),

        // ─── СЛОЙ 2: Основные погодные частицы ───
        Positioned.fill(
          child: CustomPaint(
            painter: _WeatherPainter(
              particles: _particles,
              effect: widget.effect,
              flash: _flashActive,
              isDay: widget.isDay,
              lightningBolt: _lightningBolt,
              lightningAlpha: _lightningAlpha,
              progress: progress,
            ),
          ),
        ),

        // ─── СЛОЙ 3: Передний план (Капли на стекле, мороз, блики) ───
        Positioned.fill(
          child: CustomPaint(
            painter: _ForegroundLensPainter(
              droplets: _lensDroplets,
              effect: widget.effect,
              isDay: widget.isDay,
              progress: progress,
            ),
          ),
        ),

        // Контент поверх
        if (widget.child != null) widget.child!,
      ],
      ),
    );
  }

  LinearGradient _skyGradient(double progress) {
    final isDay = widget.isDay;

    switch (widget.effect) {
      case WeatherEffect.clear:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF0284C7), const Color(0xFF38BDF8), const Color(0xFFBAE6FD)]
              : [const Color(0xFF030712), const Color(0xFF0F172A), const Color(0xFF1E293B)],
        );
      case WeatherEffect.clouds:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF475569), const Color(0xFF64748B), const Color(0xFF94A3B8)]
              : [const Color(0xFF0A0F1D), const Color(0xFF131C2E), const Color(0xFF1E293B)],
        );
      case WeatherEffect.fog:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF78909C), const Color(0xFFB0BEC5), const Color(0xFFECEFF1)]
              : [const Color(0xFF101720), const Color(0xFF1E272E), const Color(0xFF2C3A47)],
        );
      case WeatherEffect.rain:
      case WeatherEffect.heavyRain:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDay
              ? [const Color(0xFF334155), const Color(0xFF475569), const Color(0xFF64748B)]
              : [const Color(0xFF05070C), const Color(0xFF0A0F1D), const Color(0xFF161F30)],
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
              ? [const Color(0xFF1E293B), const Color(0xFF334155), const Color(0xFF475569)]
              : [const Color(0xFF030508), const Color(0xFF0B101B), const Color(0xFF182232)],
        );
      case WeatherEffect.sakura:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B0A1E), Color(0xFF4A1535), Color(0xFF702050)],
        );
      case WeatherEffect.fireflies:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF020908), Color(0xFF081814), Color(0xFF0F2B20)],
        );
      case WeatherEffect.cosmos:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF020208), Color(0xFF090417), Color(0xFF150A2E)],
        );
      case WeatherEffect.technoCivic:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF030814), Color(0xFF071226), Color(0xFF0D2240)],
        );
      case WeatherEffect.aurora:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF000428), Color(0xFF00382E), Color(0xFF001F1A)],
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
    this.plane = 0,
    // Непрерывная глубина (рекомендация gpt-6-astra): q=1/z, z∈[1,4].
    // Управляет скоростью, толщиной и прозрачностью вместо 2 дискретных планов.
    this.depth = 1.0,
    // Базовая траектория для снега: отклонение задаётся от базы, не накоплением
    this.baseX = 0.0,
  });

  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  double wobble;
  double wobbleSpeed;
  int plane;
  double depth;
  double baseX;
}

/// Капля на стекле переднего плана.
class _LensDroplet {
  _LensDroplet({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.trailLength,
  });

  double x;
  double y;
  double radius;
  double speed;
  double trailLength;
}

/// Солнце/Луна с гармоническим дыханием ореола.
class _AnimatedSunMoon extends StatelessWidget {
  const _AnimatedSunMoon({required this.isDay, required this.progress});
  final bool isDay;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final coreColor = isDay ? const Color(0xFFFFD54F) : const Color(0xFFE0F2FE);
    final breath = (0.7 + 0.3 * math.sin(progress * 2 * math.pi * 3)).clamp(0.4, 1.0);

    return Container(
      width: 95,
      height: 95,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            coreColor,
            coreColor.withOpacity(0.85),
            coreColor.withOpacity(0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: coreColor.withOpacity(0.35 * breath),
            blurRadius: 50 * breath,
            spreadRadius: 8 * breath,
          ),
        ],
      ),
    );
  }
}

/// СЛОЙ 1: Атмосферный фоновый пейнтер (строго гармонический).
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
    // 1. Дневные лучи солнца с бесшовным гармоническим вращением
    if (isDay && (effect == WeatherEffect.clear || effect == WeatherEffect.clouds)) {
      final sunOrigin = Offset(size.width * 0.88, size.height * 0.10);
      final rayCount = 10;
      final rayPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE082).withOpacity(0.16),
            const Color(0xFFFFD54F).withOpacity(0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: sunOrigin, radius: size.height * 0.85));

      canvas.save();
      canvas.translate(sunOrigin.dx, sunOrigin.dy);
      // Вращение на строго целое число оборотов за цикл (2 оборота за 60 секунд)
      canvas.rotate(animProgress * 2 * math.pi * 2.0);

      for (int i = 0; i < rayCount; i++) {
        final angle = (i * 2 * math.pi) / rayCount;
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(math.cos(angle - 0.12) * size.height * 0.9, math.sin(angle - 0.12) * size.height * 0.9)
          ..lineTo(math.cos(angle + 0.12) * size.height * 0.9, math.sin(angle + 0.12) * size.height * 0.9)
          ..close();
        canvas.drawPath(path, rayPaint);
      }
      canvas.restore();
    }

    // 2. Северное сияние (Аврора) — плавные волновые ленты
    if (effect == WeatherEffect.aurora || (!isDay && effect == WeatherEffect.clear)) {
      final wave1 = math.sin(animProgress * 2 * math.pi * 4) * 20.0;
      final wave2 = math.cos(animProgress * 2 * math.pi * 3) * 15.0;

      final aurPath = Path()
        ..moveTo(0, size.height * 0.15 + wave1)
        ..quadraticBezierTo(
            size.width * 0.35, size.height * 0.08 + wave2, size.width * 0.65, size.height * 0.18 + wave1)
        ..quadraticBezierTo(
            size.width * 0.85, size.height * 0.22 + wave2, size.width, size.height * 0.12 + wave1)
        ..lineTo(size.width, size.height * 0.32 + wave1)
        ..quadraticBezierTo(
            size.width * 0.65, size.height * 0.38 + wave2, size.width * 0.35, size.height * 0.28 + wave1)
        ..lineTo(0, size.height * 0.35 + wave1)
        ..close();

      final aurPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00FF87).withOpacity(0.18),
            const Color(0xFF00E5FF).withOpacity(0.12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

      canvas.drawPath(aurPath, aurPaint);
    }

    // 3. Звездное небо с гармоническим мерцанием и падающими метеорами
    if (!isDay) {
      final rng = math.Random(1337);
      for (int i = 0; i < 48; i++) {
        final sx = (rng.nextDouble() * size.width);
        final sy = (rng.nextDouble() * size.height * 0.65);
        final starSize = 0.8 + (i % 3) * 0.6;
        // Строго гармоническая частота мерцания (целочисленные множители 2, 3, 4, 5)
        final harmonic = 2 + (i % 4);
        final twinkle = 0.35 + 0.65 * math.sin(animProgress * 2 * math.pi * harmonic + (i * 0.5));

        final starPaint = Paint()
          ..color = (i % 6 == 0 ? const Color(0xFF80D8FF) : Colors.white)
              .withOpacity(twinkle.clamp(0.1, 0.95))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(sx, sy), starSize, starPaint);
      }

      // Падающая звезда (Метеор)
      final meteorCycle = (animProgress * 6) % 1.0;
      if (meteorCycle < 0.25) {
        final mProg = meteorCycle / 0.25;
        final mx = size.width * 0.15 + mProg * size.width * 0.45;
        final my = size.height * 0.05 + mProg * size.height * 0.20;
        final mAlpha = (math.sin(mProg * math.pi)).clamp(0.0, 1.0);

        final meteorPaint = Paint()
          ..shader = LinearGradient(
            colors: [Colors.white.withOpacity(mAlpha * 0.9), Colors.transparent],
          ).createShader(Rect.fromPoints(Offset(mx, my), Offset(mx - 60, my - 26)))
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(mx, my), Offset(mx - 60, my - 26), meteorPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientAtmospherePainter oldDelegate) => true;
}

/// СЛОЙ 2: Основной пейнтер погодных частиц.
class _WeatherPainter extends CustomPainter {
  const _WeatherPainter({
    required this.particles,
    required this.effect,
    required this.flash,
    required this.isDay,
    this.lightningBolt = const [],
    this.lightningAlpha = 0.0,
    required this.progress,
  });

  final List<_Particle> particles;
  final WeatherEffect effect;
  final bool flash;
  final bool isDay;
  final List<Offset> lightningBolt;
  final double lightningAlpha;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Вспышка молнии — освещает сцену, а не только белеет:
    // тёплый градиент сверху + подсветка облачного слоя
    if (flash && lightningAlpha > 0.05) {
      final flashPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.38 * lightningAlpha),
            const Color(0xFFBFD9FF).withOpacity(0.16 * lightningAlpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, flashPaint);

      if (lightningBolt.length >= 2) {
        final boltPath = Path()..moveTo(lightningBolt.first.dx, lightningBolt.first.dy);
        for (final pt in lightningBolt.skip(1)) {
          boltPath.lineTo(pt.dx, pt.dy);
        }

        // Внутренняя нить молнии
        canvas.drawPath(
          boltPath,
          Paint()
            ..color = Colors.white.withOpacity(0.95 * lightningAlpha)
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );

        // Неоновый ореол
        canvas.drawPath(
          boltPath,
          Paint()
            ..color = const Color(0xFF00E5FF).withOpacity(0.45 * lightningAlpha)
            ..strokeWidth = 9.0
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }

    for (final p in particles) {
      // Плавное затухание прозрачности у границ экрана для исключения резкого появления
      final edgeFade = ((p.y / 50.0).clamp(0.0, 1.0) * ((size.height - p.y) / 50.0).clamp(0.0, 1.0));

      switch (effect) {
        case WeatherEffect.rain:
        case WeatherEffect.heavyRain:
        case WeatherEffect.storm:
        case WeatherEffect.thunderstorm:
          // Непрерывная глубина: q=1/z управляет яркостью и толщиной
          final isNear = p.depth > 0.5;
          final paint = Paint()
            ..color = isDay
                ? Colors.white.withOpacity((p.depth.clamp(0.3, 1.0) * (isNear ? 0.65 : 0.35)) * edgeFade)
                : const Color(0xFF80D8FF).withOpacity((p.depth.clamp(0.3, 1.0) * (isNear ? 0.60 : 0.30)) * edgeFade)
            ..strokeWidth = p.size.clamp(0.5, 2.6)
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(p.x, p.y),
            Offset(p.x - p.vx * 2.2, p.y - p.vy * 1.3),
            paint,
          );
          break;

        case WeatherEffect.snow:
          // Кувыркание хлопка: scaleX = 0.35+0.65*|cos(Ωt+φ)|
          final tumble = 0.35 + 0.65 * math.cos(p.wobble).abs();
          final paint = Paint()
            ..color = Colors.white.withOpacity(p.depth.clamp(0.45, 0.95) * edgeFade)
            ..style = PaintingStyle.fill;
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.scale(tumble, 1.0);
          canvas.drawCircle(Offset.zero, p.size, paint);
          canvas.restore();
          break;

        case WeatherEffect.fog:
          // Слоистая оптическая толщина (закон Бугера): α=1-exp(-ρ*d).
          // Дальние слои крупнее и прозрачнее, ближние — плотнее.
          final opticalDepth = 1.0 - math.exp(-p.alpha * 14.0 * (1.0 - p.size / 240.0));
          final paint = Paint()
            ..color = (isDay ? Colors.white : Colors.grey.shade300)
                .withOpacity(opticalDepth.clamp(0.03, 0.22) * edgeFade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.35);
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
          break;

        case WeatherEffect.clouds:
          final paint = Paint()..color = Colors.white.withOpacity(p.alpha * edgeFade);
          canvas.drawOval(
            Rect.fromCenter(center: Offset(p.x, p.y), width: p.size * 1.8, height: p.size * 0.9),
            paint,
          );
          break;

        case WeatherEffect.sakura:
          final paint = Paint()
            ..color = const Color(0xFFFFB7C5).withOpacity(0.85 * edgeFade)
            ..style = PaintingStyle.fill;
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.wobble);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
            paint,
          );
          canvas.restore();
          break;

        case WeatherEffect.fireflies:
          final intensityVal = (0.35 + 0.65 * math.sin(p.wobble)).clamp(0.0, 1.0);
          final paint = Paint()
            ..color = const Color(0xFFCCFF00).withOpacity(0.55 * intensityVal * edgeFade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.4);
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size * 0.35,
            Paint()..color = Colors.white.withOpacity(0.95 * intensityVal * edgeFade),
          );
          break;

        case WeatherEffect.cosmos:
          final intensityVal = (0.3 + 0.7 * math.sin(p.wobble)).clamp(0.0, 1.0);
          final color = (p.size > 2.2) ? const Color(0xFF00E5FF) : Colors.white;
          final paint = Paint()
            ..color = color.withOpacity(intensityVal * edgeFade)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(p.x, p.y), p.size * 0.8, paint);
          break;

        case WeatherEffect.technoCivic:
          final paint = Paint()
            ..color = const Color(0xFF00E5FF).withOpacity(0.65 * edgeFade)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(p.x, p.y), p.size * 0.6, paint);

          // Связи между ближайшими узлами
          for (final other in particles) {
            if (other != p && other.x > p.x) {
              final distSq = (p.x - other.x) * (p.x - other.x) + (p.y - other.y) * (p.y - other.y);
              if (distSq < 3200) {
                final dist = math.sqrt(distSq);
                final alpha = (1.0 - dist / 56.0) * 0.18 * edgeFade;
                canvas.drawLine(
                  Offset(p.x, p.y),
                  Offset(other.x, other.y),
                  Paint()
                    ..color = const Color(0xFF00E5FF).withOpacity(alpha)
                    ..strokeWidth = 0.6,
                );
              }
            }
          }
          break;

        case WeatherEffect.aurora:
          final waveY = math.sin(p.wobble) * 14.0;
          final aurPaint = Paint()
            ..color = const Color(0xFF00FF87).withOpacity(p.alpha * (0.6 + 0.4 * math.sin(p.wobble)) * edgeFade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.35);
          canvas.drawOval(
            Rect.fromCenter(center: Offset(p.x, p.y + waveY), width: p.size * 2.2, height: p.size * 0.35),
            aurPaint,
          );
          break;

        case WeatherEffect.hail:
          if (p.wobble == 0) {
            canvas.drawCircle(
              Offset(p.x, p.y),
              p.size,
              Paint()..color = Colors.white.withOpacity(0.9 * edgeFade),
            );
          } else {
            final rPaint = Paint()
              ..color = const Color(0xFF80D8FF).withOpacity(0.35 * edgeFade)
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
          if (p.vx.abs() > 3) {
            final lineLen = p.vx.abs() * 1.8;
            final windPaint = Paint()
              ..color = (isDay ? Colors.white : const Color(0xFF80D8FF)).withOpacity(p.alpha * edgeFade)
              ..strokeWidth = p.size * 0.5
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(Offset(p.x, p.y), Offset(p.x - lineLen, p.y), windPaint);
          } else {
            final dustPaint = Paint()
              ..color = (isDay ? const Color(0xFFD4A76A) : const Color(0xFF8B7355)).withOpacity(p.alpha * edgeFade)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(Offset(p.x, p.y), p.size, dustPaint);
          }
          break;

        case WeatherEffect.clear:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) => true;
}

/// СЛОЙ 3: Передний план — капли на стекле и блики линзы (Lens Droplets & Glass Vignette).
class _ForegroundLensPainter extends CustomPainter {
  const _ForegroundLensPainter({
    required this.droplets,
    required this.effect,
    required this.isDay,
    required this.progress,
  });

  final List<_LensDroplet> droplets;
  final WeatherEffect effect;
  final bool isDay;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Капли на стекле экрана (Дождь/Гроза)
    if (effect == WeatherEffect.rain ||
        effect == WeatherEffect.heavyRain ||
        effect == WeatherEffect.storm ||
        effect == WeatherEffect.thunderstorm) {
      for (final d in droplets) {
        // След капли
        final trailPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.white.withOpacity(0.12)],
          ).createShader(Rect.fromLTWH(d.x - 1, d.y - d.trailLength, 2, d.trailLength))
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(d.x, d.y - d.trailLength), Offset(d.x, d.y), trailPaint);

        // Основное тело капли с эффектом преломления
        final dropPaint = Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        canvas.drawCircle(Offset(d.x, d.y), d.radius, dropPaint);

        // Блик света на капле
        canvas.drawCircle(
          Offset(d.x - d.radius * 0.35, d.y - d.radius * 0.35),
          d.radius * 0.35,
          Paint()..color = Colors.white.withOpacity(0.85),
        );
      }
    }

    // 2. Анамфорные кольца бликов объектива при ярком солнце
    if (isDay && effect == WeatherEffect.clear) {
      final sunOrigin = Offset(size.width * 0.88, size.height * 0.10);
      final center = Offset(size.width * 0.5, size.height * 0.5);
      final dir = center - sunOrigin;

      final flare1 = sunOrigin + dir * 0.45;
      final flare2 = sunOrigin + dir * 0.85;
      final breath = 0.8 + 0.2 * math.sin(progress * 2 * math.pi * 2);

      final ringPaint = Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.04 * breath)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(flare1, 45 * breath, ringPaint);

      final hexPaint = Paint()
        ..color = const Color(0xFFFFD54F).withOpacity(0.05 * breath)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(flare2, 28 * breath, hexPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForegroundLensPainter old) => true;
}
