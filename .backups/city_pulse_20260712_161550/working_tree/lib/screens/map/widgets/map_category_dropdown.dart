// lib/screens/map/widgets/map_category_dropdown.dart
import 'package:flutter/material.dart';
import '../../../theme/pulse_categories.dart';
import 'map_glass_panel.dart';

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

  @override
  Widget build(BuildContext context) {
    final options = PulseCategories.mapFilterOptions;

    return MapGlassPanel(
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      fillColor: uiPanelFill,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedCategory,
          dropdownColor: isNightMode ? const Color(0xFF0F172A) : Colors.white,
          icon: Icon(Icons.arrow_drop_down_rounded, color: uiTextSecondary),
          isExpanded: true,
          hint: Text(
            'Все категории ($totalComplaints)',
            style: TextStyle(color: uiTextPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          onChanged: onCategoryChanged,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.all_inclusive_rounded, size: 16, color: uiAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Все категории ($totalComplaints)',
                    style: TextStyle(color: uiTextPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            ...options.map((opt) {
              final label = opt.$1;
              final icon = opt.$2;
              final color = opt.$3;
              final count = categoryCounts[label] ?? 0;
              return DropdownMenuItem<String?>(
                value: label,
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$label ($count)',
                        style: TextStyle(color: uiTextPrimary, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
