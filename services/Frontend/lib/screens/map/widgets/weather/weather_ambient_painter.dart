import 'dart:math' as math;
import 'package:flutter/material.dart';

class WeatherAmbientPainter extends CustomPainter {
  WeatherAmbientPainter({
    required this.kind,
    required this.progress,
    required this.slowProgress,
    required this.isNight,
    required this.accent,
  });

  final String kind;
  final double progress;
  final double slowProgress;
  final bool isNight;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> colors;
    if (isNight) {
      switch (kind) {
        case 'clear':
          colors = [const Color(0xFF02040A), const Color(0xFF090D16), const Color(0xFF0F172A)];
          break;
        case 'rain':
        case 'storm':
          colors = [const Color(0xFF05070C), const Color(0xFF0A0F1D)];
          break;
        case 'snow':
          colors = [const Color(0xFF080C14), const Color(0xFF131A26)];
          break;
        case 'wind':
        case 'fog':
          colors = [const Color(0xFF010409), const Color(0xFF090E17)];
          break;
        default:
          colors = [const Color(0xFF020617), const Color(0xFF111E2E)];
      }
    } else {
      switch (kind) {
        case 'clear':
          colors = [const Color(0xFF0284C7), const Color(0xFF38BDF8), const Color(0xFFBAE6FD)];
          break;
        case 'rain':
        case 'storm':
          colors = [const Color(0xFF334155), const Color(0xFF1E293B)];
          break;
        case 'snow':
          colors = [const Color(0xFFCBD5E1), const Color(0xFFE2E8F0)];
          break;
        case 'wind':
        case 'fog':
          colors = [const Color(0xFF64748B), const Color(0xFF94A3B8)];
          break;
        default:
          colors = [const Color(0xFF0EA5E9), const Color(0xFFE2E8F0)];
      }
    }

    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // ─── 0. Медленный атмосферный слой (slowProgress) ───
    _paintSlowAtmosphere(canvas, size);

    // ─── 1. Weather Special Ambient Animations ───
    if (isNight && kind == 'clear') {
      _paintAurora(canvas, size);
      _paintShootingStars(canvas, size);
      
      // Twinkling stars with glow aura
      for (int i = 0; i < 45; i++) {
        final seed = i * 47.0;
        final x = (seed * 19) % size.width;
        final y = (seed * 37) % (size.height * 0.42);
        final starPulse = 0.3 + 0.7 * math.sin(progress * math.pi * 4 + seed);
        final starPaint = Paint()..color = Colors.white.withOpacity(0.45 * starPulse);
        canvas.drawCircle(Offset(x, y), 0.8 + (i % 2) * 0.6, starPaint);
        if (i % 9 == 0) {
          canvas.drawCircle(Offset(x, y), 3.5 + (i % 3), Paint()..color = Colors.white.withOpacity(0.08 * starPulse));
        }
      }
    } else if (!isNight && kind == 'clear') {
      _paintBokeh(canvas, size);
    }

    // ─── 2. Storm Flash & Lightning overlay ───
    double stormFlashIntensity = 0.0;
    if (kind == 'storm') {
      final flashVal = math.sin(progress * math.pi * (isNight ? 14 : 18));
      final limit = isNight ? 0.92 : 0.89;
      if (flashVal > limit) {
        stormFlashIntensity = (flashVal - limit) / (1.0 - limit);
        canvas.drawRect(
          rect,
          Paint()..color = (isNight ? accent : Colors.white).withOpacity((isNight ? 0.16 : 0.22) * stormFlashIntensity),
        );
        _paintLightningBolt(canvas, size, stormFlashIntensity);
      }
    }

    // ─── 3. Delegate specific elements ───
    switch (kind) {
      case 'clear':
        _paintSunOrMoon(canvas, size);
        break;
      case 'rain':
      case 'storm':
        _paintRain(canvas, size, heavy: kind == 'storm');
        break;
      case 'snow':
        _paintSnow(canvas, size);
        break;
      case 'wind':
        _paintWind(canvas, size);
        break;
      case 'fog':
        _paintFog(canvas, size);
        break;
      default:
        _paintClouds(canvas, size);
    }

