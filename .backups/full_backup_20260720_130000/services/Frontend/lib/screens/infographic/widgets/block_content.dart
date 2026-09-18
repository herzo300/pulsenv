/// Block content rendering — block headers, item cards, news strips,
/// fact chips, and snapshot extraction.
///
/// Extracted from `_block()`, `_itemCard()`, `_newsStrip()`, `_factChips()`,
/// and snapshot helpers in `infographic_screen.dart`.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/pulse_colors.dart';
import '../../../widgets/app_ui.dart';
import 'glass_panel.dart';
import 'chart_card.dart';

// ---------------------------------------------------------------------------
/// Data types used across block content
// ---------------------------------------------------------------------------

class BlockSnapshot {
  const BlockSnapshot({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;
}

class BlockContentItem {
  const BlockContentItem({
    required this.type,
    required this.title,
    this.val,
    this.sub,
    this.data = const [],
    this.values = const [],
    this.img,
    this.url,
  });

  final String type;
  final String title;
  final String? val;
  final String? sub;
  final List<Map<String, dynamic>> data;
  final List<Map<String, dynamic>> values;
  final String? img;
  final String? url;
}

class BlockData {
  const BlockData({
    required this.id,
    required this.title,
    required this.icon,
    required this.trend,
    required this.analysis,
    required this.items,
  });

  final String id;
  final String title;
  final String icon;
  final String trend;
  final String analysis;
  final List<BlockContentItem> items;
}

// ---------------------------------------------------------------------------
/// Renders a complete infographic block (header + analysis + items).
// ---------------------------------------------------------------------------
class InfographicBlock extends StatelessWidget {
  const InfographicBlock({
    super.key,
    required this.block,
    required this.accent,
    required this.seriesBuilder,
    required this.chartDelta,
    required this.chartNarrative,
    required this.itemNarrative,
    required this.blockNarrative,
    required this.blockSignal,
    required this.trendLabel,
    required this.unit,
  });

  final BlockData block;
  final Color accent;
  final List<ChartSeries> Function(BlockContentItem item, Color accent)
      seriesBuilder;
  final double? Function(BlockContentItem item) chartDelta;
  final String Function(BlockContentItem item) chartNarrative;
  final String Function(BlockContentItem item) itemNarrative;
  final String Function(BlockData block, List<BlockContentItem> items)
      blockNarrative;
  final String Function(BlockData block, List<BlockContentItem> items)
      blockSignal;
  final String Function(String trend) trendLabel;
  final String Function(String title) unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content =
        block.items.where((item) => item.type != 'news_card').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            block.title,
            style: GoogleFonts.manrope(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...content.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _itemCard(
                  item,
                  accent,
                  seriesBuilder,
                  chartDelta,
                  chartNarrative,
                  unit,
                ),
              )),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
/// Item card — charts or stat/grid/list/progress cards.
// ---------------------------------------------------------------------------
Widget _itemCard(
  BlockContentItem item,
  Color accent,
  List<ChartSeries> Function(BlockContentItem item, Color accent) seriesBuilder,
  double? Function(BlockContentItem item) chartDelta,
  String Function(BlockContentItem item) chartNarrative,
  String Function(String title) unit,
) {
  final type = item.type;
  if (_isChart(type)) {
    final kind = type == 'bar_chart'
        ? ChartKind.bar
        : (type == 'dual_chart' ? ChartKind.dual : ChartKind.line);
    return ChartCard(
      title: item.title,
      accent: accent,
      unit: unit(item.title),
      hint: chartNarrative(item),
      kind: kind,
      series: seriesBuilder(item, accent),
    );
  }

  return GlassPanel(
    accent: accent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: GoogleFonts.manrope(
            color: PulseColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _factChips(item, accent),
        ),
      ],
    ),
  );
}

bool _isChart(String type) =>
    type == 'line_chart' || type == 'bar_chart' || type == 'dual_chart';

