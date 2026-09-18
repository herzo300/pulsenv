import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  const AnimatedMapMarker({
    super.key,
    required this.animation,
    required this.color,
    required this.icon,
    required this.size,
    required this.seed,
    required this.isDayMode,
    required this.shell,
    this.animate = true,
    this.highlighted = false,
    this.heroTag,
    this.custom3dAsset,
  });

  final Animation<double> animation;
  final Color color;
  final IconData icon;
  final double size;
  final double seed;
  final bool isDayMode;
  final MarkerShell shell;
  final bool animate;
  final bool highlighted;
  final String? heroTag;
  final String? custom3dAsset;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (!animate) {
      child = _buildMarkerBody(phase: 0.42);
      return RepaintBoundary(
        child: child
            .animate()
            .fadeIn(duration: 250.ms)
            .scale(
              duration: 250.ms,
              begin: const Offset(0.8, 0.8),
              curve: Curves.easeOut,
            ),
      );
    } else {
      child = AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final phase = (animation.value + seed) % 1.0;
          return _buildMarkerBody(phase: phase);
        },
      );
      return RepaintBoundary(
        child: child
            .animate()
            .fadeIn(duration: 350.ms)
            .scale(
              duration: 450.ms,
              begin: const Offset(0.3, 0.3),
              curve: Curves.easeOutBack,
            ),
      );
    }
  }

  Widget _buildMarkerBody({required double phase}) {
    if (shell == MarkerShell.circle) {
      // Keep original circle vector marker for cameras
      final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
      final ringBoost = highlighted ? 0.22 : 0.0;
      final ringScale = 1 + wave * (0.38 + ringBoost);
      final glowOpacity = highlighted
          ? 0.34 + wave * 0.34
          : isDayMode
              ? 0.10 + wave * 0.08
              : 0.24 + wave * 0.24;
      final coreScale = highlighted
          ? 0.94 + wave * 0.1
          : 0.97 + wave * 0.06;

      final iconWidget = Icon(
        icon,
        color: isDayMode ? const Color(0xFF04243C) : Colors.white,
        size: size * 0.34,
      );

      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // "City Pulse" concentric waves (Circle shell)
            for (int i = 0; i < 3; i++)
              Builder(
                builder: (context) {
                  final wavePhase = (phase + i * 0.33) % 1.0;
                  final waveScale = 0.5 + wavePhase * 1.5;
                  final waveOpacity = (1.0 - wavePhase) * (highlighted ? 0.55 : 0.28);
                  return Transform.scale(
                    scale: waveScale,
                    child: Opacity(
                      opacity: waveOpacity,
                      child: Container(
                        width: size * 0.8,
                        height: size * 0.8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (highlighted)
              Transform.scale(
                scale: 1 + wave * 0.62,
                child: _buildShell(
                  size: size * 0.98,
                  shell: shell,
                  color: color.withAlpha((glowOpacity * 55).round()),
                  borderColor: color.withAlpha((glowOpacity * 90).round()),
                  borderWidth: 1.4,
                  shadow: BoxShadow(
                    color: color.withAlpha((glowOpacity * 120).round()),
                    blurRadius: 22,
                    spreadRadius: 4,
                  ),
                ),
              ),
            Transform.scale(
              scale: ringScale,
              child: _buildShell(
                size: size * 0.88,
                shell: shell,
                color: color.withAlpha((glowOpacity * 110).round()),
                borderColor: color.withAlpha(
                  (glowOpacity * (isDayMode ? 120 : 180)).round(),
                ),
                borderWidth: highlighted ? 1.6 : 1.1,
                shadow: BoxShadow(
                  color: color.withAlpha(
                    (glowOpacity * (highlighted ? 220 : (isDayMode ? 140 : 190)))
                        .round(),
                  ),
                  blurRadius: highlighted ? 24 : (isDayMode ? 9 : 20),
                  spreadRadius: highlighted ? 4 : (isDayMode ? 1 : 3),
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
                    color.withAlpha(
                      highlighted ? 255 : (isDayMode ? 226 : 255),
                    ),
                    color.withAlpha(
                      highlighted ? 230 : (isDayMode ? 144 : 210),
                    ),
                  ],
                ),
                borderColor: Colors.white.withAlpha(
                  highlighted ? 255 : (isDayMode ? 190 : 245),
                ),
                borderWidth: highlighted ? 1.8 : 1.4,
                shadow: BoxShadow(
                  color: Colors.black.withAlpha(
                    highlighted ? 60 : (isDayMode ? 22 : 80),
                  ),
                  blurRadius: highlighted ? 12 : (isDayMode ? 8 : 10),
                  spreadRadius: highlighted ? 1 : (isDayMode ? 0 : 1),
                ),
                child: heroTag != null
                    ? Hero(
                        tag: heroTag!,
                        child: Material(
                          color: Colors.transparent,
                          child: iconWidget,
                        ),
                      )
                    : iconWidget,
              ),
            ),
          ],
        ),
      );
    }

    // 3D Marker for other categories (problems and events)
    final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
    final scale = highlighted ? (1.05 + wave * 0.08) : (0.96 + wave * 0.04);
    
    // Choose 3D pin asset
    String assetPath = 'assets/3d_pin_red.png';
    bool isCustom3d = true;
    
    if (custom3dAsset != null) {
      assetPath = custom3dAsset!;
    } else if (icon == Icons.smartphone_rounded || icon == Icons.phone_android_rounded || icon == Icons.phone_iphone_rounded) {
      assetPath = 'assets/3d_icons/smartphone_3d.png';
    } else if (icon == Icons.warning_rounded || icon == Icons.local_fire_department_rounded || icon == Icons.fire_extinguisher_rounded) {
      assetPath = 'assets/3d_icons/chp_3d.png';
    } else if (icon == Icons.plumbing_rounded || icon == Icons.home_work_rounded) {
      assetPath = 'assets/3d_icons/gkh_3d.png';
    } else if (icon == Icons.edit_road_rounded) {
      assetPath = 'assets/3d_icons/dorogi_3d.png';
    } else if (icon == Icons.lightbulb_rounded || icon == Icons.lightbulb_outline_rounded) {
      assetPath = 'assets/3d_icons/light_3d.png';
    } else if (icon == Icons.commute_rounded || icon == Icons.directions_bus_rounded) {
      assetPath = 'assets/3d_icons/transport_3d.png';
    } else if (icon == Icons.eco_rounded) {
      assetPath = 'assets/3d_icons/ecology_3d.png';
    } else if (icon == Icons.shield_rounded) {
      assetPath = 'assets/3d_icons/security_3d.png';
    } else if (icon == Icons.ac_unit_rounded) {
      assetPath = 'assets/3d_icons/snow_3d.png';
    } else if (icon == Icons.medical_services_rounded) {
      assetPath = 'assets/3d_icons/medicine_3d.png';
    } else if (icon == Icons.school_rounded) {
      assetPath = 'assets/3d_icons/education_3d.png';
    } else if (icon == Icons.local_parking_rounded || icon == Icons.car_crash_rounded || icon == Icons.directions_car_rounded) {
      assetPath = 'assets/3d_icons/parking_3d.png';
    } else if (icon == Icons.engineering_rounded) {
      assetPath = 'assets/3d_icons/construction_3d.png';
    } else if (icon == Icons.pets_rounded) {
      assetPath = 'assets/3d_icons/animals_3d.png';
    } else if (icon == Icons.shopping_bag_rounded || icon == Icons.inventory_2_outlined || icon == Icons.inventory_2_rounded) {
      assetPath = 'assets/3d_icons/items_3d.png';
    } else if (icon == Icons.celebration_rounded || icon == Icons.local_activity_rounded || icon == Icons.event_rounded) {
      assetPath = 'assets/3d_icons/event_3d.png';
    } else if (icon == Icons.more_horiz_rounded || icon == Icons.info_rounded || icon == Icons.info_outline_rounded || icon == Icons.info) {
      assetPath = 'assets/3d_icons/other_3d.png';
    } else if (icon == Icons.videocam_rounded || icon == Icons.star_rounded) {
      assetPath = 'assets/3d_icons/other_3d.png';
    } else if (icon == Icons.warning_amber_rounded) {
      assetPath = 'assets/3d_icons/chp_3d.png';
    } else if (icon == Icons.local_gas_station_rounded) {
      assetPath = 'assets/3d_icons/gas_station_3d.png';
    } else if (icon == Icons.delete_sweep_rounded || icon == Icons.delete_outline_rounded || icon == Icons.delete_rounded) {
      assetPath = 'assets/3d_icons/garbage_3d.png';
    } else {
      isCustom3d = false;
      if (color.red < 100 && color.green > 150 && color.blue < 150) {
        assetPath = 'assets/3d_pin_green.png';
      } else if (color == const Color(0xFF8B5CF6) || color.blue > 200 && color.red < 100) {
        assetPath = 'assets/3d_pin_blue.png';
      }
    }

    final iconWidget = Icon(
      icon,
      color: Colors.white,
      size: size * 0.28,
      shadows: const [
        Shadow(
          color: Colors.black54,
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    );

    final floatY = highlighted ? math.sin(phase * math.pi * 2) * 4.5 - 2.5 : 0.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // "City Pulse" concentric waves (3D Pin)
          for (int i = 0; i < 3; i++)
            Builder(
              builder: (context) {
                final wavePhase = (phase + i * 0.33) % 1.0;
                final waveScale = 0.5 + wavePhase * 1.6;
                final waveOpacity = (1.0 - wavePhase) * (highlighted ? 0.6 : 0.32);
                return Transform.scale(
                  scale: waveScale,
                  child: Opacity(
                    opacity: waveOpacity,
                    child: Container(
                      width: size * 0.8,
                      height: size * 0.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Oval floating shadow under the 3D pin (stays on map surface)
          Positioned(
            bottom: size * 0.08,
            child: Transform.scale(
              scale: scale * 1.05,
              child: Opacity(
                opacity: highlighted ? 0.22 + wave * 0.10 : 0.10 + wave * 0.05,
                child: Container(
                  width: size * 0.55,
                  height: size * 0.22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(size * 0.28, size * 0.11)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: highlighted ? 14 : 7,
                        spreadRadius: highlighted ? 2 : 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 3D Pin image & Category Icon (they hover together)
          Transform.translate(
            offset: Offset(0, floatY),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Category-colored neon glow backdrop (all custom 3D icons)
                if (isCustom3d)
                  Transform.scale(
                    scale: scale * (1.05 + wave * 0.06),
                    child: Container(
                      width: size * 0.62,
                      height: size * 0.62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(
                              highlighted ? (0.55 + wave * 0.35) : (0.25 + wave * 0.15),
                            ),
                            blurRadius: highlighted ? (18 + wave * 8) : (10 + wave * 4),
                            spreadRadius: highlighted ? 4.0 : 1.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                // 3D rendered icon with scale animation
                Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    assetPath,
                    width: size * 0.92,
                    height: size * 0.92,
                    fit: BoxFit.contain,
                  ),
                ),
                // Shimmer overlay on highlighted 3D icons
                if (isCustom3d && highlighted)
                  Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: 0.12 + wave * 0.08,
                      child: Container(
                        width: size * 0.56,
                        height: size * 0.56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.35),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!isCustom3d)
                  Positioned(
                    top: size * 0.14,
                    child: Transform.scale(
                      scale: scale,
                      child: heroTag != null
                          ? Hero(
                              tag: heroTag!,
                              child: Material(
                                color: Colors.transparent,
                                child: iconWidget,
                              ),
                            )
                          : iconWidget,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    Widget? finalChild = child;
    if (finalChild != null && shell == MarkerShell.diamond) {
      finalChild = Transform.rotate(
        angle: -math.pi / 4,
        child: finalChild,
      );
    }

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
      child: finalChild == null ? null : Center(child: finalChild),
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