    // Landscape overlay at the bottom
    _paintYoWindowLandscape(canvas, size);
  }

  void _paintYoWindowLandscape(Canvas canvas, Size size) {
    final double horizonY = size.height * 0.78;
    final isClearDay = !isNight && kind == 'clear';
    
    // Задний холм
    final hillBackPaint = Paint()
      ..color = isNight 
          ? const Color(0xFF070B19) 
          : (isClearDay ? const Color(0xFF4CAF50) : const Color(0xFF1E293B));
    final hillBackPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, horizonY + 20)
      ..quadraticBezierTo(size.width * 0.35, horizonY - 45, size.width * 0.75, horizonY - 10)
      ..quadraticBezierTo(size.width * 0.9, horizonY + 5, size.width, horizonY - 15)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hillBackPath, hillBackPaint);

    // Передний холм
    final hillFrontPaint = Paint()
      ..color = isNight 
          ? const Color(0xFF03050C) 
          : (isClearDay ? const Color(0xFF2E7D32) : const Color(0xFF0F172A));
    final hillFrontPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, horizonY + 50)
      ..quadraticBezierTo(size.width * 0.25, horizonY + 15, size.width * 0.55, horizonY + 10)
      ..quadraticBezierTo(size.width * 0.8, horizonY - 25, size.width, horizonY + 10)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hillFrontPath, hillFrontPaint);

    // Wind forces calculations
    double windFreq = 1.8;
    double windAmp = 2.5;
    if (kind == 'wind') {
      windFreq = 4.2;
      windAmp = 8.0;
    } else if (kind == 'storm') {
      windFreq = 5.5;
      windAmp = 12.0;
    } else if (kind == 'rain') {
      windFreq = 2.4;
      windAmp = 4.5;
    }

    final double swing = math.sin(progress * 2 * math.pi * windFreq) * windAmp;

    // Swing tree
    final double treeX = size.width * 0.18;
    final double treeY = horizonY + 25;
    
    // Ствол
    final trunkPaint = Paint()
      ..color = isNight ? const Color(0xFF090D1A) : (isClearDay ? const Color(0xFF5D4037) : const Color(0xFF1E293B))
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
      
    final trunkPath = Path()
      ..moveTo(treeX, treeY)
      ..quadraticBezierTo(treeX - 10, treeY - 80, treeX + swing * 0.3, treeY - 140);
    canvas.drawPath(trunkPath, trunkPaint);

    // Ветви
    final branchPaint = Paint()
      ..color = isNight ? const Color(0xFF090D1A) : (isClearDay ? const Color(0xFF5D4037) : const Color(0xFF1E293B))
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
      
    final double branchEndX = treeX + swing * 0.3;
    final double branchEndY = treeY - 140;
    
    canvas.drawLine(
      Offset(branchEndX, branchEndY),
      Offset(branchEndX - 24 + swing * 0.5, branchEndY - 35),
      branchPaint,
    );
    canvas.drawLine(
      Offset(branchEndX, branchEndY),
      Offset(branchEndX + 28 + swing * 0.6, branchEndY - 25),
      branchPaint,
    );
    canvas.drawLine(
      Offset(branchEndX, branchEndY),
      Offset(branchEndX + swing * 0.7, branchEndY - 45),
      branchPaint,
    );

    // Листва
    final leafPaint = Paint()
      ..color = isNight 
          ? const Color(0xFF111827).withOpacity(0.85) 
          : (isClearDay ? const Color(0xFF81C784).withOpacity(0.9) : const Color(0xFF334155).withOpacity(0.88))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(branchEndX - 24 + swing * 0.5, branchEndY - 35),
      28,
      leafPaint,
    );
    canvas.drawCircle(
      Offset(branchEndX + 28 + swing * 0.6, branchEndY - 25),
      32,
      leafPaint,
    );
    canvas.drawCircle(
      Offset(branchEndX + swing * 0.7, branchEndY - 45),
      36,
      leafPaint,
    );

    // Блик
    final leafGlow = Paint()
      ..color = accent.withOpacity(isNight ? 0.08 : 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(branchEndX + swing * 0.7, branchEndY - 45),
      30,
      leafGlow,
    );

    // Трава
    final grassPaint = Paint()
      ..color = isNight ? const Color(0xFF080D1C) : (isClearDay ? const Color(0xFF388E3C) : const Color(0xFF1E293B))
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 22; i++) {
      final double gx = (i * 18.5) % size.width;
      double gy = horizonY + 30;
      if (gx < size.width * 0.5) {
        gy = horizonY + 25 - (gx / size.width) * 20;
      } else {
        gy = horizonY + 5 + ((gx - size.width * 0.5) / size.width) * 15;
      }
      
      final double gHeight = 12.0 + (i % 3) * 5.0;
      final double gSwing = swing * 0.8 * (0.8 + (i % 2) * 0.4);
      
      canvas.drawLine(
        Offset(gx, gy),
        Offset(gx + gSwing, gy - gHeight),
        grassPaint,
      );
    }
    
    // Swaying grass layer (denser grass swaying)
    _paintSwayingGrassLayer(canvas, size, swing);

    // Drifting fog parallax layer
    _paintDriftingFogLayer(canvas, size);

    // Floating fireflies at night
    if (isNight) {
      _paintFloatingFireflies(canvas, size);
    }

    // Wind-blown leaves
    if (kind == 'wind' || kind == 'storm' || kind == 'rain') {
      _paintWindBlownLeaves(canvas, size);
    }

    // Flying birds in the sky
    _paintFlyingBirds(canvas, size);
  }

  void _paintSwayingGrassLayer(Canvas canvas, Size size, double swing) {
    final isClearDay = !isNight && kind == 'clear';
    final grassPaint = Paint()
      ..color = isNight 
          ? const Color(0xFF030610).withOpacity(0.9) 
          : (isClearDay ? const Color(0xFF1B5E20).withOpacity(0.95) : const Color(0xFF0D172A).withOpacity(0.95))
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final horizonY = size.height * 0.78;
    for (int i = 0; i < 60; i++) {
      final double gx = (i * (size.width / 58.0));
      final double gy = horizonY + 30 + (math.sin(i) * 12);
      final double gHeight = 15.0 + (i % 5) * 4.0;
      final double gSwing = swing * (1.0 + (i % 3) * 0.3) + math.sin(progress * 2 * math.pi + i) * 1.5;
      canvas.drawLine(
        Offset(gx, gy),
        Offset(gx + gSwing, gy - gHeight),
        grassPaint,
      );
    }
  }

  void _paintDriftingFogLayer(Canvas canvas, Size size) {
    final fogPaint = Paint()
      ..color = isNight 
          ? const Color(0x1F38BDF8) 
          : const Color(0x28F1F5F9)
      ..style = PaintingStyle.fill;
    
    final double shift = (slowProgress * size.width * 0.85) % size.width;
    final double horizonY = size.height * 0.78;
    
    for (int i = 0; i < 3; i++) {
      final cx = (shift + (i * size.width * 0.33)) % (size.width + 120) - 60;
      final cy = horizonY - 10 + (math.sin(slowProgress * math.pi + i) * 15);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 140 + i * 30, height: 35 + i * 10),
        fogPaint,
      );
    }
  }

  void _paintFloatingFireflies(Canvas canvas, Size size) {
    final fireflyPaint = Paint()..style = PaintingStyle.fill;
    final double basePulse = progress * 2 * math.pi;
    final double horizonY = size.height * 0.78;
    
    for (int i = 0; i < 18; i++) {
      final seed = i * 61.3;
      final dx = (seed * 11 + progress * 35) % (size.width + 40) - 20;
      final dy = horizonY - 30 + (math.sin(basePulse + seed) * 35) - (seed % 100);
      if (dy < 50 || dy > size.height) continue;
      
      final pulse = 0.4 + 0.6 * math.sin(basePulse * 2.5 + seed);
      final sizeRadius = 1.2 + (i % 2) * 0.8;
      
      fireflyPaint.color = const Color(0xFFADFF2F).withOpacity(0.75 * pulse);
      canvas.drawCircle(Offset(dx, dy), sizeRadius, fireflyPaint);
      
      fireflyPaint.color = const Color(0xFFADFF2F).withOpacity(0.12 * pulse);
      canvas.drawCircle(Offset(dx, dy), sizeRadius * 4.5, fireflyPaint);
    }
  }

  void _paintWindBlownLeaves(Canvas canvas, Size size) {
    final leafPaint = Paint()
      ..color = isNight ? const Color(0xFF1E3A1E) : const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    
    final double basePhase = progress * 2 * math.pi;
    for (int i = 0; i < 10; i++) {
      final seed = i * 83.1;
      final lx = (seed * 17 + progress * 140) % (size.width + 80) - 40;
      final ly = (seed * 23 + progress * 70) % (size.height * 0.7) + 30;
      
      canvas.save();
      canvas.translate(lx, ly);
      canvas.rotate(math.sin(basePhase + seed) * 0.4);
      
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(8, -4, 12, 0)
        ..quadraticBezierTo(8, 4, 0, 0)
        ..close();
      canvas.drawPath(path, leafPaint);
      canvas.restore();
    }
  }

  void _paintFlyingBirds(Canvas canvas, Size size) {
    final birdPaint = Paint()
      ..color = isNight ? const Color(0x3BFFFFFF) : const Color(0x4C000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    final double bx = (slowProgress * size.width * 0.6) % (size.width + 150) - 80;
    final double by = size.height * 0.22 + (math.sin(slowProgress * math.pi) * 12);
    final flap = math.sin(progress * 2 * math.pi * 5);
    
    for (int i = 0; i < 3; i++) {
      final ox = bx - (i * 24);
      final oy = by + (i * 12) - (i == 1 ? 4 : 0);
      
      final path = Path()
        ..moveTo(ox - 8, oy + flap * 3)
        ..quadraticBezierTo(ox - 4, oy - 2, ox, oy)
        ..quadraticBezierTo(ox + 4, oy - 2, ox + 8, oy + flap * 3);
      canvas.drawPath(path, birdPaint);
    }
  }

  void _paintSlowAtmosphere(Canvas canvas, Size size) {
    final Color cloudTint;
    switch (kind) {
      case 'clear':
        cloudTint = isNight ? const Color(0xFF1E3A5F) : const Color(0xFF93C5FD);
        break;
      case 'rain':
      case 'storm':
        cloudTint = isNight ? const Color(0xFF1C2D4A) : const Color(0xFF475569);
        break;
      case 'snow':
        cloudTint = isNight ? const Color(0xFF1F2D40) : const Color(0xFFCBD5E1);
        break;
      case 'fog':
        cloudTint = isNight ? const Color(0xFF334155) : const Color(0xFF94A3B8);
        break;
      case 'wind':
        cloudTint = isNight ? const Color(0xFF1E293B) : const Color(0xFF64748B);
        break;
      default:
        cloudTint = isNight ? const Color(0xFF1E3A5F) : const Color(0xFF7DD3FC);
    }

    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final seed = i * 137.5;
      final speedFactor = 0.6 + i * 0.15;
      final yBase = size.height * (0.08 + i * 0.14);
      final drift = (slowProgress * speedFactor + seed / 360.0) % 1.0;
      final xOffset = drift * size.width * 1.5 - size.width * 0.3;
      final cloudW = size.width * (0.6 + (i % 2) * 0.25);
      final cloudH = size.height * (0.08 + (i % 3) * 0.03);
      final opacity = 0.06 + (i % 2) * 0.04;

      paint.shader = RadialGradient(
        center: Alignment.topCenter,
        colors: [
          cloudTint.withOpacity(opacity),
          cloudTint.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(xOffset, yBase),
        width: cloudW,
        height: cloudH,
      ));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(xOffset, yBase), width: cloudW, height: cloudH),
        paint,
      );
    }

    final breathe = 0.5 + 0.5 * math.sin(slowProgress * math.pi * 2);
    final overlayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          cloudTint.withOpacity(0.13 * breathe),
          cloudTint.withOpacity(0.0),
        ],
        stops: const [0.0, 0.55],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
  }

  void _paintAurora(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 48.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    final path1 = Path();
    final path2 = Path();

    final grad1 = LinearGradient(
      colors: [
        const Color(0x0000FF87),
        const Color(0x2E00FF87),
        const Color(0x5900E5FF),
        const Color(0x2E7C4DFF),
        const Color(0x007C4DFF),
      ],
    );
    paint.shader = grad1.createShader(Offset.zero & size);

    for (double x = 0; x <= size.width; x += 20) {
      final y = size.height * 0.13 +
          math.sin((x / 80) + progress * 2 * math.pi * 0.12) * 18 +
          math.cos((x / 140) - progress * 2 * math.pi * 0.06) * 12;
      if (x == 0) {
        path1.moveTo(x, y);
      } else {
        path1.lineTo(x, y);
      }
    }
    canvas.drawPath(path1, paint);

    final grad2 = LinearGradient(
      colors: [
        const Color(0x007C4DFF),
        const Color(0x287C4DFF),
        const Color(0x4CFF007F),
        const Color(0x2400E5FF),
        const Color(0x0000E5FF),
      ],
    );
    paint.shader = grad2.createShader(Offset.zero & size);
    paint.strokeWidth = 56.0;

    for (double x = 0; x <= size.width; x += 20) {
      final y = size.height * 0.18 +
          math.sin((x / 100) - progress * 2 * math.pi * 0.08) * 24 +
          math.cos((x / 180) + progress * 2 * math.pi * 0.1) * 16;
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    canvas.drawPath(path2, paint);
  }

  void _paintShootingStars(Canvas canvas, Size size) {
    final starCycle = (progress * 5) % 1.0;
    if (starCycle < 0.15) {
      final t = starCycle / 0.15;
      final startX = size.width * 0.15;
      final startY = size.height * 0.04;
      final endX = size.width * 0.75;
      final endY = size.height * 0.32;

      final currentX = startX + (endX - startX) * t;
      final currentY = startY + (endY - startY) * t;

      final tailX = startX + (endX - startX) * math.max(0.0, t - 0.16);
      final tailY = startY + (endY - startY) * math.max(0.0, t - 0.16);

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.85)],
        ).createShader(Rect.fromPoints(Offset(tailX, tailY), Offset(currentX, currentY)))
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(tailX, tailY), Offset(currentX, currentY), paint);
    }
  }

  void _paintBokeh(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 20; i++) {
      final seed = i * 59.0;
      final speed = 0.07 + (i % 3) * 0.035;
      final scale = 0.5 + (i % 4) * 0.25;

      final y = (seed * 13 - progress * speed * size.height) % size.height;
      final drift = math.sin((y / size.height) * 4 * math.pi + progress * math.pi) * 14;
      final x = (seed * 37 + drift) % size.width;

      final radius = 5.5 * scale;
      final opacity = 0.055 * (1.0 - (y / size.height)) * (0.3 + 0.7 * math.sin(progress * 2 * math.pi + seed));

      paint.color = const Color(0xFFFFF9C4).withOpacity(math.max(0.0, math.min(1.0, opacity)));
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _paintLightningBolt(Canvas canvas, Size size, double intensity) {
    if (intensity < 0.1) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(intensity)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

    final boltPath = Path();
    final randomSeed = (progress * 380).floor();
    final math.Random random = math.Random(randomSeed);

    double currentX = size.width * (0.35 + random.nextDouble() * 0.3);
    double currentY = size.height * 0.08;
    boltPath.moveTo(currentX, currentY);

    final List<Offset> branchStarts = [];

    while (currentY < size.height * 0.72) {
      final stepY = 18.0 + random.nextDouble() * 22.0;
      final stepX = (random.nextDouble() - 0.5) * 38.0;
      currentX += stepX;
      currentY += stepY;
      boltPath.lineTo(currentX, currentY);

      if (random.nextDouble() > 0.85) {
        branchStarts.add(Offset(currentX, currentY));
      }
    }
    canvas.drawPath(boltPath, paint);

    final branchPaint = Paint()
      ..color = const Color(0xFFE0F2FE).withOpacity(intensity * 0.7)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    for (final start in branchStarts) {
      double bx = start.dx;
      double by = start.dy;
      final branchPath = Path()..moveTo(bx, by);
      final direction = random.nextDouble() > 0.5 ? 1.0 : -1.0;

      for (int i = 0; i < 3; i++) {
        by += 14.0 + random.nextDouble() * 12.0;
        bx += (random.nextDouble() * 16.0 + 6.0) * direction;
        branchPath.lineTo(bx, by);
      }
      canvas.drawPath(branchPath, branchPaint);
    }
  }

  void _paintSunOrMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.72, size.height * 0.22);
    final double basePulse = progress * 2 * math.pi;

    if (isNight) {
      final double moonRadius = 32.0;

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF38BDF8).withOpacity(0.35 + 0.08 * math.sin(basePulse)),
            const Color(0xFF0F172A).withOpacity(0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 100));
      canvas.drawCircle(center, 100, glowPaint);

      final moonBodyPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.25),
          colors: const [
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
            Color(0xFF94A3B8),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: moonRadius));
      canvas.drawCircle(center, moonRadius, moonBodyPaint);

      final List<Offset> craters = const [
        Offset(-12, -8),
        Offset(2, -15),
        Offset(-8, 12),
        Offset(14, 5),
        Offset(4, 10),
      ];
      final List<double> craterSizes = const [5.0, 3.5, 6.0, 4.0, 3.0];

      for (int i = 0; i < craters.length; i++) {
        final craterCenter = center + craters[i];
        final r = craterSizes[i];

        final craterShadow = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [
              const Color(0xFF64748B).withOpacity(0.85),
              const Color(0xFF94A3B8).withOpacity(0.2),
            ],
          ).createShader(Rect.fromCircle(center: craterCenter, radius: r));
        canvas.drawCircle(craterCenter, r, craterShadow);

        final rimPaint = Paint()
          ..color = Colors.white.withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6;
        canvas.drawArc(
          Rect.fromCircle(center: craterCenter, radius: r),
          math.pi * 0.75,
          math.pi,
          false,
          rimPaint,
        );
      }

      final moonPath = Path()
        ..addArc(Rect.fromCircle(center: center, radius: moonRadius), -math.pi / 2.2, math.pi * 1.5);
      final cutPath = Path()
        ..addArc(Rect.fromCircle(center: center - const Offset(11, -5), radius: moonRadius * 0.95), -math.pi / 2, math.pi * 1.5);
      final finalMoon = Path.combine(PathOperation.difference, moonPath, cutPath);

      final crescentPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.2),
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFE2E8F0),
            Color(0xFFCBD5E1),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: moonRadius));

      canvas.drawPath(finalMoon, crescentPaint);

    } else {
      final double sunRadius = 36.0;

      final coronaPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD54F).withOpacity(0.58 + 0.12 * math.sin(basePulse * 1.8)),
            const Color(0xFFFF8F00).withOpacity(0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 110));
      canvas.drawCircle(center, 110, coronaPaint);

      final rayPaint = Paint()..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(progress * 2 * math.pi * 0.08);
      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        rayPaint.shader = LinearGradient(
          colors: [
            const Color(0xFFFFE082).withOpacity(0.24),
            const Color(0xFFFFB300).withOpacity(0.0),
          ],
        ).createShader(Rect.fromPoints(Offset.zero, Offset(160 * math.cos(angle), 160 * math.sin(angle))));
        
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(38 * math.cos(angle - 0.22), 38 * math.sin(angle - 0.22))
          ..lineTo(160 * math.cos(angle), 160 * math.sin(angle))
          ..lineTo(38 * math.cos(angle + 0.22), 38 * math.sin(angle + 0.22))
          ..close();
        canvas.drawPath(path, rayPaint);
      }
      canvas.restore();

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-progress * 2 * math.pi * 0.04);
      for (int i = 0; i < 6; i++) {
        final angle = i * math.pi / 3 + 0.2;
        rayPaint.shader = LinearGradient(
          colors: [
            const Color(0xFFFFB300).withOpacity(0.18),
            const Color(0xFFFF6D00).withOpacity(0.0),
          ],
        ).createShader(Rect.fromPoints(Offset.zero, Offset(210 * math.cos(angle), 210 * math.sin(angle))));
        
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(44 * math.cos(angle - 0.18), 44 * math.sin(angle - 0.18))
          ..lineTo(210 * math.cos(angle), 210 * math.sin(angle))
          ..lineTo(44 * math.cos(angle + 0.18), 44 * math.sin(angle + 0.18))
          ..close();
        canvas.drawPath(path, rayPaint);
      }
      canvas.restore();

      final sunBodyPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: const [
            Color(0xFFFFFDE7),
            Color(0xFFFFF59D),
            Color(0xFFFFCA28),
            Color(0xFFFF8F00),
          ],
          stops: const [0.0, 0.2, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: sunRadius));
      canvas.drawCircle(center, sunRadius, sunBodyPaint);

      final glossPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.42),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(center.dx - sunRadius, center.dy - sunRadius, sunRadius * 2, sunRadius));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - sunRadius * 0.35),
          width: sunRadius * 1.5,
          height: sunRadius * 0.7,
        ),
        glossPaint,
      );
    }
  }

  void _paintRain(Canvas canvas, Size size, {bool heavy = false}) {
    final count = heavy ? 120 : 70;
    for (int i = 0; i < count; i++) {
      final depth = (i % 3) / 2.0;
      final speedMult = 1.0 + depth * 1.5;
      final seed = i * 29.0;
      
      final x = (seed * 41 + progress * speedMult * size.width * 0.6) % size.width;
      final y = (seed * 17 + progress * speedMult * size.height * 1.8) % size.height;
      
      final strokeWidth = (heavy ? 2.2 : 1.2) * (0.6 + depth * 0.8);
      final length = (heavy ? 24.0 : 16.0) * (0.6 + depth * 1.2);
      
      final paint = Paint()
        ..color = (heavy ? accent : Colors.white).withOpacity((heavy ? 0.6 : 0.45) * (0.4 + depth * 0.6))
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
        
      if (depth == 1.0) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      }
      
      canvas.drawLine(Offset(x, y), Offset(x - (heavy ? 8.0 : 5.0) * speedMult, y + length), paint);
      
      if (y > size.height * 0.78 && i % 4 == 0) {
        final splashProgress = (y - size.height * 0.78) / (size.height * 0.22);
        final splashPaint = Paint()
          ..color = Colors.white.withOpacity(0.28 * (1 - splashProgress) * (0.4 + depth * 0.6))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(x, y + length),
            width: 14 * splashProgress * (0.6 + depth * 0.8),
            height: 4 * splashProgress * (0.6 + depth * 0.8),
          ),
          0,
          math.pi * 2,
          false,
          splashPaint,
        );
      }
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    for (int i = 0; i < 120; i++) {
      final depth = (i % 3) / 2.0;
      final speedMult = 0.4 + depth * 0.8;
      final waveFreq = 1.5 + depth;
      final seed = i * 31.0;
      
      final y = (seed * 19 + progress * speedMult * size.height * 1.2) % size.height;
      final drift = math.sin((y / size.height) * waveFreq * math.pi + progress * math.pi * 2 + seed * 0.1) * (15 + depth * 20);
      final x = (seed * 29 + drift) % size.width;
      
      final radius = (1.0 + depth * 3.5) + (i % 4) * 0.5;
      
      final paint = Paint()..color = Colors.white.withOpacity(0.3 + depth * 0.6);
      
      if (depth == 1.0) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      }
      
      canvas.drawCircle(Offset(x, y), radius, paint);
      
      if (depth > 0.0 && i % 8 == 0) {
        final linePaint = Paint()
          ..color = Colors.white.withOpacity(0.5 + depth * 0.4)
          ..strokeWidth = 0.8 + depth * 0.8;
        final len = radius * 2.4;
        
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * math.pi * 4 + seed);
        canvas.drawLine(Offset(-len, 0), Offset(len, 0), linePaint);
        canvas.drawLine(Offset(0, -len), Offset(0, len), linePaint);
        canvas.drawLine(Offset(-len*0.7, -len*0.7), Offset(len*0.7, len*0.7), linePaint);
        canvas.drawLine(Offset(len*0.7, -len*0.7), Offset(-len*0.7, len*0.7), linePaint);
        canvas.restore();
      }
    }
  }

  void _paintWind(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withOpacity(0.25)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < 15; i++) {
      final y = size.height * (0.12 + i * 0.055);
      final path = Path();
      final seed = i * 13.0;
      for (double x = 0; x <= size.width; x += 10) {
        final dy = math.sin((x / 50) + progress * math.pi * 2 + seed) * (8 + (i % 3) * 4);
        if (x == 0) {
          path.moveTo(x, y + dy);
        } else {
          path.lineTo(x, y + dy);
        }
      }
      canvas.drawPath(path, paint);
    }

    final particlePaint = Paint()..color = (isNight ? accent : const Color(0xFF10B981)).withOpacity(0.48);
    for (int i = 0; i < 12; i++) {
      final seed = i * 43.0;
      final speed = 1.2 + (i % 3) * 0.3;
      final x = (seed * 19 + progress * speed * size.width * 1.4) % size.width;
      final y = (seed * 27 + math.sin(progress * math.pi * 2 + seed) * 30) % size.height;
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2 + seed);
      
      final path = Path()
        ..moveTo(-6, 0)
        ..quadraticBezierTo(0, -3, 6, 0)
        ..quadraticBezierTo(0, 3, -6, 0);
      canvas.drawPath(path, particlePaint);
      canvas.restore();
    }
  }

  void _paintFog(Canvas canvas, Size size) {
    for (int i = 0; i < 8; i++) {
      final y = size.height * (0.2 + i * 0.09);
      final speed = 0.15 + (i % 2) * 0.1;
      final offset = (progress * speed * size.width) % size.width;
      
      final rect = Rect.fromLTWH(
        -size.width * 0.4 + offset,
        y + math.sin(progress * math.pi * 2 + i) * 6,
        size.width * 1.5,
        32 + (i % 3) * 10,
      );
      
      canvas.drawOval(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withOpacity(0.0),
              Colors.white.withOpacity(0.12 + (i % 2) * 0.06),
              Colors.white.withOpacity(0.0),
            ],
          ).createShader(rect),
      );
    }
  }

  void _paintClouds(Canvas canvas, Size size) {
    final cloudCount = 10;
    for (int i = 0; i < cloudCount; i++) {
      final depth = i / cloudCount;
      final speed = 0.1 + depth * 0.3;
      final scale = 0.5 + depth * 0.8;
      
      final cx = (size.width * (i * 0.23) + progress * speed * 120) % (size.width + 200) - 100;
      final cy = size.height * (0.08 + depth * 0.15 + math.sin(progress * math.pi * 2 + i) * 0.02);
      
      final cloudOpacity = isNight ? (0.15 + depth * 0.15) : (0.4 + depth * 0.4);
      final shadowColor = Colors.black.withOpacity(isNight ? 0.4 : 0.12);
      
      final baseColor = isNight 
          ? Color.lerp(const Color(0xFF1E293B), Colors.white, depth * 0.5)!
          : Color.lerp(const Color(0xFFE2E8F0), Colors.white, depth * 0.8)!;

      final basePaint = Paint()..color = baseColor.withOpacity(cloudOpacity);
      final blurPaint = Paint()
        ..color = shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale);
      
      canvas.drawCircle(Offset(cx + 6 * scale, cy + 8 * scale), 36 * scale, blurPaint);
      
      canvas.drawCircle(Offset(cx, cy), 36 * scale, basePaint);
      canvas.drawCircle(Offset(cx + 28 * scale, cy + 10 * scale), 28 * scale, basePaint);
      canvas.drawCircle(Offset(cx - 24 * scale, cy + 12 * scale), 24 * scale, basePaint);
      canvas.drawCircle(Offset(cx + 14 * scale, cy - 14 * scale), 22 * scale, basePaint);
      
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(cloudOpacity * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * scale);
      canvas.drawCircle(Offset(cx - 4 * scale, cy - 8 * scale), 20 * scale, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WeatherAmbientPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.slowProgress != slowProgress ||
      oldDelegate.kind != kind;
}
