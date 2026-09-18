/// Shared glass-morphic panel for infographic widgets.
/// Uses unified AppPanel with aurora style.
/// This replaces the old GlassPanel.
library;

import 'package:flutter/material.dart';

import '../../../theme/pulse_colors.dart';
import '../../../widgets/app_ui.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.accent,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Color accent;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      style: PanelStyle.aurora,
      accent: accent,
      padding: padding,
      borderRadius: AppRadii.lg,
      showAuroraGlow: true,
      backgroundColor: PulseColors.surfaceGlass,
      child: child,
    );
  }
}
