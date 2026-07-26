import 'package:flutter/material.dart';

import '../../../theme/pulse_categories.dart';
import '../../../theme/pulse_colors.dart';
import 'map_glass_panel.dart';

/// Floating, collapsible legend that shows the active category color pictograms
/// on the map. Tapping the header toggles the expanded list so it never gets in
/// the way of the map; in zen mode the host can simply hide it.
class MapCategoryLegend extends StatefulWidget {
  final bool isNightMode;
  final bool visible;

  const MapCategoryLegend({
    super.key,
    required this.isNightMode,
    this.visible = true,
  });

  @override
  State<MapCategoryLegend> createState() => _MapCategoryLegendState();
}

class _MapCategoryLegendState extends State<MapCategoryLegend> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final options = PulseCategories.mapFilterOptions;

    return Semantics(
      label: _expanded ? 'Легенда категорий развёрнута' : 'Легенда категорий',
      button: true,
      child: MapGlassPanel(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        fillColor: PulseColors.surfaceGlass,
        blurSigma: 22,
        borderColors: [
          PulseColors.primary.withAlpha(widget.isNightMode ? 90 : 40),
          Colors.transparent,
        ],
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _buildExpanded(options)
              : _buildCollapsed(options.length),
        ),
      ),
    );
  }

  Widget _buildCollapsed(int count) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.palette_outlined,
              size: 16, color: PulseColors.primary),
          const SizedBox(width: 6),
          Text(
            'Легенда',
            style: TextStyle(
              color: PulseColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              color: PulseColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 16, color: PulseColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildExpanded(List<(String, IconData, Color)> options) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = false),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.palette_outlined,
                  size: 16, color: PulseColors.primary),
              const SizedBox(width: 6),
              Text(
                'Категории',
                style: TextStyle(
                  color: PulseColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(Icons.expand_more_rounded,
                  size: 18, color: PulseColors.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final opt in options)
              _LegendChip(
                name: opt.$1,
                icon: opt.$2,
                color: opt.$3,
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;

  const _LegendChip({
    required this.name,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withAlpha(120), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          name,
          style: TextStyle(
            color: PulseColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
