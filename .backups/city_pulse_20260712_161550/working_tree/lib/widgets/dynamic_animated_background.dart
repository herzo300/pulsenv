import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/pulse_colors.dart';
import '../screens/infographic/widgets/infographic_backdrop.dart';

class DynamicAnimatedBackground extends StatefulWidget {
  final bool forceAuroraVIP;
  
  const DynamicAnimatedBackground({
    super.key,
    this.forceAuroraVIP = false,
  });

  @override
  State<DynamicAnimatedBackground> createState() => _DynamicAnimatedBackgroundState();
}

class _DynamicAnimatedBackgroundState extends State<DynamicAnimatedBackground> with SingleTickerProviderStateMixin {
  String _theme = 'gravity';
  bool _loaded = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('splash_theme') ?? 'gravity';
    if (mounted) {
      setState(() {
        _theme = saved;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    if (widget.forceAuroraVIP || _theme == 'aurora' || _theme == 'aurora_living') {
      return _AuroraPulseBackground(controller: _controller);
    }

    // Map splash themes to backgrounds
    if (_theme == 'gravity' || _theme == 'radar') {
      return const InfographicBackdrop();
    } else if (_theme == 'ai_core' || _theme == 'cyber') {
      return _CyberBackground(controller: _controller);
    } else {
      return _SwampBackground(controller: _controller);
    }
  }
}

class _AuroraPulseBackground extends StatelessWidget {
  final AnimationController controller;
  const _AuroraPulseBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF130924), // Deep VIP purple
            Color(0xFF040209),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _AuroraPulsePainter(controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _AuroraPulsePainter extends CustomPainter {
  final double progress;
  _AuroraPulsePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Pulse wave 1
    final p1 = (progress * 2) % 1.0;
    final r1 = p1 * size.width;
    final paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = PulseColors.accentViolet.withOpacity((1 - p1) * 0.3);
    canvas.drawCircle(center, r1, paint1);

    // Pulse wave 2
    final p2 = ((progress * 2) + 0.5) % 1.0;
    final r2 = p2 * size.width;
    final paint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = PulseColors.primary.withOpacity((1 - p2) * 0.15);
    canvas.drawCircle(center, r2, paint2);

    // Incoming signals (particles)
    final math.Random rng = math.Random(42);
    for (int i = 0; i < 15; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 0.5 + rng.nextDouble();
      final distance = size.width - ((progress * size.width * speed) % size.width);
      
      final dx = center.dx + math.cos(angle) * distance;
      final dy = center.dy + math.sin(angle) * distance;
      
      final particlePaint = Paint()
        ..color = PulseColors.success.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dx, dy), 2.5, particlePaint);
      
      // Trail
      final trailPaint = Paint()
        ..color = PulseColors.success.withOpacity(0.2)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(dx, dy),
        Offset(dx + math.cos(angle) * 15, dy + math.sin(angle) * 15),
        trailPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPulsePainter old) => old.progress != progress;
}

class _CyberBackground extends StatelessWidget {
  final AnimationController controller;
  const _CyberBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PulseColors.background,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CyberPainter(controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _CyberPainter extends CustomPainter {
  final double progress;
  _CyberPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PulseColors.primary.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const spacing = 40.0;
    
    // Draw moving grid
    final yOffset = progress * spacing;
    for (double y = yOffset; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Scanline
    final scanlinePaint = Paint()
      ..color = PulseColors.primary.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    
    final scanY = (progress * 2 % 1.0) * size.height;
    canvas.drawRect(Rect.fromLTWH(0, scanY, size.width, 20), scanlinePaint);
  }

  @override
  bool shouldRepaint(covariant _CyberPainter old) => old.progress != progress;
}

class _SwampBackground extends StatelessWidget {
  final AnimationController controller;
  const _SwampBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF020A05),
            Color(0xFF04140A),
            Color(0xFF010502),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SwampPainter(controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _SwampPainter extends CustomPainter {
  final double progress;
  _SwampPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PulseColors.success.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final math.Random rng = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.5 + rng.nextDouble();
      
      final y = (baseY - (progress * size.height * speed)) % size.height;
      final r = 2.0 + rng.nextDouble() * 3.0;
      
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SwampPainter old) => old.progress != progress;
}
