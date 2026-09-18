import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/pulse_colors.dart';

/// Animated splash with pulsing particles and sound
class PulseSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const PulseSplashScreen({super.key, required this.onComplete});

  @override
  State<PulseSplashScreen> createState() => _PulseSplashScreenState();
}

class _PulseSplashScreenState extends State<PulseSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowOpacity;

  final AudioPlayer _player = AudioPlayer();
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random(42);

  static const int _particleCount = 45;

  bool _reduceMotion = false;
  bool _sequenceStarted = false;

  @override
  void initState() {
    super.initState();

    // Generate particles once
    for (var i = 0; i < _particleCount; i++) {
      _particles.add(_Particle.random(_rng, i));
    }

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _particleCtrl,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_sequenceStarted) {
      _sequenceStarted = true;
      _startSequence(skipParticles: _reduceMotion);
    }
  }

  Future<void> _startSequence({bool skipParticles = false}) async {
    // Play splash sound immediately
    try {
      await _player.play(AssetSource('sounds/soft_pulse.mp3'), volume: 0.6);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 100));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!skipParticles) {
      _particleCtrl.forward();
    } else {
      // Jump to the "peak" state so glow/logo reveal without particle motion.
      _particleCtrl.value = 0.5;
    }

    // After particles peak, play transition sound
    await Future.delayed(const Duration(milliseconds: 1800));
    try {
      await _player.play(AssetSource('sounds/soft_splash.mp3'), volume: 0.45);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1000));

    // Fade out and complete
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _particleCtrl.dispose();
    _fadeCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_logoCtrl, _particleCtrl, _fadeCtrl]),
      builder: (context, _) {
        return Opacity(
          opacity: 1.0 - _fadeCtrl.value,
          child: Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF020817),
                  Color(0xFF050E1F),
                  Color(0xFF020817),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Particle layer (skipped when user requests reduced motion)
                if (!_reduceMotion)
                  CustomPaint(
                    size: size,
                    painter: _ParticlesPainter(
                      particles: _particles,
                      progress: _particleCtrl.value,
                      center: Offset(size.width / 2, size.height / 2),
                    ),
                  ),

                // Radial glow behind logo
                Opacity(
                  opacity: _glowOpacity.value * 0.7,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          PulseColors.primary.withOpacity(0.35),
                          PulseColors.primary.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Logo
                Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseLogo(glowIntensity: _glowOpacity.value),
                        const SizedBox(height: 20),
                        Opacity(
                          opacity: _glowOpacity.value,
                          child: Text(
                            'ПУЛЬС ГОРОДА',
                            style: GoogleFonts.exo2(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: _glowOpacity.value * 0.6,
                          child: Text(
                            'мониторинг • события • сигналы',
                            style: GoogleFonts.manrope(
                              color: PulseColors.primary.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Loading dots at bottom
                Positioned(
                  bottom: 80,
                  child: Opacity(
                    opacity: _glowOpacity.value,
                    child: _LoadingDots(progress: _particleCtrl.value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated pulsing logo mark
class _PulseLogo extends StatelessWidget {
  final double glowIntensity;
  const _PulseLogo({required this.glowIntensity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00E5FF), Color(0xFF007AFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: PulseColors.primary.withOpacity(0.6 * glowIntensity),
            blurRadius: 40,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: PulseColors.primary.withOpacity(0.3 * glowIntensity),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '⚡',
          style: TextStyle(fontSize: 46),
        ),
      ),
    );
  }
}

/// Particle data model
class _Particle {
  final double angle; // radians
  final double speed;
  final double maxRadius;
  final double size;
  final Color color;
  final double phaseOffset;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.maxRadius,
    required this.size,
    required this.color,
    required this.phaseOffset,
  });

  factory _Particle.random(math.Random rng, int index) {
    final colors = [
      const Color(0xFF00E5FF),
      const Color(0xFF007AFF),
      const Color(0xFF38BDF8),
      const Color(0xFF818CF8),
      const Color(0xFFE2E8F0),
    ];
    return _Particle(
      angle: (index / 45) * math.pi * 2 + rng.nextDouble() * 0.4,
      speed: 0.3 + rng.nextDouble() * 0.7,
      maxRadius: 80 + rng.nextDouble() * 160,
      size: 2.0 + rng.nextDouble() * 4.0,
      color: colors[rng.nextInt(colors.length)],
      phaseOffset: rng.nextDouble(),
    );
  }

  Offset position(double progress, Offset center) {
    final t = (progress - phaseOffset).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);
    final r = eased * maxRadius * speed;
    return Offset(
      center.dx + math.cos(angle) * r,
      center.dy + math.sin(angle) * r,
    );
  }

  double opacity(double progress) {
    final t = (progress - phaseOffset).clamp(0.0, 1.0);
    if (t < 0.1) return t / 0.1;
    if (t > 0.7) return 1.0 - (t - 0.7) / 0.3;
    return 1.0;
  }
}

/// Particle painter
class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset center;

  const _ParticlesPainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final pos = p.position(progress, center);
      final alpha = p.opacity(progress);
      if (alpha <= 0) continue;

      final paint = Paint()
        ..color = p.color.withOpacity(alpha * 0.85)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(pos, p.size * 0.5, paint);

      // Bright core
      final corePaint = Paint()
        ..color = Colors.white.withOpacity(alpha * 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, p.size * 0.2, corePaint);
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) =>
      old.progress != progress || old.center != center;
}

/// Animated loading dots
class _LoadingDots extends StatelessWidget {
  final double progress;
  const _LoadingDots({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final dotProgress = ((progress * 3) - i).clamp(0.0, 1.0);
        final opacity = (math.sin(dotProgress * math.pi)).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PulseColors.primary.withOpacity(opacity * 0.9),
            ),
          ),
        );
      }),
    );
  }
}
