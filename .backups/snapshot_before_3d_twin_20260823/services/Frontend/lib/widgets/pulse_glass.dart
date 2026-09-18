// lib/widgets/pulse_glass.dart
//
// Glassmorphism-обёртка с дисциплиной (restraint).
//
// ПРАВИЛО: glass = акцент на ОДИН элемент на экран, не фон.
// Премиум-дизайн = то, что убрано, а не добавлено. Лишний blur удешевляет.
//
// Дизайн-рекомендация 5: Glassmorphism с restraint (1 элемент/экран).
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'premium/pulse_liquid_glass.dart';

/// Glass-контейнер с blur-фоном и преломлением (iOS 26 Liquid Glass).
class PulseGlass extends StatelessWidget {
  const PulseGlass({
    super.key,
    required this.child,
    this.blurSigma = 18,
    this.opacity = 0.7,
    this.borderRadius = 20,
    this.showBorder = true,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  /// Сила размытия фона.
  final double blurSigma;

  /// Непрозрачность tint-цвета.
  final double opacity;

  final double borderRadius;
  final bool showBorder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return PulseLiquidGlass(
      borderRadius: borderRadius,
      settings: LiquidGlassSettings(
        thickness: 0.15,
        blur: blurSigma,
        ambientStrength: opacity,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
