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
  late AnimationController _pulseCtrl;
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
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

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

    // After particles peak, play transition sound (reuse soft_pulse at lower volume)
    await Future.delayed(const Duration(milliseconds: 1800));
    try {
      await _player.play(AssetSource('sounds/soft_pulse.mp3'), volume: 0.45);
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
    _pulseCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_logoCtrl, _particleCtrl, _fadeCtrl, _pulseCtrl]),
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
                  Color(0xFF030308),
                  Color(0xFF0D0A1E),
                  Color(0xFF070020),
                  Color(0xFF030308),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // City skyline silhouette at the bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(size.width, size.height * 0.38),
                    painter: _CitySkylinePainter(
                      progress: _particleCtrl.value,
                      pulseValue: _pulseCtrl.value,
                    ),
                  ),
                ),

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
                        _PulseLogo(
                          glowIntensity: _glowOpacity.value,
                          pulseValue: _pulseCtrl.value,
                        ),
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

/// Animated pulsing city heartbeat mark (Vector + Canvas + Dynamic Radar Pulse)
class _PulseLogo extends StatelessWidget {
  final double glowIntensity;
  final double pulseValue;
  const _PulseLogo({required this.glowIntensity, required this.pulseValue});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding radar waves
          ...List.generate(3, (i) {
            final ringProgress = ((pulseValue + i * 0.33) % 1.0);
            final scale = 0.8 + (ringProgress * 0.7);
            final opacity = ((1.0 - ringProgress) * glowIntensity * 0.55).clamp(0.0, 1.0);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(opacity),
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),

          // Glowing circular cyber plate
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF0B192C),
                  Color(0xFF030712),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.8),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.5 * glowIntensity),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFF007AFF).withOpacity(0.3 * glowIntensity),
                  blurRadius: 60,
                  spreadRadius: 12,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Heartbeat ECG waveform inside the pulse core
                CustomPaint(
                  size: const Size(100, 60),
                  painter: _HeartbeatPainter(
                    progress: pulseValue,
                    color: const Color(0xFF00E5FF),
                  ),
                ),
                // Center pulsing energy dot
                Transform.scale(
                  scale: 0.8 + 0.4 * math.sin(pulseValue * math.pi * 2),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00E5FF),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  final double progress;
  final Color color;

  _HeartbeatPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    // Define points for heartbeat (ECG) wave
    final pulseScale = math.sin(progress * math.pi); // 0.0 -> 1.0 -> 0.0
    final qrsHeight = 18.0 * (0.3 + 0.7 * pulseScale);
    final pHeight = 4.0 * (0.5 + 0.5 * pulseScale);
    final tHeight = 6.0 * (0.5 + 0.5 * pulseScale);

    path.moveTo(0, midY);
    path.lineTo(w * 0.25, midY);
    
    // P wave
    path.quadraticBezierTo(w * 0.3, midY - pHeight, w * 0.35, midY);
    path.lineTo(w * 0.42, midY);
    
    // QRS complex
    path.lineTo(w * 0.45, midY + 3.0); // Q
    path.lineTo(w * 0.5, midY - qrsHeight); // R
    path.lineTo(w * 0.55, midY + 10.0); // S
    path.lineTo(w * 0.58, midY - 2.0);
    path.lineTo(w * 0.6, midY); // back to baseline
    
    // T wave
    path.quadraticBezierTo(w * 0.68, midY - tHeight, w * 0.75, midY);
    
    path.lineTo(w, midY);

    // Draw glow first, then main stroke
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartbeatPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
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

/// City skyline painter — draws animated building silhouettes
class _CitySkylinePainter extends CustomPainter {
  final double progress;
  final double pulseValue;

