import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/pulse_colors.dart';
import '../screens/infographic/widgets/infographic_backdrop.dart';
import 'dart:ui' show ImageFilter;
import 'gpu_shader_background.dart';

class DynamicAnimatedBackground extends StatefulWidget {
  final bool forceAuroraVIP;
  final String? theme;
  
  const DynamicAnimatedBackground({
    super.key,
    this.forceAuroraVIP = false,
    this.theme,
  });

  @override
  State<DynamicAnimatedBackground> createState() => _DynamicAnimatedBackgroundState();
}

class _DynamicAnimatedBackgroundState extends State<DynamicAnimatedBackground> with SingleTickerProviderStateMixin {
  String _theme = 'gravity';
  bool _loaded = false;
  bool _highPerformanceMode = false;
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
    final highPerf = prefs.getBool('high_performance_mode') ?? false;
    if (mounted) {
      setState(() {
        _theme = saved;
        _highPerformanceMode = highPerf;
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
    final currentTheme = widget.theme ?? _theme;
    final isThemeLoaded = widget.theme != null || _loaded;
    if (!isThemeLoaded) return const SizedBox.shrink();

    Widget child;
    if (currentTheme == 'premium_glass' || currentTheme.startsWith('glass_vip_')) {
      child = _PremiumGlassBackground(controller: _controller, theme: currentTheme);
    } else if (widget.forceAuroraVIP || currentTheme == 'aurora' || currentTheme == 'aurora_living') {
      child = _AuroraPulseBackground(controller: _controller);
    } else if (currentTheme == 'gravity' || currentTheme == 'radar') {
      child = const InfographicBackdrop();
    } else {
      child = _ThemeBackground(
        controller: _controller,
        palette: _ThemePalette.fromTheme(currentTheme),
        theme: currentTheme,
        highPerformanceMode: _highPerformanceMode,
      );
    }
    return RepaintBoundary(child: child);
  }
}

// ─── Theme palette mapping ───────────────────────────────────────
class _ThemePalette {
  final Color bg1;
  final Color bg2;
  final Color bg3;
  final Color accent;
  final Color particle;

  const _ThemePalette(this.bg1, this.bg2, this.bg3, this.accent, this.particle);

  static _ThemePalette fromTheme(String theme) {
    switch (theme) {
      // New custom engine themes
      case 'plasma_storm':
        return const _ThemePalette(Color(0xFF1A0530), Color(0xFF2D0855), Color(0xFF150325), Color(0xFFA855F7), Color(0xFFE9D5FF));
      case 'constellation':
        return const _ThemePalette(Color(0xFF050820), Color(0xFF0C1540), Color(0xFF030510), Color(0xFF60A5FA), Color(0xFFEFF6FF));
      case 'aurora_borealis':
        return const _ThemePalette(Color(0xFF051E2E), Color(0xFF0A3850), Color(0xFF031218), Color(0xFF10B981), Color(0xFFD1FAE5));
      case 'quantum_foam':
        return const _ThemePalette(Color(0xFF100525), Color(0xFF200A48), Color(0xFF080214), Color(0xFFEC4899), Color(0xFFFCE7F3));
      case 'rain_on_glass':
        return const _ThemePalette(Color(0xFF101E25), Color(0xFF183845), Color(0xFF0A1418), Color(0xFF94A3B8), Color(0xFFF1F5F9));

      // Space themes
      case 'cosmos':
        return const _ThemePalette(Color(0xFF030118), Color(0xFF0A0232), Color(0xFF02010D), Color(0xFF6366F1), Color(0xFF818CF8));
      case 'nebula':
        return const _ThemePalette(Color(0xFF120520), Color(0xFF1A0835), Color(0xFF08020F), Color(0xFFD946EF), Color(0xFFF0ABFC));
      case 'starfield':
        return const _ThemePalette(Color(0xFF040412), Color(0xFF0A0A30), Color(0xFF050518), Color(0xFFE2E8F0), Color(0xFFFAFAFA));
      case 'black_hole':
        return const _ThemePalette(Color(0xFF000000), Color(0xFF0A0510), Color(0xFF050208), Color(0xFFEF4444), Color(0xFFF87171));
      case 'supernova':
        return const _ThemePalette(Color(0xFF100500), Color(0xFF1C0A02), Color(0xFF080300), Color(0xFFF97316), Color(0xFFFBBF24));
      // Cyber themes
      case 'cyberpunk':
        return const _ThemePalette(Color(0xFF140228), Color(0xFF220540), Color(0xFF0A0115), Color(0xFFF472B6), Color(0xFFE879F9));
      case 'neon':
        return const _ThemePalette(Color(0xFF021520), Color(0xFF042538), Color(0xFF010A10), Color(0xFF00E5FF), Color(0xFF22D3EE));
      case 'matrix':
        return const _ThemePalette(Color(0xFF021200), Color(0xFF052000), Color(0xFF010A00), Color(0xFF22C55E), Color(0xFF4ADE80));
      case 'glitch':
        return const _ThemePalette(Color(0xFF0A0008), Color(0xFF150010), Color(0xFF050004), Color(0xFFFF3B8B), Color(0xFF00FFFF));
      case 'hologram':
        return const _ThemePalette(Color(0xFF020510), Color(0xFF050A20), Color(0xFF010308), Color(0xFF67E8F9), Color(0xFFA78BFA));
      // Abstract themes
      case 'fractal':
        return const _ThemePalette(Color(0xFF000510), Color(0xFF000A20), Color(0xFF000308), Color(0xFF3B82F6), Color(0xFF60A5FA));
      case 'voronoi':
        return const _ThemePalette(Color(0xFF050510), Color(0xFF0A0A20), Color(0xFF030308), Color(0xFFA855F7), Color(0xFFC084FC));
      case 'wave_func':
        return const _ThemePalette(Color(0xFF000808), Color(0xFF001015), Color(0xFF000505), Color(0xFF14B8A6), Color(0xFF2DD4BF));
      case 'ink_diffuse':
        return const _ThemePalette(Color(0xFF080005), Color(0xFF10000A), Color(0xFF040003), Color(0xFFEC4899), Color(0xFFF9A8D4));
      case 'fluid':
        return const _ThemePalette(Color(0xFF000510), Color(0xFF010A1E), Color(0xFF000308), Color(0xFF6366F1), Color(0xFF818CF8));
      // Nature themes
      case 'ocean':
        return const _ThemePalette(Color(0xFF001020), Color(0xFF001830), Color(0xFF000810), Color(0xFF0EA5E9), Color(0xFF38BDF8));
      case 'sakura':
        return const _ThemePalette(Color(0xFF0A0008), Color(0xFF120010), Color(0xFF050004), Color(0xFFFDA4AF), Color(0xFFFB7185));
      case 'snow':
        return const _ThemePalette(Color(0xFF050A12), Color(0xFF0A1020), Color(0xFF030508), Color(0xFFE2E8F0), Color(0xFFF1F5F9));
      case 'fireflies':
        return const _ThemePalette(Color(0xFF020A05), Color(0xFF04140A), Color(0xFF010502), Color(0xFFFBBF24), Color(0xFFFDE68A));
      case 'incense':
        return const _ThemePalette(Color(0xFF0A0500), Color(0xFF140A02), Color(0xFF050300), Color(0xFFD97706), Color(0xFFFBBF24));
      case 'tropical':
        return const _ThemePalette(Color(0xFF001008), Color(0xFF001810), Color(0xFF000805), Color(0xFF10B981), Color(0xFF34D399));
      case 'candle':
        return const _ThemePalette(Color(0xFF0A0500), Color(0xFF120800), Color(0xFF050300), Color(0xFFF59E0B), Color(0xFFFBBF24));
      case 'breath':
        return const _ThemePalette(Color(0xFF050810), Color(0xFF0A1020), Color(0xFF030508), Color(0xFF94A3B8), Color(0xFFCBD5E1));
      case 'water':
        return const _ThemePalette(Color(0xFF000815), Color(0xFF001025), Color(0xFF00040A), Color(0xFF06B6D4), Color(0xFF22D3EE));
      case 'rain':
        return const _ThemePalette(Color(0xFF030810), Color(0xFF051020), Color(0xFF020508), Color(0xFF64748B), Color(0xFF94A3B8));
      case 'oil':
        return const _ThemePalette(Color(0xFF050200), Color(0xFF0A0500), Color(0xFF030100), Color(0xFFD4A500), Color(0xFFF5C842));
      // Monitor / ai_core
      case 'ai_core':
        return const _ThemePalette(Color(0xFF050A1E), Color(0xFF0A1238), Color(0xFF030510), Color(0xFF00E5FF), Color(0xFF22D3EE));
      case 'monitor':
        return const _ThemePalette(Color(0xFF020A05), Color(0xFF04140A), Color(0xFF010502), Color(0xFF10B981), Color(0xFF34D399));
      default:
        return const _ThemePalette(Color(0xFF020A05), Color(0xFF04140A), Color(0xFF010502), Color(0xFF10B981), Color(0xFF34D399));
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
  final _ThemePalette palette;
  const _CyberBackground({required this.controller, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.bg1, palette.bg2, palette.bg3],
        ),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CyberPainter(controller.value, palette),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _CyberPainter extends CustomPainter {
  final double progress;
  final _ThemePalette palette;
  _CyberPainter(this.progress, this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.accent.withOpacity(0.05)
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
      ..color = palette.accent.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    
    final scanY = (progress * 2 % 1.0) * size.height;
    canvas.drawRect(Rect.fromLTWH(0, scanY, size.width, 20), scanlinePaint);
  }

  @override
  bool shouldRepaint(covariant _CyberPainter old) => old.progress != progress || old.palette.accent != palette.accent;
}

class _ThemeBackground extends StatelessWidget {
  final AnimationController controller;
  final _ThemePalette palette;
  final String theme;
  final bool highPerformanceMode;
  const _ThemeBackground({
    required this.controller,
    required this.palette,
    required this.theme,
    required this.highPerformanceMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.bg1, palette.bg2, palette.bg3],
        ),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ThemePainter(controller.value, palette, theme, highPerformanceMode),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ThemePainter extends CustomPainter {
  final double progress;
  final _ThemePalette palette;
  final String theme;
  final bool highPerformanceMode;
  _ThemePainter(this.progress, this.palette, this.theme, this.highPerformanceMode);

  @override
  void paint(Canvas canvas, Size size) {
    if (theme == 'matrix') {
      final cols = highPerformanceMode ? 8 : 18;
      final trailLength = highPerformanceMode ? 4 : 10;
      final paint = Paint()..style = PaintingStyle.fill;
      final rng = math.Random(123);
      for (int col = 0; col < cols; col++) {
        final double x = (col * (size.width / cols)) + 8;
        final double speed = 0.6 + rng.nextDouble() * 1.2;
        final double headY = (progress * size.height * speed) % size.height;
        for (int i = 0; i < trailLength; i++) {
          final double y = (headY - (i * 16)) % size.height;
          final double opacity = (1.0 - (i / double.parse(trailLength.toString()))).clamp(0.0, 1.0) * 0.35;
          final dotPaint = Paint()..color = palette.particle.withOpacity(opacity);
          canvas.drawCircle(Offset(x, y), 1.5 + (1.0 - i / double.parse(trailLength.toString())) * 2.0, dotPaint);
        }
      }
      return;
    }

    if (theme == 'starfield') {
      final maxStars = highPerformanceMode ? 15 : 40;
      final paint = Paint()..style = PaintingStyle.fill;
      final rng = math.Random(987);
      final center = Offset(size.width / 2, size.height / 2);
      for (int i = 0; i < maxStars; i++) {
        final double angle = rng.nextDouble() * 2 * math.pi;
        final double baseRadius = 5.0 + rng.nextDouble() * (size.width * 0.45);
        final double speed = 0.6 + rng.nextDouble() * 1.4;
        
        final double currentDist = (baseRadius + (progress * size.width * speed)) % (size.width * 0.5);
        final double x = center.dx + math.cos(angle) * currentDist;
        final double y = center.dy + math.sin(angle) * currentDist;
        
        final double sizeFactor = (currentDist / (size.width * 0.5)).clamp(0.1, 1.0);
        final double opacity = sizeFactor * 0.7;
        
        paint.color = Colors.white.withOpacity(opacity);
        canvas.drawCircle(Offset(x, y), 0.5 + sizeFactor * 2.2, paint);
      }
      return;
    }

    if (theme == 'neon') {
      final center = Offset(size.width / 2, size.height / 2);
      final maxCircles = highPerformanceMode ? 2 : 4;
      final blurRadius = highPerformanceMode ? 4.0 : 10.0;
      for (int i = 0; i < maxCircles; i++) {
        final pulse = (progress + (i * (1.0 / maxCircles))) % 1.0;
        final r = pulse * (size.width * 0.65);
        final opacity = (1.0 - pulse).clamp(0.0, 1.0) * 0.22;
        
        final circlePaint = Paint()
          ..color = palette.accent.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 + (1.0 - pulse) * 4.0;
        
        if (blurRadius > 0) {
          circlePaint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);
        }
          
        canvas.drawCircle(center, r, circlePaint);
      }
      if (!highPerformanceMode) {
        final rng = math.Random(456);
        for (int i = 0; i < 5; i++) {
          final angle = progress * 2 * math.pi + (i * 72.0 * math.pi / 180.0);
          final x = center.dx + math.cos(angle) * 70;
          final y = center.dy + math.sin(angle * 1.3) * 110;
          final blobPaint = Paint()
            ..color = palette.particle.withOpacity(0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
          canvas.drawCircle(Offset(x, y), 35 + i * 8, blobPaint);
        }
      }
      return;
    }

    if (theme == 'cyberpunk') {
      final paint = Paint()
        ..color = palette.accent.withOpacity(0.10)
        ..strokeWidth = 1.0;
      
      final horizonY = size.height * 0.48;
      final linesCount = highPerformanceMode ? 4 : 8;
      for (int i = -linesCount; i <= linesCount; i++) {
        final xStart = size.width / 2 + (i * (size.width / (linesCount * 2)));
        canvas.drawLine(
          Offset(size.width / 2, horizonY),
          Offset(xStart, size.height),
          paint,
        );
      }
      final hLines = highPerformanceMode ? 4 : 8;
      for (int i = 0; i < hLines; i++) {
        final pos = (progress + (i * (1.0 / hLines))) % 1.0;
        final y = horizonY + (pos * pos * (size.height - horizonY));
        final opacity = pos * 0.22;
        final hLinePaint = Paint()
          ..color = palette.particle.withOpacity(opacity)
          ..strokeWidth = 1.0 + pos * 1.2;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), hLinePaint);
      }
      return;
    }

    if (theme == 'ai_core') {
      final center = Offset(size.width / 2, size.height / 2);
      final corePulse = 0.95 + 0.05 * math.sin(progress * 2 * math.pi);
      
      final corePaint = Paint()..color = palette.accent.withOpacity(0.20);
      if (!highPerformanceMode) {
        corePaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      }
      canvas.drawCircle(center, 36 * corePulse, corePaint);
      
      final maxNodes = highPerformanceMode ? 6 : 12;
      final rng = math.Random(111);
      final List<Offset> nodes = [];
      for (int i = 0; i < maxNodes; i++) {
        final angle = (progress * 2 * math.pi * (rng.nextBool() ? 1 : -1) * 0.25) + (i * (2 * math.pi / maxNodes));
        final dist = 45.0 + rng.nextDouble() * 85.0;
        final x = center.dx + math.cos(angle) * dist;
        final y = center.dy + math.sin(angle) * dist;
        nodes.add(Offset(x, y));
      }
      final linePaint = Paint()
        ..color = palette.accent.withOpacity(0.10)
        ..strokeWidth = 1.0;
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final dist = (nodes[i] - nodes[j]).distance;
          if (dist < (highPerformanceMode ? 90 : 75)) {
            canvas.drawLine(nodes[i], nodes[j], linePaint);
          }
        }
        final pPaint = Paint()..color = palette.particle.withOpacity(0.5);
        canvas.drawCircle(nodes[i], 2.5, pPaint);
      }
      return;
    }

    if (theme == 'plasma_storm') {
      final center = Offset(size.width / 2, size.height / 2);
      final rng = math.Random(321);
      final maxBlobs = highPerformanceMode ? 2 : 4;
      final blurRadius = highPerformanceMode ? 18.0 : 45.0;
      for (int i = 0; i < maxBlobs; i++) {
        final double t = progress * 2 * math.pi + (i * math.pi / 2);
        final double dx = math.sin(t) * (size.width * 0.22);
        final double dy = math.cos(t * 1.4) * (size.height * 0.15);
        final radius = 90.0 + rng.nextDouble() * 50.0;
        final paint = Paint()
          ..color = (i % 2 == 0 ? palette.accent : const Color(0xFF06B6D4)).withOpacity(0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);
        canvas.drawCircle(Offset(center.dx + dx, center.dy + dy), radius, paint);
      }
      return;
    }

    if (theme == 'constellation') {
      final center = Offset(size.width / 2, size.height / 2);
      final rng = math.Random(12345);
      final maxStars = highPerformanceMode ? 8 : 18;
      final maxDistance = highPerformanceMode ? 60.0 : 90.0;
      final List<Offset> stars = [];
      for (int i = 0; i < maxStars; i++) {
        final double speed = 0.2 + rng.nextDouble() * 0.4;
        final double baseAngle = rng.nextDouble() * 2 * math.pi;
        final double angle = baseAngle + (progress * 2 * math.pi * speed);
        final double dist = 30.0 + rng.nextDouble() * (size.width * 0.4);
        final double x = center.dx + math.cos(angle) * dist;
        final double y = center.dy + math.sin(angle) * dist;
        stars.add(Offset(x, y));
      }
      final linePaint = Paint()
        ..color = palette.accent.withOpacity(0.09)
        ..strokeWidth = 0.8;
      for (int i = 0; i < stars.length; i++) {
        for (int j = i + 1; j < stars.length; j++) {
          final dist = (stars[i] - stars[j]).distance;
          if (dist < maxDistance) {
            canvas.drawLine(stars[i], stars[j], linePaint);
          }
        }
        final starPaint = Paint()
          ..color = palette.particle.withOpacity(0.55)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(stars[i], 2.0, starPaint);
      }
      return;
    }

    if (theme == 'aurora_borealis') {
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5;
      final horizonY = size.height * 0.25;
      final maxLayers = highPerformanceMode ? 1 : 3;
      final blurRadius = highPerformanceMode ? 6.0 : 15.0;
      for (int layer = 0; layer < maxLayers; layer++) {
        final path = Path();
        final double speed = 0.5 + (layer * 0.2);
        final double waveHeight = 25.0 + (layer * 10);
        final double opacity = 0.08 - (layer * 0.02);
        paint.color = palette.accent.withOpacity(opacity);
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius + layer * 5.0);

        path.moveTo(0, horizonY + layer * 20);
        for (double x = 0; x <= size.width; x += (highPerformanceMode ? 30.0 : 15.0)) {
          final double y = horizonY +
              (layer * 30) +
              math.sin((x / 50.0) + (progress * 2 * math.pi * speed)) * waveHeight +
              math.cos((x / 100.0) - (progress * math.pi * speed)) * (waveHeight * 0.5);
          path.lineTo(x, y);
        }
        canvas.drawPath(path, paint);
      }
      return;
    }

    if (theme == 'quantum_foam') {
      final paint = Paint()..style = PaintingStyle.fill;
      final rng = math.Random(555);
      final maxParticles = highPerformanceMode ? 10 : 24;
      for (int i = 0; i < maxParticles; i++) {
        final double t = (progress + (i * (1.0 / maxParticles))) % 1.0;
        final double scale = math.sin(t * math.pi);
        final double x = rng.nextDouble() * size.width;
        final double y = rng.nextDouble() * size.height;
        final double r = (1.5 + rng.nextDouble() * 3.5) * scale;
        
        paint.color = palette.accent.withOpacity(scale * 0.35);
        canvas.drawCircle(Offset(x, y), r, paint);
        
        if (!highPerformanceMode && scale > 0.6) {
          final ringPaint = Paint()
            ..color = palette.particle.withOpacity((1.0 - scale) * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawCircle(Offset(x, y), r * 2.2, ringPaint);
        }
      }
      return;
    }

    if (theme == 'rain_on_glass') {
      final paint = Paint()..style = PaintingStyle.fill;
      final rng = math.Random(777);
      final maxDrops = highPerformanceMode ? 6 : 15;
      for (int i = 0; i < maxDrops; i++) {
        final double speed = 0.4 + rng.nextDouble() * 0.8;
        final double startX = rng.nextDouble() * size.width;
        final double headY = (progress * size.height * speed) % size.height;
        final double opacity = 0.25 + 0.15 * math.sin(progress * 2 * math.pi + i);
        
        paint.color = palette.particle.withOpacity(opacity);
        canvas.drawCircle(Offset(startX, headY), 3.5, paint);
        
        if (!highPerformanceMode) {
          for (int j = 0; j < 5; j++) {
            final trailY = (headY - (j * 12)) % size.height;
            final trailOpacity = (1.0 - (j / 5.0)) * opacity * 0.5;
            final trailPaint = Paint()..color = palette.particle.withOpacity(trailOpacity);
            canvas.drawCircle(Offset(startX, trailY), 2.5 - (j * 0.3), trailPaint);
          }
        }
      }
      return;
    }
    if (theme == 'plasma_storm') {
      final center = Offset(size.width / 2, size.height / 2);
      final rng = math.Random(321);
      for (int i = 0; i < 4; i++) {
        final double t = progress * 2 * math.pi + (i * math.pi / 2);
        final double dx = math.sin(t) * (size.width * 0.22);
        final double dy = math.cos(t * 1.4) * (size.height * 0.15);
        final radius = 90.0 + rng.nextDouble() * 50.0;
        final paint = Paint()
          ..color = (i % 2 == 0 ? palette.accent : const Color(0xFF06B6D4)).withOpacity(0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
        canvas.drawCircle(Offset(center.dx + dx, center.dy + dy), radius, paint);
      }
      return;
    }

    if (theme == 'constellation') {
      final center = Offset(size.width / 2, size.height / 2);
      final rng = math.Random(12345);
      final List<Offset> stars = [];
      for (int i = 0; i < 18; i++) {
        final double speed = 0.2 + rng.nextDouble() * 0.4;
        final double baseAngle = rng.nextDouble() * 2 * math.pi;
        final double angle = baseAngle + (progress * 2 * math.pi * speed);
        final double dist = 30.0 + rng.nextDouble() * (size.width * 0.4);
        final double x = center.dx + math.cos(angle) * dist;
        final double y = center.dy + math.sin(angle) * dist;
        stars.add(Offset(x, y));
      }
      final linePaint = Paint()
        ..color = palette.accent.withOpacity(0.09)
        ..strokeWidth = 0.8;
      for (int i = 0; i < stars.length; i++) {
        for (int j = i + 1; j < stars.length; j++) {
          final dist = (stars[i] - stars[j]).distance;
          if (dist < 90) {
            canvas.drawLine(stars[i], stars[j], linePaint);
          }
        }
        final starPaint = Paint()
          ..color = palette.particle.withOpacity(0.55)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(stars[i], 2.0, starPaint);
      }
      return;
    }

    if (theme == 'aurora_borealis') {
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5;
      final horizonY = size.height * 0.25;
      for (int layer = 0; layer < 3; layer++) {
        final path = Path();
        final double speed = 0.5 + (layer * 0.2);
        final double waveHeight = 25.0 + (layer * 10);
        final double opacity = 0.08 - (layer * 0.02);
        paint.color = palette.accent.withOpacity(opacity);
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 15.0 + layer * 5.0);

        path.moveTo(0, horizonY + layer * 20);
        for (double x = 0; x <= size.width; x += 15) {
          final double y = horizonY +
              (layer * 30) +
              math.sin((x / 50.0) + (progress * 2 * math.pi * speed)) * waveHeight +
              math.cos((x / 100.0) - (progress * math.pi * speed)) * (waveHeight * 0.5);
          path.lineTo(x, y);
        }
        canvas.drawPath(path, paint);
      }
      return;
    }

    if (theme == 'quantum_foam') {
      final paint = Paint()..style = PaintingStyle.fill;
      final rng = math.Random(555);
      for (int i = 0; i < 24; i++) {
        final double t = (progress + (i * 0.04)) % 1.0;
        final double scale = math.sin(t * math.pi);
        final double x = rng.nextDouble() * size.width;
        final double y = rng.nextDouble() * size.height;
        final double r = (1.5 + rng.nextDouble() * 3.5) * scale;
        
        paint.color = palette.accent.withOpacity(scale * 0.35);
        canvas.drawCircle(Offset(x, y), r, paint);
        
        if (scale > 0.6) {
          final ringPaint = Paint()
            ..color = palette.particle.withOpacity((1.0 - scale) * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawCircle(Offset(x, y), r * 2.2, ringPaint);
        }
      }
      return;
    }

    if (theme == 'rain_on_glass') {
      final paint = Paint()..style = PaintingStyle.fill;
      final rng = math.Random(777);
      for (int i = 0; i < 15; i++) {
        final double speed = 0.4 + rng.nextDouble() * 0.8;
        final double startX = rng.nextDouble() * size.width;
        final double headY = (progress * size.height * speed) % size.height;
        final double opacity = 0.25 + 0.15 * math.sin(progress * 2 * math.pi + i);
        
        paint.color = palette.particle.withOpacity(opacity);
        canvas.drawCircle(Offset(startX, headY), 3.5, paint);
        
        for (int j = 0; j < 5; j++) {
          final trailY = (headY - (j * 12)) % size.height;
          final trailOpacity = (1.0 - (j / 5.0)) * opacity * 0.5;
          final trailPaint = Paint()..color = palette.particle.withOpacity(trailOpacity);
          canvas.drawCircle(Offset(startX, trailY), 2.5 - (j * 0.3), trailPaint);
        }
      }
      return;
    }

    if (theme == 'matrix') {
      // Digital Rain animation
      final paint = Paint()..style = PaintingStyle.fill;
      final rng = math.Random(123);
      for (int col = 0; col < 18; col++) {
        final double x = (col * (size.width / 18)) + 8;
        final double speed = 0.6 + rng.nextDouble() * 1.2;
        final double headY = (progress * size.height * speed) % size.height;
        // Draw trailing dots
        for (int i = 0; i < 10; i++) {
          final double y = (headY - (i * 16)) % size.height;
          final double opacity = (1.0 - (i / 10.0)).clamp(0.0, 1.0) * 0.35;
          final dotPaint = Paint()..color = palette.particle.withOpacity(opacity);
          canvas.drawCircle(Offset(x, y), 1.5 + (1.0 - i / 10.0) * 2.0, dotPaint);
        }
      }
      return;
    }

    if (theme == 'starfield') {
      // 3D Space Warp Stars zoom outward from center
      final paint = Paint()..style = PaintingStyle.fill;
      final rng = math.Random(987);
      final center = Offset(size.width / 2, size.height / 2);
      for (int i = 0; i < 40; i++) {
        final double angle = rng.nextDouble() * 2 * math.pi;
        final double baseRadius = 5.0 + rng.nextDouble() * (size.width * 0.45);
        final double speed = 0.6 + rng.nextDouble() * 1.4;
        
        final double currentDist = (baseRadius + (progress * size.width * speed)) % (size.width * 0.5);
        final double x = center.dx + math.cos(angle) * currentDist;
        final double y = center.dy + math.sin(angle) * currentDist;
        
        final double sizeFactor = (currentDist / (size.width * 0.5)).clamp(0.1, 1.0);
        final double opacity = sizeFactor * 0.7;
        
        paint.color = Colors.white.withOpacity(opacity);
        canvas.drawCircle(Offset(x, y), 0.5 + sizeFactor * 2.2, paint);
      }
      return;
    }

    if (theme == 'neon') {
      // Concentric pulsating glowing neon circles
      final center = Offset(size.width / 2, size.height / 2);
      for (int i = 0; i < 4; i++) {
        final pulse = (progress + (i * 0.25)) % 1.0;
        final r = pulse * (size.width * 0.65);
        final opacity = (1.0 - pulse).clamp(0.0, 1.0) * 0.22;
        
        final circlePaint = Paint()
          ..color = palette.accent.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 + (1.0 - pulse) * 4.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
          
        canvas.drawCircle(center, r, circlePaint);
      }
      // Draw neon blobs
      final rng = math.Random(456);
      for (int i = 0; i < 5; i++) {
        final angle = progress * 2 * math.pi + (i * 72.0 * math.pi / 180.0);
        final x = center.dx + math.cos(angle) * 70;
        final y = center.dy + math.sin(angle * 1.3) * 110;
        final blobPaint = Paint()
          ..color = palette.particle.withOpacity(0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
        canvas.drawCircle(Offset(x, y), 35 + i * 8, blobPaint);
      }
      return;
    }

    if (theme == 'cyberpunk') {
      // Draw grid lines perspective moving down
      final paint = Paint()
        ..color = palette.accent.withOpacity(0.10)
        ..strokeWidth = 1.0;
      
      final horizonY = size.height * 0.48;
      // Perspective vertical grid lines
      for (int i = -8; i <= 8; i++) {
        final xStart = size.width / 2 + (i * (size.width / 16));
        canvas.drawLine(
          Offset(size.width / 2, horizonY),
          Offset(xStart, size.height),
          paint,
        );
      }
      // Horizontal grid lines moving down
      for (int i = 0; i < 8; i++) {
        final pos = (progress + (i * 0.125)) % 1.0;
        final y = horizonY + (pos * pos * (size.height - horizonY));
        final opacity = pos * 0.22;
        final hLinePaint = Paint()
          ..color = palette.particle.withOpacity(opacity)
          ..strokeWidth = 1.0 + pos * 1.2;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), hLinePaint);
      }
      return;
    }

    if (theme == 'ai_core') {
      // Interconnected node network with a glowing central orb
      final center = Offset(size.width / 2, size.height / 2);
      final corePulse = 0.95 + 0.05 * math.sin(progress * 2 * math.pi);
      
      final corePaint = Paint()
        ..color = palette.accent.withOpacity(0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(center, 36 * corePulse, corePaint);
      
      final rng = math.Random(111);
      final List<Offset> nodes = [];
      for (int i = 0; i < 12; i++) {
        final angle = (progress * 2 * math.pi * (rng.nextBool() ? 1 : -1) * 0.25) + (i * (2 * math.pi / 12));
        final dist = 45.0 + rng.nextDouble() * 85.0;
        final x = center.dx + math.cos(angle) * dist;
        final y = center.dy + math.sin(angle) * dist;
        nodes.add(Offset(x, y));
      }
      // Connect nodes with thin lines
      final linePaint = Paint()
        ..color = palette.accent.withOpacity(0.10)
        ..strokeWidth = 1.0;
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final dist = (nodes[i] - nodes[j]).distance;
          if (dist < 75) {
            canvas.drawLine(nodes[i], nodes[j], linePaint);
          }
        }
        // Draw node points
        final pPaint = Paint()..color = palette.particle.withOpacity(0.5);
        canvas.drawCircle(nodes[i], 2.5, pPaint);
      }
      return;
    }

    // Default (cosmos/nebula): beautiful glowing nebulas drifting
    final paint = Paint()
      ..color = palette.particle.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final math.Random rng = math.Random(42);
    for (int i = 0; i < 20; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.4;
      
      final y = (baseY - (progress * size.height * speed)) % size.height;
      final r = 2.5 + rng.nextDouble() * 3.5;
      
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    final glowPaint = Paint()
      ..color = palette.accent.withOpacity(0.05 + 0.018 * math.sin(progress * math.pi * 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
    
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.35 + math.sin(progress * math.pi * 2) * 20),
      size.width * 0.35,
      glowPaint,
    );
    
    final glow2Paint = Paint()
      ..color = palette.particle.withOpacity(0.035 + 0.015 * math.cos(progress * math.pi * 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.65 + math.cos(progress * math.pi * 2) * 15),
      size.width * 0.25,
      glow2Paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ThemePainter old) => old.progress != progress || old.theme != theme || old.highPerformanceMode != highPerformanceMode || old.palette.accent != palette.accent;
}



class _PremiumGlassBackground extends StatelessWidget {
  final AnimationController controller;
  final String theme;
  
  const _PremiumGlassBackground({required this.controller, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    
    // Determine colors based on VIP theme
    final List<double> color1;
    final List<double> color2;
    
    if (theme == 'glass_vip_gold') {
      if (isLightTheme) {
        color1 = [0.98, 0.94, 0.82];
        color2 = [0.95, 0.84, 0.52];
      } else {
        color1 = [0.15, 0.08, 0.02];
        color2 = [0.45, 0.28, 0.05];
      }
    } else if (theme == 'glass_vip_nebula') {
      if (isLightTheme) {
        color1 = [0.95, 0.90, 0.98];
        color2 = [0.92, 0.75, 0.88];
      } else {
        color1 = [0.08, 0.03, 0.16];
        color2 = [0.45, 0.05, 0.35];
      }
    } else if (theme == 'glass_vip_emerald') {
      if (isLightTheme) {
        color1 = [0.92, 0.98, 0.94];
        color2 = [0.75, 0.92, 0.82];
      } else {
        color1 = [0.02, 0.08, 0.05];
        color2 = [0.05, 0.38, 0.22];
      }
    } else if (theme == 'glass_vip_arctic') {
      if (isLightTheme) {
        color1 = [0.90, 0.95, 0.98];
        color2 = [0.72, 0.88, 0.95];
      } else {
        color1 = [0.03, 0.08, 0.16];
        color2 = [0.15, 0.38, 0.55];
      }
    } else if (theme == 'glass_vip_sunset') {
      if (isLightTheme) {
        color1 = [0.98, 0.92, 0.90];
        color2 = [0.95, 0.78, 0.68];
      } else {
        color1 = [0.12, 0.03, 0.04];
        color2 = [0.42, 0.15, 0.04];
      }
    } else {
      if (isLightTheme) {
        color1 = [0.94, 0.94, 0.98];
        color2 = [0.78, 0.85, 0.92];
      } else {
        color1 = [0.07, 0.04, 0.14];
        color2 = [0.05, 0.20, 0.30];
      }
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GpuShaderBackground(
            shaderAsset: 'shaders/aura_theme.frag',
            fallbackColor: isLightTheme ? const Color(0xFFF3F4F6) : const Color(0xFF030508),
            onSetUniforms: (shader, time, size) {
              shader.setFloat(0, size.width);
              shader.setFloat(1, size.height);
              shader.setFloat(2, time);
              shader.setFloat(3, color1[0]);
              shader.setFloat(4, color1[1]);
              shader.setFloat(5, color1[2]);
              shader.setFloat(6, color2[0]);
              shader.setFloat(7, color2[1]);
              shader.setFloat(8, color2[2]);
              shader.setFloat(9, 1.0);
              shader.setFloat(10, 0.5);
              shader.setFloat(11, 0.5);
              shader.setFloat(12, 0.0);
            },
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                color: isLightTheme ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
