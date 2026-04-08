/// Hero banner and executive overview strip widgets.
///
/// Extracted from `_hero()` and `_overviewStrip()` in `infographic_screen.dart`.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return GlassPanel(
      accent: const Color(0xFF00E5FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF4D8DFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_graph_rounded,
                    color: Colors.black, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city,
                      style: GoogleFonts.orbitron(
                        color: PulseColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$region • $updatedAt',
                      style: GoogleFonts.inter(
                        color: PulseColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _tag('$chartCount charts'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '\u0418\u043D\u0444\u043E\u0433\u0440\u0430\u0444\u0438\u043A\u0430 \u0442\u0435\u043F\u0435\u0440\u044C \u0447\u0438\u0442\u0430\u0435\u0442\u0441\u044F \u043A\u0430\u043A \u0432\u0438\u0437\u0443\u0430\u043B\u044C\u043D\u044B\u0439 \u043E\u0442\u0447\u0435\u0442: \u043E\u0431\u044A\u0435\u043C\u043D\u044B\u0435 \u043A\u0430\u0440\u0442\u043E\u0447\u043A\u0438, \u0441\u0442\u0435\u043A\u043B\u043E, \u0440\u0430\u0441\u043A\u0440\u044B\u0432\u0430\u044E\u0449\u0438\u0435\u0441\u044F \u0433\u0440\u0430\u0444\u0438\u043A\u0438.',
            style: GoogleFonts.inter(
              color: PulseColors.textPrimary.withOpacity(0.78),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill(
                  Icons.groups_rounded,
                  '\u041D\u0430\u0441\u0435\u043B\u0435\u043D\u0438\u0435',
                  population,
                  const Color(0xFF7C4DFF)),
              _pill(Icons.dataset_rounded, 'Datasets', datasets,
                  const Color(0xFFF8D24A)),
              _pill(Icons.grid_view_rounded, '\u0411\u043B\u043E\u043A\u0438',
                  blocks, const Color(0xFF21F3C3)),
              _pill(
                  Icons.square_foot_rounded,
                  '\u041F\u043B\u043E\u0449\u0430\u0434\u044C',
                  area,
                  const Color(0xFF38BDF8)),
            ],
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
          Text(
            'EXECUTIVE OVERVIEW',
            style:
                AppTextStyles.overline.copyWith(color: PulseColors.accentGold),
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

// ---------------------------------------------------------------------------
// Inline helpers (small, self-contained)
// ---------------------------------------------------------------------------

Widget _tag(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: PulseColors.textPrimary.withOpacity(0.06),
        border: Border.all(color: PulseColors.textPrimary.withOpacity(0.08)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              color: PulseColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );

Widget _pill(IconData icon, String label, String value, Color accent) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: PulseColors.textPrimary.withOpacity(0.05),
        border: Border.all(color: PulseColors.textPrimary.withOpacity(0.08)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: accent, size: 14),
        const SizedBox(width: 8),
        Text('$label • $value',
            style: GoogleFonts.inter(
                color: PulseColors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      ]),
    );

Widget _snapshotCard({
  required String label,
  required String value,
  required String detail,
  required Color accent,
}) =>
    Container(
      constraints: const BoxConstraints(minWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withOpacity(0.1),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: PulseColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.orbitron(
              color: PulseColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
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
