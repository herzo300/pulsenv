// lib/widgets/pulse_icons.dart
//
// Единый каталог кастомных SVG-иконок City Pulse.
//
// Заменяют Material Icons на фирменный набор (единая обводка 2px, скруглённые
// концы) — это убирает «дешёвый» дефолтный вид и добавляет узнаваемость.
//
// Использование:
//   PulseIcon(PulseIcons.complaint, size: 24)
//   PulseIcon(PulseIcons.map, color: PulseColors.primary)
//
// Дизайн-рекомендация 4: Кастомные SVG иконки (единый стиль).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Имена доступных фирменных иконок.
abstract final class PulseIcons {
  PulseIcons._();

  static const complaint = 'assets/icons/complaint.svg';
  static const map = 'assets/icons/map.svg';
  static const camera = 'assets/icons/camera.svg';
  static const trophy = 'assets/icons/trophy.svg';
  static const weather = 'assets/icons/weather.svg';
  static const profile = 'assets/icons/profile.svg';
  static const qr = 'assets/icons/qr.svg';
  static const receipt = 'assets/icons/receipt.svg';

  // Фирменный набор «Пульс Города»: ночной градиент 0F172A→0B132B,
  // циановая обводка #00E5FF с акцентными градиентами.
  static const signal = 'assets/icons/pulse_signal.svg';
  static const hermes = 'assets/icons/pulse_hermes.svg';
  static const lostFound = 'assets/icons/pulse_lost.svg';
  static const twin = 'assets/icons/pulse_twin.svg';
}

/// Виджет фирменной иконки.
///
/// По умолчанию наследует цвет от IconTheme/currentColor в SVG,
/// что позволяет использовать его как обычный Icon.
class PulseIcon extends StatelessWidget {
  const PulseIcon(
    this.assetName, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  /// Путь к SVG (одна из констант [PulseIcons]).
  final String assetName;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
  }
}
