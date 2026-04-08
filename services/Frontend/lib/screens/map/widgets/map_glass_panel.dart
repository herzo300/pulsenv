import 'package:flutter/material.dart';

import '../../../widgets/app_ui.dart';

/// Map screen glass panel — uses unified AppPanel with neo style.
/// This replaces the old NeoGlassPanel.
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
    // If custom borderColors or boxShadow provided, use neo style with borderColor
    final effectiveBorderColor = borderColor ??
        (borderColors != null && borderColors!.isNotEmpty
            ? borderColors![0]
            : null);

    return AppPanel(
      style: PanelStyle.neo,
      padding: padding ?? const EdgeInsets.all(16),
      backgroundColor: fillColor ?? const Color(0xCC151C2F),
      blurSigma: blurSigma ?? 20,
      borderColor: effectiveBorderColor,
      borderRadius: borderRadius,
      child: child,
    );
  }
}
