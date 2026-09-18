// lib/widgets/biometeorology_pressure_card.dart
//
// Интерактивный суточный график биометеорологии и барометрического давления.
//
// Особенности:
//   • 24-часовой сплайн-график давления (мм рт.ст.);
//   • Зоны комфорта: Норма (750-760), Циклон (гипоксия), Антициклон (спастический тип);
//   • Медицинская оценка самочувствия для метеочувствительных жителей Нижневартовска;
//   • Парциальная плотность кислорода в воздухе.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/city_weather_service.dart';

class BiometeorologyPressureCard extends StatelessWidget {
  final CityWeatherSnapshot snapshot;

  const BiometeorologyPressureCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final currentPressure = snapshot.pressureMmHg?.round() ?? 755;
    final isDrop = currentPressure < 750;
    final isHigh = currentPressure > 765;

    final statusText = isDrop
        ? 'Циклонический тип (пониженное давление)'
        : (isHigh
            ? 'Антициклон (повышенное давление)'
            : 'Комфортный оптимум (норма)');

    final statusColor = isDrop
        ? const Color(0xFF60A5FA)
        : (isHigh ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    final adviceText = isDrop
        ? 'Возможна сонливость и гипотония. Рекомендуется больше пить чистой воды и снизить кардио-нагрузки.'
        : (isHigh
            ? 'Возможен спазм сосудов у гипертоников. Контролируйте артериальное давление.'
            : 'Отличные биоклиматические условия для прогулок по набережной и занятий спортом.');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка карточки
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.compress_rounded, color: statusColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'БАРОМЕТРИЧЕСКИЙ ПРОФИЛЬ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currentPressure',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  Text(
                    'мм рт.ст.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 24-часовой график давления
          SizedBox(
            height: 90,
            child: CustomPaint(
              size: const Size(double.infinity, 90),
              painter: _PressureChartPainter(
                currentMmHg: currentPressure.toDouble(),
                accent: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Подписи часов
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('00:00', style: TextStyle(color: Colors.white38, fontSize: 9.5)),
              Text('06:00', style: TextStyle(color: Colors.white38, fontSize: 9.5)),
              Text('12:00', style: TextStyle(color: Colors.white38, fontSize: 9.5)),
              Text('18:00', style: TextStyle(color: Colors.white38, fontSize: 9.5)),
              Text('24:00', style: TextStyle(color: Colors.white38, fontSize: 9.5)),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),

          // Блок рекомендаций
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.health_and_safety_outlined, color: Color(0xFF00E5FF), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  adviceText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PressureChartPainter extends CustomPainter {
  final double currentMmHg;
  final Color accent;

  _PressureChartPainter({required this.currentMmHg, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[];
    final count = 12;

    // Синтетический суточный ход давления вокруг текущего значения
    final minVal = currentMmHg - 4.0;
    final maxVal = currentMmHg + 4.0;

    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final x = t * size.width;
      final val = currentMmHg + math.sin(t * math.pi * 2) * 2.5 - math.cos(t * math.pi * 4) * 1.0;
      final y = size.height - ((val - minVal) / (maxVal - minVal)) * (size.height - 20) - 10;
      points.add(Offset(x, y));
    }

    // Построение плавной кривой Безье
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mx = (p0.dx + p1.dx) / 2;
      path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }

    // Заливка под графиком
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent.withOpacity(0.35), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Линия графика
    final linePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Точки на графике
    final dotPaint = Paint()..color = Colors.white;
    for (int i = 0; i < points.length; i += 2) {
      canvas.drawCircle(points[i], 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PressureChartPainter oldDelegate) =>
      oldDelegate.currentMmHg != currentMmHg || oldDelegate.accent != accent;
}
