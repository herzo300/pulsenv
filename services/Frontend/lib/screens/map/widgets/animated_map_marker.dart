import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MarkerShell {
  circle,
  roundedSquare,
  diamond,
  hexagon,
  shield,
}

class _HexagonClipper extends CustomClipper<Path> {
  const _HexagonClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.28)
      ..lineTo(size.width, size.height * 0.72)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height * 0.72)
      ..lineTo(0, size.height * 0.28)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ShieldClipper extends CustomClipper<Path> {
  const _ShieldClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.12)
      ..quadraticBezierTo(
        size.width * 0.5,
        0,
        size.width * 0.84,
        size.height * 0.12,
      )
      ..lineTo(size.width * 0.84, size.height * 0.56)
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.8,
        size.width * 0.5,
        size.height,
      )
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height * 0.8,
        size.width * 0.16,
        size.height * 0.56,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class AnimatedMapMarker extends StatelessWidget {
  const AnimatedMapMarker({super.key, 
    required this.animation,
    required this.color,
    required this.icon,
    required this.size,
    required this.seed,
    required this.isDayMode,
    required this.shell,
  });

  final Animation<double> animation;
  final Color color;
  final IconData icon;
  final double size;
  final double seed;
  final bool isDayMode;
  final MarkerShell shell;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final phase = (animation.value + seed) % 1.0;
        final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
        final ringScale = 1 + wave * 0.38;
        final glowOpacity = isDayMode ? 0.10 + wave * 0.08 : 0.24 + wave * 0.24;
        final coreScale = 0.97 + wave * 0.06;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: _buildShell(
                  size: size * 0.88,
                  shell: shell,
                  color: color.withAlpha((glowOpacity * 110).round()),
                  borderColor: color.withAlpha(
                    (glowOpacity * (isDayMode ? 120 : 180)).round(),
                  ),
                  borderWidth: 1.1,
                  shadow: BoxShadow(
                    color: color.withAlpha(
                      (glowOpacity * (isDayMode ? 140 : 190)).round(),
                    ),
                    blurRadius: isDayMode ? 9 : 20,
                    spreadRadius: isDayMode ? 1 : 3,
                  ),
                ),
              ),
              Transform.scale(
                scale: coreScale,
                child: _buildShell(
                  size: size * 0.72,
                  shell: shell,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withAlpha(isDayMode ? 226 : 255),
                      color.withAlpha(isDayMode ? 144 : 210),
                    ],
                  ),
                  borderColor: Colors.white.withAlpha(isDayMode ? 190 : 245),
                  borderWidth: 1.4,
                  shadow: BoxShadow(
                    color: Colors.black.withAlpha(isDayMode ? 22 : 80),
                    blurRadius: isDayMode ? 8 : 10,
                    spreadRadius: isDayMode ? 0 : 1,
                  ),
                  child: Icon(
                    icon,
                    color: isDayMode ? const Color(0xFF04243C) : Colors.white,
                    size: size * 0.34,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShell({
    required double size,
    required MarkerShell shell,
    required Color borderColor,
    required double borderWidth,
    Color? color,
    Gradient? gradient,
    BoxShadow? shadow,
    Widget? child,
  }) {
    final decoration = BoxDecoration(
      color: color,
      gradient: gradient,
      borderRadius: shell == MarkerShell.roundedSquare
          ? BorderRadius.circular(size * 0.24)
          : shell == MarkerShell.diamond
              ? BorderRadius.circular(size * 0.18)
              : null,
      shape: shell == MarkerShell.circle ? BoxShape.circle : BoxShape.rectangle,
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: shadow == null ? null : <BoxShadow>[shadow],
    );

    Widget current = Container(
      width: size,
      height: size,
      decoration: decoration,
      child: child == null ? null : Center(child: child),
    );

    if (shell == MarkerShell.diamond) {
      current = Transform.rotate(angle: math.pi / 4, child: current);
    }

    if (shell == MarkerShell.hexagon) {
      current = ClipPath(clipper: const _HexagonClipper(), child: current);
    } else if (shell == MarkerShell.shield) {
      current = ClipPath(clipper: const _ShieldClipper(), child: current);
    }

    return current;
  }
}