String _itemNarrativeFallback(BlockContentItem item) {
  final type = item.type;
  if (type == 'stat') {
    return 'Доминирующий показатель блока, который задаёт главный headline без необходимости читать длинный текст.';
  }
  if (type == 'progress_list') {
    final values = item.values;
    final avg = values.isEmpty
        ? 0.0
        : values.fold<double>(
                0, (sum, value) => sum + _parseNum(value['percent'])) /
            values.length;
    return 'Средний уровень покрытия по списку составляет ${avg.toStringAsFixed(0)}%, поэтому здесь удобно читать зрелость инфраструктуры.';
  }
  final values = item.values;
  if (values.isNotEmpty) {
    final lead = values.first;
    return 'Первая позиция в списке задаёт тон всему набору: ${_s(lead['label'])} со значением ${_s(lead['val'], fallback: '${_parseNum(lead['percent']).toStringAsFixed(0)}%')}.';
  }
  return 'Дополнительный аналитический блок с локальными фактами и опорными значениями.';
}

// ---------------------------------------------------------------------------
/// News strip — horizontal scrollable news cards.
// ---------------------------------------------------------------------------
class NewsStrip extends StatelessWidget {
  const NewsStrip({super.key, required this.items, required this.accent});

  final List<BlockContentItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 280,
              child: GlassPanel(
                accent: accent,
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: (item.img == null || item.img == '-')
                            ? Container(color: const Color(0xFF0B1528))
                            : Image.network(
                                item.img!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: const Color(0xFF0B1528)),
                              ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.06),
                                Colors.black.withOpacity(0.38),
                                const Color(0xFF040913).withOpacity(0.92),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _tag('CITY FEED'),
                            const Spacer(),
                            Text(
                              item.title,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: PulseColors.textPrimary,
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.url ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color:
                                    PulseColors.textSecondary.withOpacity(0.72),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Snapshot extraction
// ---------------------------------------------------------------------------

List<BlockSnapshot> _extractBlockSnapshots(
  BlockData block,
  List<ChartSeries> Function(BlockContentItem item, Color accent) seriesBuilder,
  String Function(String title) unit,
) {
  final accent = _accent(block.id, block.trend);
  final snapshots = <BlockSnapshot>[];

  for (final item in block.items) {
    final type = item.type;
    if (_isChart(type)) {
      final series = seriesBuilder(item, accent);
      if (series.isNotEmpty && series.first.points.isNotEmpty) {
        final latest = series.first.points.last.value;
        snapshots.add(
          BlockSnapshot(
            label: item.title,
            value:
                '${latest % 1 == 0 ? latest.toInt() : latest.toStringAsFixed(1)}${unit(item.title)}',
            detail: 'последнее значение ряда',
          ),
        );
      }
    } else if (type == 'stat') {
      snapshots.add(
        BlockSnapshot(
          label: item.title,
          value: item.val ?? '-',
          detail: item.sub ?? '',
        ),
      );
    } else {
      final values = item.values;
      if (values.isNotEmpty) {
        final lead = values.first;
        snapshots.add(
          BlockSnapshot(
            label: item.title,
            value: _s(
              lead['val'],
              fallback: '${_parseNum(lead['percent']).toStringAsFixed(0)}%',
            ),
            detail: _s(lead['label']),
          ),
        );
      }
    }
    if (snapshots.length >= 3) break;
  }

  if (snapshots.isEmpty) {
    snapshots.add(
      const BlockSnapshot(
        label: 'Содержимое блока',
        value: '0',
        detail: 'нет выделенных метрик',
      ),
    );
  }
  return snapshots.take(3).toList();
}

// ---------------------------------------------------------------------------
// Fact chips
// ---------------------------------------------------------------------------

List<Widget> _factChips(BlockContentItem item, Color accent) {
  final type = item.type;
  if (type == 'stat') {
    return [_factChip(item.title, item.val ?? '-', accent, item.sub ?? '')];
  }
  if (type == 'grid' || type == 'list') {
    return item.values.asMap().entries.map((entry) {
      final value = entry.value;
      final label = _s(value['label']).trim().isEmpty
          ? '\u041F\u043E\u0437\u0438\u0446\u0438\u044F ${entry.key + 1}'
          : _s(value['label']);
      return _factChip(label, _s(value['val']), accent, '');
    }).toList();
  }
  if (type == 'progress_list') {
    return item.values.map((value) {
      return _factChip(_s(value['label']),
          '${_parseNum(value['percent']).toStringAsFixed(0)}%', accent, '');
    }).toList();
  }
  return [_factChip(item.title, '-', accent, '')];
}

// ---------------------------------------------------------------------------
// Inline helpers
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

Widget _factChip(String label, String value, Color accent, String subtitle) =>
    Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withOpacity(0.1),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(
                color: PulseColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.orbitron(
                color: PulseColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: PulseColors.textSecondary, fontSize: 10.5)),
        ],
      ]),
    );

