import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Custom pictograms for map chrome — crisp at any DPI, no emoji.
enum PulseUiIconKind {
  pulseMark,
  signals,
  events,
  cameras,
  mapLayers,
  digest,
  menu,
  profile,
  uk,
  infographic,
  mesh,
  settings,
  stats,
  themeDay,
  themeNight,
  about,
  secret,
  chevron,
}

class PulseUiIcon extends StatelessWidget {
  const PulseUiIcon({
    super.key,
    required this.kind,
    this.size = 20,
    this.color = Colors.white,
  });

  final PulseUiIconKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (kind == PulseUiIconKind.pulseMark) {
      return SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(
          'assets/animations/pulse.json',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _PulseUiIconPainter(kind: kind, color: color),
    );
  }
}

class _PulseUiIconPainter extends CustomPainter {
  _PulseUiIconPainter({required this.kind, required this.color});

  final PulseUiIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.078
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final s = size.width;
    final c = Offset(s / 2, s / 2);

    switch (kind) {
      case PulseUiIconKind.pulseMark:
        _drawPulseMark(canvas, size, paint, fill);
      case PulseUiIconKind.signals:
        canvas.drawCircle(c, s * 0.11, fill);
        canvas.drawCircle(c, s * 0.28, paint..strokeWidth = s * 0.06);
        canvas.drawCircle(c, s * 0.42, paint);
        canvas.drawLine(
          Offset(c.dx, s * 0.58),
          Offset(c.dx, s * 0.9),
          paint,
        );
      case PulseUiIconKind.events:
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.18, s * 0.2, s * 0.64, s * 0.62),
          Radius.circular(s * 0.1),
        );
        canvas.drawRRect(r, paint);
        canvas.drawLine(
          Offset(s * 0.34, s * 0.12),
          Offset(s * 0.34, s * 0.28),
          paint,
        );
        canvas.drawLine(
          Offset(s * 0.66, s * 0.12),
          Offset(s * 0.66, s * 0.28),
          paint,
        );
        canvas.drawCircle(Offset(s * 0.58, s * 0.56), s * 0.07, fill);
      case PulseUiIconKind.cameras:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.12, s * 0.3, s * 0.76, s * 0.46),
            Radius.circular(s * 0.1),
          ),
          paint,
        );
        canvas.drawCircle(Offset(s * 0.5, s * 0.53), s * 0.14, paint);
        canvas.drawCircle(Offset(s * 0.5, s * 0.53), s * 0.05, fill);
        canvas.drawLine(
          Offset(s * 0.5, s * 0.3),
          Offset(s * 0.62, s * 0.16),
          paint,
        );
      case PulseUiIconKind.mapLayers:
        final path = Path()
          ..moveTo(s * 0.22, s * 0.34)
          ..lineTo(s * 0.5, s * 0.18)
          ..lineTo(s * 0.78, s * 0.34)
          ..lineTo(s * 0.5, s * 0.5)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(
          path.shift(Offset(0, s * 0.22)),
          paint..color = color.withAlpha(170),
        );
      case PulseUiIconKind.digest:
        for (var i = 0; i < 3; i++) {
          final angle = -math.pi / 2 + i * (2 * math.pi / 3);
          final p = c + Offset(math.cos(angle), math.sin(angle)) * s * 0.28;
          canvas.drawLine(c, p, paint);
          canvas.drawCircle(p, s * 0.06, fill);
        }
      case PulseUiIconKind.menu:
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 3; col++) {
            canvas.drawCircle(
              Offset(s * (0.26 + col * 0.24), s * (0.26 + row * 0.24)),
              s * 0.07,
              fill,
            );
          }
        }
      case PulseUiIconKind.profile:
        canvas.drawCircle(Offset(s * 0.5, s * 0.34), s * 0.16, paint);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(s * 0.5, s * 0.78), width: s * 0.56, height: s * 0.42),
          math.pi,
          math.pi,
          false,
          paint,
        );
      case PulseUiIconKind.uk:
        canvas.drawRect(Rect.fromLTWH(s * 0.22, s * 0.24, s * 0.56, s * 0.58), paint);
        canvas.drawLine(Offset(s * 0.22, s * 0.42), Offset(s * 0.78, s * 0.42), paint);
        canvas.drawLine(Offset(s * 0.42, s * 0.42), Offset(s * 0.42, s * 0.82), paint);
        canvas.drawLine(Offset(s * 0.58, s * 0.42), Offset(s * 0.58, s * 0.82), paint);
      case PulseUiIconKind.infographic:
        canvas.drawLine(Offset(s * 0.22, s * 0.78), Offset(s * 0.78, s * 0.78), paint);
        canvas.drawLine(Offset(s * 0.3, s * 0.78), Offset(s * 0.3, s * 0.48), paint);
        canvas.drawLine(Offset(s * 0.5, s * 0.78), Offset(s * 0.5, s * 0.3), paint);
        canvas.drawLine(Offset(s * 0.7, s * 0.78), Offset(s * 0.7, s * 0.56), paint);
      case PulseUiIconKind.mesh:
        final nodes = [
          Offset(s * 0.5, s * 0.22),
          Offset(s * 0.22, s * 0.72),
          Offset(s * 0.78, s * 0.72),
        ];
        for (final a in nodes) {
          for (final b in nodes) {
            if (a != b) canvas.drawLine(a, b, paint..color = color.withAlpha(120));
          }
        }
        for (final n in nodes) {
          canvas.drawCircle(n, s * 0.09, fill);
        }
      case PulseUiIconKind.settings:
        canvas.drawCircle(c, s * 0.2, paint);
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * s * 0.24,
            c + Offset(math.cos(a), math.sin(a)) * s * 0.38,
            paint,
          );
        }
        canvas.drawCircle(c, s * 0.16, paint);
      case PulseUiIconKind.stats:
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: s * 0.34),
          -math.pi * 0.85,
          math.pi * 1.2,
          false,
          paint..strokeWidth = s * 0.1,
        );
        canvas.drawLine(
          Offset(s * 0.5, s * 0.5),
          Offset(s * 0.68, s * 0.34),
          paint..strokeWidth = s * 0.08,
        );
      case PulseUiIconKind.themeDay:
        canvas.drawCircle(c, s * 0.18, fill);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * s * 0.28,
            c + Offset(math.cos(a), math.sin(a)) * s * 0.4,
            paint,
          );
        }
      case PulseUiIconKind.themeNight:
        final moon = Path()
          ..addArc(Rect.fromCircle(center: c, radius: s * 0.28), 0.8, math.pi * 1.5);
        canvas.drawPath(moon, paint);
      case PulseUiIconKind.about:
        canvas.drawCircle(c, s * 0.38, paint);
        canvas.drawLine(Offset(s * 0.5, s * 0.3), Offset(s * 0.5, s * 0.56), paint);
        canvas.drawCircle(Offset(s * 0.5, s * 0.7), s * 0.05, fill);
      case PulseUiIconKind.secret:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.24, s * 0.44, s * 0.52, s * 0.4),
            Radius.circular(s * 0.08),
          ),
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: Offset(s * 0.5, s * 0.44), width: s * 0.34, height: s * 0.34),
          math.pi,
          math.pi,
          false,
          paint,
        );
      case PulseUiIconKind.chevron:
        final p = Path()
          ..moveTo(s * 0.38, s * 0.28)
          ..lineTo(s * 0.62, s * 0.5)
          ..lineTo(s * 0.38, s * 0.72);
        canvas.drawPath(p, paint);
    }
  }

  void _drawPulseMark(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.12, s * 0.56)
      ..lineTo(s * 0.28, s * 0.56)
      ..lineTo(s * 0.38, s * 0.28)
      ..lineTo(s * 0.5, s * 0.74)
      ..lineTo(s * 0.62, s * 0.42)
      ..lineTo(s * 0.72, s * 0.56)
      ..lineTo(s * 0.88, s * 0.56);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(Offset(s * 0.5, s * 0.74), s * 0.07, fill);
  }

  @override
  bool shouldRepaint(covariant _PulseUiIconPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}
