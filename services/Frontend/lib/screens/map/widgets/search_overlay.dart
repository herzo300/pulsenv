// lib/screens/map/widgets/search_overlay.dart
//
// Извлечённый из map_screen.dart виджет поисковой панели поверх карты.
//
// Цель декомпозиции (Item 6): вынести логику поиска в отдельный Stateless-виджет,
// обернув в RepaintBoundary, чтобы ввод текста не триггерил перерисовку
// всей карты (5370 строк) на каждое нажатие клавиши.
//
// Item 6 (CityPulse_Improvements.md): UX/UI и Перформанс.
import 'package:flutter/material.dart';

import '../../../theme/pulse_colors.dart';

/// Компактная поисковая панель над картой с кнопками «голос» и «фильтр».
class SearchOverlay extends StatelessWidget {
  const SearchOverlay({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onVoiceTap,
    required this.onFilterTap,
    this.hintText = 'Поиск по адресу, категории…',
    this.hasActiveFilters = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onVoiceTap;
  final VoidCallback onFilterTap;
  final String hintText;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        decoration: BoxDecoration(
          color: PulseColors.backgroundRaised.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PulseColors.primary.withOpacity(0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded,
                color: PulseColors.textSecondary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TextStyle(color: PulseColors.textPrimary),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle:
                      TextStyle(color: PulseColors.textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            // Кнопка голосового ввода
            _IconAction(
              icon: Icons.mic_rounded,
              onTap: onVoiceTap,
              color: PulseColors.primary,
            ),
            // Кнопка фильтров с индикатором активных
            _IconAction(
              icon: Icons.tune_rounded,
              onTap: onFilterTap,
              color: hasActiveFilters
                  ? PulseColors.primary
                  : PulseColors.textSecondary,
              showDot: hasActiveFilters,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.color,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 22),
          onPressed: onTap,
          splashRadius: 22,
        ),
        if (showDot)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: PulseColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: PulseColors.backgroundRaised,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