IconData _icon(String icon) {
  switch (icon) {
    case 'trending_up':
      return Icons.trending_up_rounded;
    case 'groups':
      return Icons.groups_rounded;
    case 'directions_bus':
      return Icons.directions_bus_rounded;
    case 'business':
      return Icons.business_rounded;
    case 'apartment':
      return Icons.apartment_rounded;
    case 'newspaper':
      return Icons.newspaper_rounded;
    case 'leaf':
      return Icons.eco_rounded;
    case 'local_gas_station':
      return Icons.local_gas_station_rounded;
    case 'air':
      return Icons.air_rounded;
    case 'recycling':
      return Icons.recycling_rounded;
    case 'hail':
      return Icons.hail_rounded;
    case 'local_activity':
      return Icons.local_activity_rounded;
    case 'directions_run':
      return Icons.directions_run_rounded;
    case 'palette':
      return Icons.palette_rounded;
    case 'accessible':
      return Icons.accessible_rounded;
    case 'emoji_events':
      return Icons.emoji_events_rounded;
    case 'rocket_launch':
      return Icons.rocket_launch_rounded;
    case 'auto_stories':
      return Icons.auto_stories_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'local_hospital':
      return Icons.local_hospital_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'wifi':
      return Icons.wifi_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'business_center':
      return Icons.business_center_rounded;
    case 'shield':
      return Icons.shield_rounded;
    case 'oil_barrel':
      return Icons.oil_barrel_rounded;
    case 'cloud':
      return Icons.cloud_rounded;
    case 'water':
      return Icons.water_rounded;
    default:
      return Icons.insights_rounded;
  }
}

Color _accent(String id, String trend) {
  switch (id) {
    case 'economy':
      return const Color(0xFFF8D24A);
    case 'demographics':
      return const Color(0xFF7C4DFF);
    case 'transport':
      return const Color(0xFF00E5FF);
    case 'construction':
      return const Color(0xFF21F3C3);
    case 'social':
      return const Color(0xFF4D8DFF);
    case 'active_life':
      return const Color(0xFFFFB300);
    case 'accessibility':
      return const Color(0xFFE040FB);
    case 'news':
      return const Color(0xFFFF7C5C);
    case 'eco':
      return const Color(0xFF80ED99);
    case 'healthcare':
      return const Color(0xFFEF5350);
    case 'education':
      return const Color(0xFF42A5F5);
    case 'digital':
      return const Color(0xFF26C6DA);
    case 'real_estate':
      return const Color(0xFFAB47BC);
    case 'business':
      return const Color(0xFFFFA726);
    case 'safety':
      return const Color(0xFF66BB6A);
    case 'oil_production':
      return const Color(0xFFD4E157);
    case 'weather_eco':
      return const Color(0xFF29B6F6);
    case 'river':
      return const Color(0xFF26A69A);
    default:
      return trend == 'stable'
          ? const Color(0xFF8B9BB5)
          : const Color(0xFF4D8DFF);
  }
}

// ---------------------------------------------------------------------------
// Shared data helpers
// ---------------------------------------------------------------------------

String _s(dynamic value, {String fallback = '-'}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

double _parseNum(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  return 0;
}

Widget _newsStrip(List<BlockContentItem> items, Color accent) =>
    NewsStrip(items: items, accent: accent);
