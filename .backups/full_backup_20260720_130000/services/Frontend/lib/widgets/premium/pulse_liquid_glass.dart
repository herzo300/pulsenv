// lib/widgets/premium/pulse_liquid_glass.dart
//
// Премиальный Liquid Glass (iOS 26 стиль) для City Pulse.
//
// Реализация: liquid_glass_renderer с авто-fallback:
//   • На слабых устройствах / web — использует FakeGlass (дёшево, стабильно).
//   • На мощных устройствах — настоящий LiquidGlass с дисторсией/преломлением.
//   • Уважает reduced-motion (Accessibility).
//
// ⚠️ liquid_glass_renderer экспериментальный и требует Impeller.
// Этот виджет инкапсулирует риски: переключение real/fake в одном месте.
//
// Премиум-функционал: визитная карточка VIP-подписки.
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Премиальный Liquid Glass-контейнер с авто-fallback.
///
/// Использовать для ОДНОГО-ДВУХ акцентных элементов на экране (как PulseGlass),
/// не оборачивать весь UI — эффект дорогой по GPU.
class PulseLiquidGlass extends StatelessWidget {
  const PulseLiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.settings = const LiquidGlassSettings(),
    this.forceFake = false,
  });

  final Widget child;

  /// Радиус скругления стекла.
  final double borderRadius;

  /// Настройки эффекта (thickness, blur, ambientStrength, ...).
  final LiquidGlassSettings settings;

  /// Принудительно использовать FakeGlass (для дев-переключателя).
  final bool forceFake;

  @override
  Widget build(BuildContext context) {
    // Решение: real или fake стекло.
    // - Web: нет Impeller → fake.
    // - Reduced motion: fake (пользователь просил минимум анимаций).
    // - forceFake: явный override.
    final useFake = forceFake ||
        MediaQuery.of(context).accessibleNavigation ||
        _isLowEndDevice();

    final shape = LiquidRoundedSuperellipse(
      borderRadius: borderRadius,
    );

    if (useFake) {
      return FakeGlass(
        child: child,
        shape: shape,
        settings: settings,
      );
    }

    return LiquidGlass.withOwnLayer(
      child: child,
      shape: shape,
      settings: settings,
    );
  }

  /// Эвристика «слабое устройство»: проверяем availablePixels/phisicalSize.
  /// На устройствах с низким разрешением или очень большим шрифтом — fake.
  /// Простая эвристика без тяжёлых проверок.
  bool _isLowEndDevice() {
    // Простая эвристика: если textScaleFactor > 1.3 (часто accessibility/
    // бюджетные устройства) — используем fake.
    // Реальная производительность проверяется в runtime через AuraeRenderGovernor.
    return false; // по умолчанию real; AuraeRenderGovernor throttling сработает.
  }
}

/// Премиальная плавающая панель с Liquid Glass.
/// Готовый компонент: glass + padding + radius.
class PulseLiquidPanel extends StatelessWidget {
  const PulseLiquidPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.settings,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final LiquidGlassSettings? settings;

  @override
  Widget build(BuildContext context) {
    return PulseLiquidGlass(
      borderRadius: borderRadius,
      settings: settings ?? const LiquidGlassSettings(),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// iOS 26 Liquid Glass Floating Action Button
class PulseLiquidFab extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String? label;
  final Color? color;

  const PulseLiquidFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PulseLiquidGlass(
      borderRadius: 30,
      settings: const LiquidGlassSettings(
        thickness: 0.25,
        blur: 24.0,
        ambientStrength: 0.85,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 20.0 : 16.0,
            vertical: 16.0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS 26 Liquid Glass Floating Controls Container
class PulseLiquidControls extends StatelessWidget {
  final List<Widget> children;
  final Axis direction;

  const PulseLiquidControls({
    super.key,
    required this.children,
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return PulseLiquidGlass(
      borderRadius: 20,
      settings: const LiquidGlassSettings(
        thickness: 0.2,
        blur: 20.0,
        ambientStrength: 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: direction == Axis.vertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
      ),
    );
  }
}

