import 'package:flutter/material.dart';

import '../../../theme/pulse_colors.dart';
import 'map_glass_panel.dart';

/// Category dropdown widget for filtering map markers by category.
class MapCategoryDropdown extends StatelessWidget {
  final String? selectedCategory;
  final int totalComplaints;
  final Map<String, int> categoryCounts;
  final Color uiTextPrimary;
  final Color uiTextSecondary;
  final Color uiPanelFill;
  final Color uiGlow;
  final Color uiAccent;
  final bool isNightMode;
  final ValueChanged<String?> onCategoryChanged;

  const MapCategoryDropdown({
    super.key,
    required this.selectedCategory,
    required this.totalComplaints,
    required this.categoryCounts,
    required this.uiTextPrimary,
    required this.uiTextSecondary,
    required this.uiPanelFill,
    required this.uiGlow,
    required this.uiAccent,
    required this.isNightMode,
    required this.onCategoryChanged,
  });

  static const List<(String, IconData, Color)> categories = [
    ('Дороги', Icons.directions_car, PulseColors.negative),
    ('ЖКХ', Icons.home, PulseColors.primary),
    ('Освещение', Icons.lightbulb, Color(0xFFf59e0b)),
    ('Транспорт', Icons.directions_bus, Color(0xFF3b82f6)),
    ('Экология', Icons.eco, PulseColors.success),
    ('Безопасность', Icons.shield, Color(0xFF6366f1)),
    ('Снег/Наледь', Icons.ac_unit, Color(0xFF38bdf8)),
    ('Медицина', Icons.local_hospital, Color(0xFFef4444)),
    ('Образование', Icons.school, Color(0xFF818cf8)),
    ('Парковки', Icons.local_parking, Color(0xFF9ca3af)),
    ('Строительство', Icons.architecture_rounded, Color(0xFFF59E0B)),
    ('Мероприятие', Icons.event_available_rounded, Color(0xFFEAB308)),
    ('Прочее', Icons.report_problem, PulseColors.neutral),
  ];

  @override
  Widget build(BuildContext context) {
    final borderColor = selectedCategory != null
        ? uiAccent.withAlpha(isNightMode ? 180 : 130)
        : uiGlow.withAlpha(isNightMode ? 120 : 80);

    return MapGlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: EdgeInsets.zero,
      fillColor: uiPanelFill,
      blurSigma: 24,
      borderColors: [
        borderColor,
        borderColor.withAlpha(60),
        Colors.transparent,
      ],
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(60),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ],
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedCategory,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: selectedCategory != null ? uiAccent : uiTextSecondary,
                size: 22,
              ),
              dropdownColor:
                  isNightMode ? PulseColors.surface : const Color(0xFFF7FCFF),
              borderRadius: BorderRadius.circular(12),
              hint: Row(
                children: [
                  Icon(Icons.filter_list_rounded,
                      color: uiTextSecondary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Все категории',
                    style: TextStyle(
                      color: uiTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.clear_all_rounded,
                          color: uiTextSecondary, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Все категории',
                        style: TextStyle(
                          color: uiTextPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$totalComplaints',
                        style: TextStyle(
                          color: uiTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ...categories.map((cat) {
                  final (name, icon, color) = cat;
                  final count = categoryCounts[name] ?? 0;
                  return DropdownMenuItem<String?>(
                    value: name,
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: color.withAlpha(40),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(icon, color: color, size: 15),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: uiTextPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: onCategoryChanged,
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter panel with time range chips (Все, Новые, 1д, 7д, 30д).
class MapFilterPanel extends StatelessWidget {
  final int? selectedDaysFilter;
  final Color uiTextPrimary;
  final Color uiPanelFill;
  final Color uiGlow;
  final Color uiAccent;
  final bool isNightMode;
  final ValueChanged<int?> onDaysFilterChanged;

  const MapFilterPanel({
    super.key,
    required this.selectedDaysFilter,
    required this.uiTextPrimary,
    required this.uiPanelFill,
    required this.uiGlow,
    required this.uiAccent,
    required this.isNightMode,
    required this.onDaysFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = <Map<String, Object?>>[
      {'days': null, 'label': '\u0412\u0441\u0435'},
      {'days': -1, 'label': '\u041d\u043e\u0432\u044b\u0435'},
      {'days': 1, 'label': '1 \u0434'},
      {'days': 7, 'label': '7 \u0434'},
      {'days': 30, 'label': '30 \u0434'},
    ];

    return MapGlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      fillColor: uiPanelFill,
      blurSigma: 24,
      borderColors: [
        uiGlow.withAlpha(isNightMode ? 120 : 48),
        uiGlow.withAlpha(isNightMode ? 55 : 12),
        Colors.transparent,
      ],
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in filters)
            _buildDaysChip(
              days: f['days'] as int?,
              label: f['label'] as String,
            ),
        ],
      ),
    );
  }

  Widget _buildDaysChip({required int? days, required String label}) {
    final selected = selectedDaysFilter == days;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? (isNightMode ? Colors.black : Colors.white)
              : uiTextPrimary,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: uiAccent,
      backgroundColor: isNightMode
          ? PulseColors.surface.withAlpha(185)
          : Colors.white.withAlpha(175),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected
              ? uiAccent
              : (isNightMode
                  ? Colors.white.withAlpha(60)
                  : const Color(0xFF7DD3FC).withAlpha(120)),
          width: 1.0,
        ),
      ),
      onSelected: (_) => onDaysFilterChanged(days),
    );
  }
}
