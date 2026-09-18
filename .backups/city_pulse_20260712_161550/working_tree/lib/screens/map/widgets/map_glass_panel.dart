import 'package:flutter/material.dart';

import '../../../theme/theme_provider.dart';
import '../../../widgets/app_ui.dart';

/// Map screen glass panel — uses unified AppPanel with neo style.
/// Automatically adapts to day/night mode:
///   Night → dark translucent glass fill
///   Day   → white opaque fill with subtle shadow
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
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? fillColor;
  final double? blurSigma;
  final Color? borderColor;
  final List<Color>? borderColors;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final isNight = ThemeProvider.instance.isDarkMode;

    final effectiveBorderColor = borderColor ??
        (borderColors != null && borderColors!.isNotEmpty
            ? borderColors![0]
            : null);

    // In day mode: white glass fill; in night mode: dark glass fill
    final effectiveFill = fillColor ??
        (isNight
            ? const Color(0xCC151C2F)
            : Colors.white.withOpacity(0.55)); // Transparent white glass

    final effectiveBorder = effectiveBorderColor ??
        (isNight ? null : Colors.white.withOpacity(0.8)); // Glossy edge

    return AppPanel(
      style: PanelStyle.neo,
      padding: padding ?? const EdgeInsets.all(16),
      backgroundColor: effectiveFill,
      blurSigma: blurSigma ?? (isNight ? 20 : 18),
      borderColor: effectiveBorder,
      borderRadius: borderRadius,
      child: child,
    );
  }
}
