import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Векторные анимированные потоки ветра (Wind Particle Streamlines).
/// Рисует процедурные светящиеся линии тока ветра с цветовой шкалой скорости (м/с).
class WeatherWindStreamlines extends StatefulWidget {
  final double windSpeedMs;
  final double windDirectionDeg;
  final double height;
  final bool showHeaderOverlay;

  const WeatherWindStreamlines({
    super.key,
    required this.windSpeedMs,
    this.windDirectionDeg = 240.0,
    this.height = 140.0,
    this.showHeaderOverlay = true,
  });

  @override
  State<WeatherWindStreamlines> createState() => _WeatherWindStreamlinesState();
}

class _WeatherWindStreamlinesState extends State<WeatherWindStreamlines>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final math.Random _rng = math.Random(42);
  late final List<_WindStreamline> _streamlines;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _streamlines = List.generate(24, (i) {
      return _WindStreamline(
        yOffset: _rng.nextDouble(),
        xPhase: _rng.nextDouble(),
        lengthFactor: 0.25 + _rng.nextDouble() * 0.45,
        speedFactor: 0.6 + _rng.nextDouble() * 0.8,
        amplitude: 6.0 + _rng.nextDouble() * 12.0,
        frequency: 1.5 + _rng.nextDouble() * 2.0,
        opacity: 0.25 + _rng.nextDouble() * 0.55,
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getSpeedColor(double speed) {
    if (speed < 4.0) return const Color(0xFF38BDF8); // Лазурный штиль
    if (speed < 8.0) return const Color(0xFF34D399); // Мятный умеренный
    if (speed < 14.0) return const Color(0xFFFBBF24); // Янтарный сильный
    return const Color(0xFFFF453A); // Неоново-красный шторм
  }

  String _getSpeedLabel(double speed) {
    if (speed < 4.0) return 'Слабый ветер (Штиль)';
    if (speed < 8.0) return 'Умеренный бриз';
    if (speed < 14.0) return 'Порывистый ветер';
    return 'Штормовое предупреждение!';
  }

  @override
  Widget build(BuildContext context) {
    final speed = widget.windSpeedMs.clamp(0.0, 35.0);
    final accentColor = _getSpeedColor(speed);

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Анимированный векторный холст потоков ветра
            AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _WindStreamlinesPainter(
                    progress: _animController.value,
                    streamlines: _streamlines,
                    windSpeed: speed,
                    windDirection: widget.windDirectionDeg,
                    lineColor: accentColor,
                  ),
                );
              },
            ),

            // Верхний оверлей со статусом и телеметрией
            if (widget.showHeaderOverlay)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: accentColor.withOpacity(0.6)),
                                ),
                                child: Icon(Icons.air_rounded, color: accentColor, size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ВЕКТОРНЫЕ ПОТОКИ ВЕТРА',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              '${widget.windDirectionDeg.round()}° ЮЗ',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${speed.toStringAsFixed(1)} ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'м/с',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _getSpeedLabel(speed),
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WindStreamline {
  final double yOffset;
  final double xPhase;
  final double lengthFactor;
  final double speedFactor;
  final double amplitude;
  final double frequency;
  final double opacity;

  _WindStreamline({
    required this.yOffset,
    required this.xPhase,
    required this.lengthFactor,
    required this.speedFactor,
    required this.amplitude,
    required this.frequency,
    required this.opacity,
  });
}

class _WindStreamlinesPainter extends CustomPainter {
  final double progress;
  final List<_WindStreamline> streamlines;
  final double windSpeed;
  final double windDirection;
  final Color lineColor;

  _WindStreamlinesPainter({
    required this.progress,
    required this.streamlines,
    required this.windSpeed,
    required this.windDirection,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final speedMultiplier = (0.5 + (windSpeed / 10.0)).clamp(0.5, 3.5);

    for (final line in streamlines) {
      final currentPhase = (line.xPhase + progress * line.speedFactor * speedMultiplier) % 1.0;
      final startX = (currentPhase * (size.width + 120.0)) - 60.0;
      final lineLength = size.width * line.lengthFactor;
      final baseY = size.height * line.yOffset;

      final path = Path();
      const segments = 16;
      bool started = false;

      for (int i = 0; i <= segments; i++) {
        final t = i / segments;
        final x = startX + t * lineLength;
        final wave = math.sin((x / size.width * line.frequency * math.pi * 2) + progress * math.pi * 2) * line.amplitude;
        final y = baseY + wave;

        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }

      final alpha = (math.sin(currentPhase * math.pi) * line.opacity).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = lineColor.withOpacity(alpha * 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.2 + (windSpeed / 15.0)).clamp(1.0, 2.8)
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, paint);

      // Головная светящаяся частица
      final headX = startX + lineLength;
      final headWave = math.sin((headX / size.width * line.frequency * math.pi * 2) + progress * math.pi * 2) * line.amplitude;
      final headY = baseY + headWave;

      final headPaint = Paint()
        ..color = Colors.white.withOpacity(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headX, headY), 1.6, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WindStreamlinesPainter oldDelegate) => true;
}
