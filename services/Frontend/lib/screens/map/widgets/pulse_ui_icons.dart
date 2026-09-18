import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Custom pictograms for map chrome and inner screens — crisp at any DPI, no emoji.
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
  navigation,
  weather,
  lostAndFound,
  aiAssistant,
  jkh,
  petitions,
  security,
  gamification,
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
      case PulseUiIconKind.navigation:
        final nav = Path()
          ..moveTo(s * 0.5, s * 0.18)
          ..lineTo(s * 0.8, s * 0.8)
          ..lineTo(s * 0.5, s * 0.64)
          ..lineTo(s * 0.2, s * 0.8)
          ..close();
        canvas.drawPath(nav, paint);
      case PulseUiIconKind.weather:
        canvas.drawCircle(Offset(s * 0.4, s * 0.44), s * 0.18, paint);
        final cloud = Path()
          ..moveTo(s * 0.26, s * 0.72)
          ..lineTo(s * 0.74, s * 0.72)
          ..addArc(Rect.fromCircle(center: Offset(s * 0.68, s * 0.62), radius: s * 0.12), -math.pi * 0.5, math.pi)
          ..addArc(Rect.fromCircle(center: Offset(s * 0.48, s * 0.54), radius: s * 0.16), -math.pi, math.pi * 1.2);
        canvas.drawPath(cloud, paint);
      case PulseUiIconKind.lostAndFound:
        canvas.drawCircle(Offset(s * 0.42, s * 0.42), s * 0.22, paint);
        canvas.drawLine(Offset(s * 0.58, s * 0.58), Offset(s * 0.8, s * 0.8), paint..strokeWidth = s * 0.09);
        canvas.drawCircle(Offset(s * 0.42, s * 0.42), s * 0.08, fill);
      case PulseUiIconKind.aiAssistant:
        final head = RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.24, s * 0.32, s * 0.52, s * 0.44),
          Radius.circular(s * 0.12),
        );
        canvas.drawRRect(head, paint);
        canvas.drawCircle(Offset(s * 0.38, s * 0.52), s * 0.05, fill);
        canvas.drawCircle(Offset(s * 0.62, s * 0.52), s * 0.05, fill);
        canvas.drawLine(Offset(s * 0.5, s * 0.18), Offset(s * 0.5, s * 0.32), paint);
        canvas.drawCircle(Offset(s * 0.5, s * 0.16), s * 0.04, fill);
      case PulseUiIconKind.jkh:
        final house = Path()
          ..moveTo(s * 0.5, s * 0.18)
          ..lineTo(s * 0.82, s * 0.45)
          ..lineTo(s * 0.82, s * 0.82)
          ..lineTo(s * 0.18, s * 0.82)
          ..lineTo(s * 0.18, s * 0.45)
          ..close();
        canvas.drawPath(house, paint);
        canvas.drawRect(Rect.fromLTWH(s * 0.4, s * 0.56, s * 0.2, s * 0.26), paint);
      case PulseUiIconKind.petitions:
        final doc = RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.24, s * 0.2, s * 0.52, s * 0.64),
          Radius.circular(s * 0.06),
        );
        canvas.drawRRect(doc, paint);
        canvas.drawLine(Offset(s * 0.34, s * 0.38), Offset(s * 0.66, s * 0.38), paint);
        canvas.drawLine(Offset(s * 0.34, s * 0.52), Offset(s * 0.66, s * 0.52), paint);
        canvas.drawLine(Offset(s * 0.34, s * 0.66), Offset(s * 0.54, s * 0.66), paint);
      case PulseUiIconKind.security:
        final shield = Path()
          ..moveTo(s * 0.5, s * 0.18)
          ..lineTo(s * 0.8, s * 0.28)
          ..lineTo(s * 0.8, s * 0.56)
          ..quadraticBezierTo(s * 0.8, s * 0.8, s * 0.5, s * 0.88)
          ..quadraticBezierTo(s * 0.2, s * 0.8, s * 0.2, s * 0.56)
          ..lineTo(s * 0.2, s * 0.28)
          ..close();
        canvas.drawPath(shield, paint);
      case PulseUiIconKind.gamification:
        final star = Path();
        for (var i = 0; i < 5; i++) {
          final a1 = -math.pi / 2 + i * math.pi * 2 / 5;
          final a2 = a1 + math.pi / 5;
          final p1 = c + Offset(math.cos(a1), math.sin(a1)) * s * 0.36;
          final p2 = c + Offset(math.cos(a2), math.sin(a2)) * s * 0.18;
          if (i == 0) star.moveTo(p1.dx, p1.dy);
          else star.lineTo(p1.dx, p1.dy);
          star.lineTo(p2.dx, p2.dy);
        }
        star.close();
        canvas.drawPath(star, paint);
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