  _CitySkylinePainter({required this.progress, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final fadeIn = (progress * 3.0).clamp(0.0, 1.0);
    if (fadeIn <= 0) return;

    final w = size.width;
    final h = size.height;
    final baseY = h; // bottom

    // Building definitions: [x_ratio, width_ratio, height_ratio, hasAntenna]
    final buildings = <List<double>>[
      [0.00, 0.06, 0.35, 0],
      [0.05, 0.05, 0.55, 1],
      [0.09, 0.07, 0.42, 0],
      [0.15, 0.04, 0.72, 1],
      [0.18, 0.06, 0.38, 0],
      [0.23, 0.08, 0.60, 0],
      [0.30, 0.05, 0.85, 1],
      [0.34, 0.07, 0.48, 0],
      [0.40, 0.06, 0.65, 0],
      [0.45, 0.04, 0.92, 1],
      [0.48, 0.07, 0.55, 0],
      [0.54, 0.06, 0.70, 0],
      [0.59, 0.05, 0.45, 0],
      [0.63, 0.08, 0.80, 1],
      [0.70, 0.06, 0.50, 0],
      [0.75, 0.05, 0.68, 0],
      [0.79, 0.07, 0.58, 0],
      [0.85, 0.04, 0.75, 1],
      [0.88, 0.06, 0.40, 0],
      [0.93, 0.05, 0.52, 0],
    ];

    final buildPaint = Paint()..style = PaintingStyle.fill;

    for (final b in buildings) {
      final bx = b[0] * w;
      final bw = b[1] * w;
      final bh = b[2] * h * fadeIn;
      final hasAnt = b[3] > 0.5;

      // Building body gradient
      buildPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0A1628).withOpacity(0.9 * fadeIn),
          const Color(0xFF06101F).withOpacity(0.95 * fadeIn),
        ],
      ).createShader(Rect.fromLTWH(bx, baseY - bh, bw, bh));

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(bx, baseY - bh, bw, bh),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        buildPaint,
      );

      // Antenna on tall buildings
      if (hasAnt) {
        final antPaint = Paint()
          ..color = const Color(0xFF1E3A5F).withOpacity(fadeIn)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final antX = bx + bw / 2;
        final antH = bh * 0.15;
        canvas.drawLine(
          Offset(antX, baseY - bh),
          Offset(antX, baseY - bh - antH),
          antPaint,
        );
        // Blinking red light
        final blinkAlpha = (0.4 + 0.6 * math.sin(pulseValue * math.pi * 2))
            .clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(antX, baseY - bh - antH),
          2.0,
          Paint()..color = Color.fromRGBO(255, 60, 60, blinkAlpha * fadeIn),
        );
      }

      // Windows — small glowing rectangles
      final rng = math.Random(b[0].hashCode ^ b[2].hashCode);
      final windowCols = (bw / 6).floor().clamp(1, 8);
      final windowRows = (bh / 10).floor().clamp(1, 20);
      final winW = bw / (windowCols * 2 + 1);
      final winH = 3.0;

      for (int row = 0; row < windowRows; row++) {
        for (int col = 0; col < windowCols; col++) {
          // ~40% of windows are lit
          if (rng.nextDouble() > 0.4) continue;
          final wx = bx + winW + col * winW * 2;
          final wy = baseY - bh + 8 + row * 10.0;
          if (wy > baseY - 4) continue;

          // Window pulse — some windows flicker with city pulse
          final flicker = rng.nextDouble() < 0.15
              ? 0.3 + 0.7 * math.sin(pulseValue * math.pi * 2 + rng.nextDouble() * 6)
              : 1.0;
          final windowColor = rng.nextDouble() < 0.7
              ? Color.fromRGBO(255, 200, 80, 0.6 * fadeIn * flicker) // warm
              : Color.fromRGBO(100, 180, 255, 0.5 * fadeIn * flicker); // cool

          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(wx, wy, winW * 0.8, winH),
              const Radius.circular(0.5),
            ),
            Paint()..color = windowColor,
          );
        }
      }
    }

    // Horizon glow line
    final horizonPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF007AFF).withOpacity(0),
          const Color(0xFF007AFF).withOpacity(0.25 * fadeIn),
          const Color(0xFF00E5FF).withOpacity(0.3 * fadeIn),
          const Color(0xFF007AFF).withOpacity(0.25 * fadeIn),
          const Color(0xFF007AFF).withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, baseY - h * 0.88 * fadeIn, w, 4));
    canvas.drawRect(
      Rect.fromLTWH(0, baseY - h * 0.88 * fadeIn - 1, w, 3),
      horizonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CitySkylinePainter old) =>
      old.progress != progress || old.pulseValue != pulseValue;
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
