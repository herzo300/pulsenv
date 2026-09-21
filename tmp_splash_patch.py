# Append CityPulsePainter to oil_splash_screen.dart
p = r'C:\Soobshio_project\services\Frontend\lib\screens\oil_splash_screen.dart'
src = open(p, 'rb').read().decode('utf-8')

painter = '''
/// Бьющийся пульс из силуэтов города: ECG-кардиограмма, «дышащие»
/// высотки Нижневартовска вдоль линии, золотое свечение на пике удара.
class CityPulsePainter extends CustomPainter {
  final double pulse; // 0..1 цикл удара
  final double time;
  CityPulsePainter({required this.pulse, required this.time});

  double get _beat {
    final t = pulse;
    if (t < 0.12) return Curves.easeOutCubic.transform(t / 0.12) * 0.35;
    if (t < 0.18) return 0.35 - (t - 0.12) / 0.06 * 0.25;
    if (t < 0.26) return 0.10 + Curves.easeOutCubic.transform((t - 0.18) / 0.08) * 0.90;
    if (t < 0.32) return 1.0 - Curves.easeInCubic.transform((t - 0.26) / 0.06) * 1.05;
    if (t < 0.38) return -0.05 + (t - 0.32) / 0.06 * 0.22;
    if (t < 0.46) return 0.17 - (t - 0.38) / 0.08 * 0.17;
    return 0.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final beat = _beat.clamp(-0.1, 1.0).toDouble();
    final beatAbs = beat.abs();
    final baseY = h * 0.62;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.2),
        radius: 1.0,
        colors: [
          Color.lerp(const Color(0x33D4A537), const Color(0x88D4A537), beatAbs)!,
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);

    final cityPaint = Paint()..color = const Color(0xFF0B1626);
    final edgePaint = Paint()
      ..color = Color.lerp(
          const Color(0xFF1E3A5F), const Color(0xFFD4A537), beatAbs * 0.9)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final towers = <double>[0.34, 0.58, 0.42, 0.75, 0.5, 0.95, 0.62, 0.8, 0.45, 0.68, 0.38];
    final n = towers.length;
    const cityWidthFactor = 0.92;
    final towerW = w * cityWidthFactor / n;
    final x0 = w * (1 - cityWidthFactor) / 2;

    for (int i = 0; i < n; i++) {
      final wave = math.sin(time * 1.4 + i * 0.55);
      final lift = beat * towers[i] * (0.55 + 0.45 * math.sin(i * 1.7 + time * 0.8));
      final th = h * towers[i] * (0.72 + 0.28 * wave * 0.3) * (1.0 + lift * 0.16);
      final tx = x0 + i * towerW;
      final rect = Rect.fromLTRB(tx + 1.5, baseY - th, tx + towerW - 1.5, baseY);
      final rrect = RRect.fromRectAndCorners(rect,
          topLeft: const Radius.circular(3), topRight: const Radius.circular(3));
      canvas.drawRRect(rrect, cityPaint);
      canvas.drawRRect(rrect, edgePaint);

      if (beatAbs > 0.25) {
        final winPaint = Paint()
          ..color = const Color(0xFFD4A537).withOpacity(((beatAbs - 0.25) * 1.4).clamp(0.0, 0.9));
        final rng = math.Random(i * 97);
        for (int f = 0; f < 5; f++) {
          for (int c = 0; c < 2; c++) {
            if (rng.nextDouble() > 0.62) continue;
            final wx = rect.left + 4 + c * (rect.width - 8) / 2;
            final wy = rect.top + 8 + f * (rect.height - 14) / 5;
            if (wy < rect.bottom - 8) {
              canvas.drawRRect(
                RRect.fromRectAndRadius(
                    Rect.fromCenter(
                        center: Offset(wx, wy), width: rect.width * 0.22, height: 4),
                    const Radius.circular(1)),
                winPaint);
            }
          }
        }
      }
    }

    final ecg = Path();
    final segW = w * 0.8;
    final ex0 = (w - segW) / 2;
    const steps = 120;
    for (int s = 0; s <= steps; s++) {
      final t = s / steps;
      double y = 0.0;
      final p2 = (time * 0.35 + t) % 1.0;
      if (p2 > 0.40 && p2 < 0.46) {
        y = -0.12;
      } else if (p2 >= 0.46 && p2 < 0.50) {
        y = 0.28;
      } else if (p2 >= 0.50 && p2 < 0.54) {
        y = -0.95;
      } else if (p2 >= 0.54 && p2 < 0.58) {
        y = 0.34;
      } else if (p2 > 0.70 && p2 < 0.80) {
        y = -0.18;
      }
      final px = ex0 + t * segW;
      final py = baseY + y * h * 0.34;
      if (s == 0) {
        ecg.moveTo(px, py);
      } else {
        ecg.lineTo(px, py);
      }
    }
    canvas.drawPath(
      ecg,
      Paint()
        ..color = const Color(0xFFD4A537).withOpacity(0.25 + beatAbs * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(
      ecg,
      Paint()
        ..color = const Color(0xFFFFE9B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round);

    if (beatAbs > 0.3) {
      final ringPhase = ((pulse - 0.26) / 0.5).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(w / 2, baseY),
        40 + ringPhase * w * 0.55,
        Paint()
          ..color = const Color(0xFFD4A537)
              .withOpacity((1 - ringPhase) * beatAbs * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(CityPulsePainter old) => old.pulse != pulse || old.time != time;
}
'''
src = src + painter
open(p, 'wb').write(src.encode('utf-8'))
print('painter appended')
