import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';

/// Нейтральный сдержанный анимированный фон для экрана создания обращения/сигнала.
/// Не режет глаза, использует спокойные сланцево-графитовые тона (Slate/Zinc),
/// но сохраняет мягкие плавные физические микро-анимации плавающих частиц и световых ореолов.
class NeutralAnimatedFormBackground extends StatefulWidget {
  final Widget child;

  const NeutralAnimatedFormBackground({
    super.key,
    required this.child,
  });

  @override
  State<NeutralAnimatedFormBackground> createState() => _NeutralAnimatedFormBackgroundState();
}

class _NeutralAnimatedFormBackgroundState extends State<NeutralAnimatedFormBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeProvider.instance.isDarkMode;

    final bgColors = isDark
        ? const [
            Color(0xFF0B0F19), // Deep neutral obsidian
            Color(0xFF0F172A), // Slate 900
            Color(0xFF111827), // Gray 900
          ]
        : const [
            Color(0xFFF8FAFC), // Slate 50
            Color(0xFFF1F5F9), // Slate 100
            Color(0xFFE2E8F0), // Slate 200
          ];

    return Stack(
      children: [
        // 1. Спокойный градиентный фон
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgColors,
              ),
            ),
          ),
        ),

        // 2. Мягкие нейтральные анимированные ореолы света (без едких неоновых пятен)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * math.pi * 2;
              final orb1Offset = Offset(
                math.sin(t) * 35,
                math.cos(t * 0.8) * 30,
              );
              final orb2Offset = Offset(
                math.cos(t * 0.7) * -30,
                math.sin(t * 0.9) * 35,
              );

              return CustomPaint(
                painter: _NeutralAtmospherePainter(
                  isDark: isDark,
                  orb1Offset: orb1Offset,
                  orb2Offset: orb2Offset,
                  progress: _controller.value,
                ),
              );
            },
          ),
        ),

        // 3. Основной контент формы
        widget.child,
      ],
    );
  }
}

class _NeutralAtmospherePainter extends CustomPainter {
  final bool isDark;
  final Offset orb1Offset;
  final Offset orb2Offset;
  final double progress;

  _NeutralAtmospherePainter({
    required this.isDark,
    required this.orb1Offset,
    required this.orb2Offset,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Мягкий рассеянный холодный свет вверху справа (сдержанный, прозрачность 0.05)
    final p1 = Paint()
      ..shader = RadialGradient(
        center: Alignment.topRight,
        radius: 0.9,
        colors: [
          (isDark ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8))
              .withOpacity(isDark ? 0.06 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(w * 0.4 + orb1Offset.dx, -50 + orb1Offset.dy, w * 0.8, h * 0.5));
    canvas.drawCircle(Offset(w * 0.85 + orb1Offset.dx, h * 0.15 + orb1Offset.dy), w * 0.6, p1);

    // Мягкий рассеянный акцент внизу слева
    final p2 = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomLeft,
        radius: 0.8,
        colors: [
          (isDark ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1))
              .withOpacity(isDark ? 0.04 : 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(-50 + orb2Offset.dx, h * 0.6 + orb2Offset.dy, w * 0.7, h * 0.5));
    canvas.drawCircle(Offset(w * 0.15 + orb2Offset.dx, h * 0.8 + orb2Offset.dy), w * 0.5, p2);

    // Тонкие рассеянные микро-частицы пыли/атмосферы
    final dotPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.08 : 0.04)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 16; i++) {
      final px = (math.sin(i * 99 + progress * math.pi * 2) * 0.5 + 0.5) * w;
      final py = ((i * 67 + progress * 80) % h);
      final r = 1.0 + (i % 3) * 0.6;
      canvas.drawCircle(Offset(px, py), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeutralAtmospherePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
