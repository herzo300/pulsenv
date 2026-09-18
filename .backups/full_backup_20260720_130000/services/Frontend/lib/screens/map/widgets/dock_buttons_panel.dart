// lib/screens/map/widgets/dock_buttons_panel.dart
//
// Извлечённая из map_screen.dart панель кнопок-дока (локация, слои,
// AR-камера, переключатель стиля карты).
//
// RepaintBoundary гарантирует, что анимация нажатий на кнопки дока
// не инвалидирует слой карты целиком.
//
// Item 6 (CityPulse_Improvements.md): UX/UI и Перформанс.
import 'package:flutter/material.dart';

import '../../../theme/pulse_colors.dart';

/// Одна кнопка дока с иконкой + подписью.
class DockButton {
  const DockButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final bool isActive;
}

/// Плавающая панель кнопок внизу/сбоку карты.
class DockButtonsPanel extends StatelessWidget {
  const DockButtonsPanel({
    super.key,
    required this.buttons,
    this.alignment = DockAlignment.bottom,
  });

  final List<DockButton> buttons;
  final DockAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: PulseColors.backgroundRaised.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: PulseColors.primary.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: alignment == DockAlignment.bottom
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: buttons
                    .map((b) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _DockButtonView(button: b),
                        ))
                    .toList(),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: buttons
                    .map((b) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: _DockButtonView(button: b),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

enum DockAlignment { bottom, side }

class _DockButtonView extends StatelessWidget {
  const _DockButtonView({required this.button});
  final DockButton button;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: button.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: button.isActive
              ? PulseColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  button.icon,
                  color: button.isActive
                      ? PulseColors.primary
                      : PulseColors.textPrimary,
                  size: 30,
                ),
                if (button.badge != null)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: PulseColors.backgroundRaised, width: 1),
                      ),
                      constraints: const BoxConstraints(minWidth: 14),
                      child: Text(
                        button.badge!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              button.label,
              style: TextStyle(
                color: PulseColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
