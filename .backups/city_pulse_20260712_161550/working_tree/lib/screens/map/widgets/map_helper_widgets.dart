import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Бегущая строка — прокручивает текст горизонтально, если он не помещается
class MarqueeText extends StatefulWidget {
  const MarqueeText({super.key, required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scroll = ScrollController();
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: (widget.text.length * 0.12).ceil().clamp(6, 40)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScroll());
  }

  Future<void> _startScroll() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;

    while (mounted) {
      await _scroll.animateTo(max,
          duration: Duration(milliseconds: (max * 22).toInt()),
          curve: Curves.linear);
      if (!mounted) break;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) break;
      _scroll.jumpTo(0);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Text(widget.text, style: widget.style, maxLines: 1),
      ),
    );
  }
}

/// Анимированный маркер, который плавно увеличивается при появлении
class ScaleInMarker extends StatefulWidget {
  final Widget child;
  const ScaleInMarker({super.key, required this.child});

  @override
  State<ScaleInMarker> createState() => _ScaleInMarkerState();
}

class _ScaleInMarkerState extends State<ScaleInMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// Рисует погодные частицы (дождь/снег) поверх карты
class MapWeatherParticlePainter extends CustomPainter {
  final String kind;
  final double progress;

  MapWeatherParticlePainter({required this.kind, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (kind == 'rain' || kind == 'storm') {
      _paintRain(canvas, size, heavy: kind == 'storm');
    } else if (kind == 'snow') {
      _paintSnow(canvas, size);
    }
  }

  void _paintRain(Canvas canvas, Size size, {bool heavy = false}) {
    final count = heavy ? 60 : 35;
    for (int i = 0; i < count; i++) {
      final depth = (i % 3) / 2.0;
      final speedMult = 1.0 + depth * 1.5;
      final seed = i * 29.0;

      final x = (seed * 41 + progress * speedMult * size.width * 0.6) % size.width;
      final y = (seed * 17 + progress * speedMult * size.height * 1.8) % size.height;

      final strokeWidth = (heavy ? 1.8 : 1.0) * (0.6 + depth * 0.8);
      final length = (heavy ? 20.0 : 12.0) * (0.6 + depth * 1.2);

      final paint = Paint()
        ..color = Colors.white.withOpacity((heavy ? 0.35 : 0.25) * (0.4 + depth * 0.6))
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x, y), Offset(x - (heavy ? 6.0 : 4.0) * speedMult, y + length), paint);
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final count = 60;
    for (int i = 0; i < count; i++) {
      final depth = (i % 3) / 2.0;
      final speedMult = 0.4 + depth * 0.8;
      final waveFreq = 1.5 + depth;
      final seed = i * 31.0;

      final y = (seed * 19 + progress * speedMult * size.height * 1.2) % size.height;
      final drift = math.sin((y / size.height) * waveFreq * math.pi + progress * math.pi * 2 + seed * 0.1) * (12 + depth * 15);
      final x = (seed * 29 + drift) % size.width;

      final radius = (1.0 + depth * 2.5) + (i % 4) * 0.4;
      final paint = Paint()..color = Colors.white.withOpacity(0.25 + depth * 0.45);

      if (depth == 1.0) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      }

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MapWeatherParticlePainter oldDelegate) => true;
}

/// Возвращает иконку для соответствующего погодного типа
IconData getWeatherIcon(String kind, bool isDay) {
  return switch (kind) {
    'clear' => isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
    'rain' => Icons.grain_rounded,
    'snow' => Icons.ac_unit_rounded,
    'wind' => Icons.air_rounded,
    'fog' => Icons.blur_on_rounded,
    'storm' => Icons.thunderstorm_rounded,
    _ => Icons.filter_drama_rounded,
  };
}
