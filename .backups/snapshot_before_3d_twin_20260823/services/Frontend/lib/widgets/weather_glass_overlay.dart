import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dynamic Weather Overlay Modes for Glassmorphic Panels in City Pulse NV.
enum WeatherOverlayMode {
  none,
  frost,        // Severe frost (<= -20°C): Ice crystal pattern & frost border
  aurora,       // Northern Lights: Animated neon aurora gradient Sweep (#00E5FF -> #8B5CF6 -> #10B981)
  snowfall,     // Snowfall: Falling vector snowflakes drift
}

class WeatherGlassOverlay extends StatefulWidget {
  final Widget child;
  final WeatherOverlayMode mode;
  final double tempC;
  final BorderRadius borderRadius;

  const WeatherGlassOverlay({
    super.key,
    required this.child,
    this.mode = WeatherOverlayMode.none,
    this.tempC = -15.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  State<WeatherGlassOverlay> createState() => _WeatherGlassOverlayState();
}

class _WeatherGlassOverlayState extends State<WeatherGlassOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final List<_SnowParticle> _snowflakes = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Initialize 25 falling vector snowflakes for snowfall mode
    for (int i = 0; i < 25; i++) {
      _snowflakes.add(_SnowParticle.random(_rng));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WeatherOverlayMode activeMode = widget.mode;
    if (activeMode == WeatherOverlayMode.none) {
      if (widget.tempC <= -25.0) {
        activeMode = WeatherOverlayMode.frost;
      }
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          widget.child,

          // 1. Aurora Gradient Sweep Effect (Non-blocking touch pass-through)
          if (activeMode == WeatherOverlayMode.aurora)
            IgnorePointer(
              ignoring: true,
              child: Positioned.fill(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _AuroraGradientPainter(progress: _animController.value),
                    );
                  },
                ),
              ),
            ),

          // 2. Severe Frost Ice Crystals Border (Non-blocking touch pass-through)
          if (activeMode == WeatherOverlayMode.frost)
            IgnorePointer(
              ignoring: true,
              child: Positioned.fill(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _FrostBorderPainter(
                        progress: _animController.value,
                        borderRadius: widget.borderRadius,
                      ),
                    );
                  },
                ),
              ),
            ),

          // 3. Falling Snowflakes Vector Layer (Non-blocking touch pass-through)
          if (activeMode == WeatherOverlayMode.snowfall)
            IgnorePointer(
              ignoring: true,
              child: Positioned.fill(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _SnowfallPainter(
                        snowflakes: _snowflakes,
                        progress: _animController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 1. AURORA BOREALIS GRADIENT PAINTER
// ═══════════════════════════════════════════════════════════════

class _AuroraGradientPainter extends CustomPainter {
  final double progress;

  _AuroraGradientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double angle = progress * 2 * math.pi;
    final Rect rect = Offset.zero & size;

    final Gradient gradient = LinearGradient(
      begin: Alignment(math.sin(angle), -1.0),
      end: Alignment(-math.sin(angle), 1.0),
      colors: const [
        Color(0x2200E5FF), // Neon Cyan
        Color(0x338B5CF6), // Neon Purple
        Color(0x2210B981), // Emerald Green
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.screen;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraGradientPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════
// 2. FROST ICE CRYSTALS BORDER PAINTER
// ═══════════════════════════════════════════════════════════════

class _FrostBorderPainter extends CustomPainter {
  final double progress;
  final BorderRadius borderRadius;

  _FrostBorderPainter({required this.progress, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = borderRadius.toRRect(Offset.zero & size);

    // Frost glow border
    final Paint borderPaint = Paint()
      ..color = const Color(0x77BAE6FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect, borderPaint);

    // Corner Frost Crystal details
    final Paint crystalPaint = Paint()
      ..color = Colors.white.withOpacity(0.5 + 0.2 * math.sin(progress * math.pi * 2))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Top-left corner frost spikes
    for (int i = 0; i < 4; i++) {
      final double len = 12.0 + i * 4;
      canvas.drawLine(const Offset(10, 10), Offset(10 + len, 10 + len * 0.4), crystalPaint);
      canvas.drawLine(const Offset(10, 10), Offset(10 + len * 0.4, 10 + len), crystalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FrostBorderPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════
// 3. VECTOR SNOWFALL PAINTER
// ═══════════════════════════════════════════════════════════════

class _SnowParticle {
  double x;
  double y;
  double radius;
  double speed;

  _SnowParticle({required this.x, required this.y, required this.radius, required this.speed});

  factory _SnowParticle.random(math.Random rng) {
    return _SnowParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 1.5 + rng.nextDouble() * 2.5,
      speed: 0.002 + rng.nextDouble() * 0.004,
    );
  }
}

class _SnowfallPainter extends CustomPainter {
  final List<_SnowParticle> snowflakes;
  final double progress;

  _SnowfallPainter({required this.snowflakes, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint flakePaint = Paint()
      ..color = Colors.white.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    for (final flake in snowflakes) {
      flake.y += flake.speed;
      flake.x += math.sin(progress * math.pi * 4 + flake.y * 10) * 0.001;

      if (flake.y > 1.0) {
        flake.y = -0.05;
      }

      final Offset center = Offset(flake.x * size.width, flake.y * size.height);
      canvas.drawCircle(center, flake.radius, flakePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowfallPainter oldDelegate) => true;
}
