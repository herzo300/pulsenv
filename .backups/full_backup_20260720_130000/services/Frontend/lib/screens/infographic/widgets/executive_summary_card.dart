/// Hero banner and executive overview strip widgets.
///
/// Extracted from `_hero()` and `_overviewStrip()` in `infographic_screen.dart`.
library;

import 'package:flutter/material.dart';

import '../../../theme/pulse_colors.dart';
import '../../../widgets/app_ui.dart';
import 'glass_panel.dart';

// ---------------------------------------------------------------------------
/// Hero banner — city header with KPI pills.
// ---------------------------------------------------------------------------
class InfographicHero extends StatelessWidget {
  const InfographicHero({
    super.key,
    required this.city,
    required this.region,
    required this.updatedAt,
    required this.chartCount,
    required this.population,
    required this.datasets,
    required this.blocks,
    required this.area,
  });

  final String city;
  final String region;
  final String updatedAt;
  final int chartCount;
  final String population;
  final String datasets;
  final String blocks;
  final String area;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      accent: scheme.primary,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: AppTextStyles.section.copyWith(
                    fontSize: 20,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$region • $updatedAt',
                  style: AppTextStyles.bodyMuted.copyWith(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.62),
                  ),
                ),
              ],
            ),
          ),
          _pill(Icons.groups_rounded, population, scheme.primary),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Executive overview — summary cards with growth/stable/risk counts and
/// strongest-chart narrative.
// ---------------------------------------------------------------------------
class ExecutiveOverview extends StatelessWidget {
  const ExecutiveOverview({
    super.key,
    required this.growth,
    required this.stable,
    required this.risk,
    required this.narrative,
  });

  final int growth;
  final int stable;
  final int risk;
  final String narrative;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: PulseColors.accentViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF8D24A), Color(0xFF21F3C3)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ГОРОДСКОЙ ПУЛЬС',
                style: AppTextStyles.overline
                    .copyWith(color: PulseColors.accentGold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            narrative,
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _snapshotCard(
                label: 'Рост и восстановление',
                value: growth.toString(),
                detail: 'блоков с позитивной динамикой',
                accent: PulseColors.success,
              ),
              _snapshotCard(
                label: 'Стабильные зоны',
                value: stable.toString(),
                detail: 'блоков без заметных колебаний',
                accent: PulseColors.primary,
              ),
              _snapshotCard(
                label: 'Зоны внимания',
                value: risk.toString(),
                detail: 'блоков с просадкой или смешанным сигналом',
                accent: PulseColors.accentGold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _snapshotCard({
  required String label,
  required String value,
  required String detail,
  required Color accent,
}) =>
    Container(
      constraints: const BoxConstraints(minWidth: 176, maxWidth: 230),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: accent.withOpacity(0.1),
        border: Border.all(color: accent.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppTextStyles.overline.copyWith(
              fontSize: 10.5,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: AppTextStyles.metric.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
