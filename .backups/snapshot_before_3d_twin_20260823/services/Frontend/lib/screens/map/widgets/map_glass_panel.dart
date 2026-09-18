import 'package:flutter/material.dart';

import '../../../widgets/app_ui.dart';

import '../../../widgets/weather_glass_overlay.dart';

/// Map screen glass panel — uses unified AppPanel with neo style & dynamic weather overlay.
class MapGlassPanel extends StatelessWidget {
  const MapGlassPanel({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.fillColor,
    this.blurSigma,
    this.borderColor,
    this.borderColors,
    this.boxShadow,
    this.tempC = -18.0,
    this.weatherMode = WeatherOverlayMode.none,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? fillColor;
  final double? blurSigma;
  final Color? borderColor;
  final List<Color>? borderColors;
  final List<BoxShadow>? boxShadow;
  final double tempC;
  final WeatherOverlayMode weatherMode;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ??
        (borderColors != null && borderColors!.isNotEmpty
            ? borderColors![0]
            : null);
    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);

    return WeatherGlassOverlay(
      mode: weatherMode,
      tempC: tempC,
      borderRadius: effectiveRadius,
      child: AppPanel(
        style: PanelStyle.neo,
        padding: padding ?? const EdgeInsets.all(16),
        backgroundColor: fillColor ?? const Color(0xCC151C2F),
        blurSigma: blurSigma ?? 20,
        borderColor: effectiveBorderColor,
        borderRadius: effectiveRadius,
        child: child,
      ),
    );
  }
}
