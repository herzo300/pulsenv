/// Chart card widget with line, bar, and dual-chart support.
///
/// Extracted from the original `_ChartCard` in `infographic_screen.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/pulse_colors.dart';
import '../../../widgets/app_ui.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class ChartPoint {
  const ChartPoint(this.label, this.value);
  final String label;
  final double value;
}

class ChartSeries {
  const ChartSeries(this.label, this.color, this.points);
  final String label;
  final Color color;
  final List<ChartPoint> points;
}

enum ChartKind { line, bar, dual }

// ---------------------------------------------------------------------------
/// Glass-morphic chart card with interactive chart, metrics, and expandable
/// detail panel.
// ---------------------------------------------------------------------------
class ChartCard extends StatefulWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.accent,
    required this.kind,
    required this.hint,
    required this.series,
    required this.unit,
  });

  final String title;
  final Color accent;
  final ChartKind kind;
  final String hint;
  final List<ChartSeries> series;
  final String unit;

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;
  late final List<_BurstSeed> _seeds;
  bool _expanded = false;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    final random = math.Random(widget.title.hashCode);
    _seeds = List.generate(28, (_) => _BurstSeed.random(random));
    if (widget.series.isNotEmpty && widget.series.first.points.isNotEmpty) {
      _selected = widget.series.first.points.length - 1;
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _expand() {
    if (widget.series.isEmpty || widget.series.first.points.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    _burst.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.series.first;
    final selected = primary.points.isEmpty
        ? null
        : primary.points[_selected.clamp(0, primary.points.length - 1)];
    final maxY = primary.points.isEmpty
        ? 0.0
        : primary.points.map((p) => p.value).reduce(math.max);
    final delta = primary.points.length >= 2
        ? primary.points.last.value - primary.points.first.value
        : 0.0;

    return AppPanel(
      borderColor: widget.accent.withOpacity(0.14),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) => CustomPaint(
                  painter:
                      _ParticlePainter(widget.accent, _burst.value, _seeds),
                ),
              ),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.title,
                        style: GoogleFonts.inter(
                            color: PulseColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(widget.hint,
                        style: GoogleFonts.inter(
                            color: PulseColors.textSecondary.withOpacity(0.72),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500)),
                  ])),
              GestureDetector(
                onTap: _expand,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PulseColors.textPrimary.withOpacity(0.05),
                      border: Border.all(
                          color: PulseColors.textPrimary.withOpacity(0.08))),
                  child: Icon(
                      _expanded
                          ? Icons.remove_rounded
                          : Icons.auto_awesome_rounded,
                      color: widget.accent,
                      size: 18),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            SizedBox(
                height: _expanded ? 220 : 184,
                child: widget.kind == ChartKind.bar
                    ? BarChart(_barData())
                    : LineChart(_lineData(widget.kind == ChartKind.line))),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _metric(
                  selected == null
                      ? '-'
                      : '${selected.label} • ${_value(selected.value)}${widget.unit}',
                  '\u0412\u044B\u0431\u0440\u0430\u043D\u043E',
                  widget.accent),
              _metric(
                  '${delta >= 0 ? '+' : ''}${_value(delta)}${widget.unit}',
                  '\u0414\u0435\u043B\u044C\u0442\u0430',
                  delta >= 0 ? PulseColors.success : const Color(0xFFFF7C5C)),
              _metric('${_value(maxY)}${widget.unit}', 'Peak',
                  PulseColors.accentGold),
            ]),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 360),
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: PulseColors.textPrimary.withOpacity(0.04),
                      border: Border.all(
                          color: PulseColors.textPrimary.withOpacity(0.06))),
                  child: Wrap(spacing: 10, runSpacing: 10, children: [
                    _detail('\u0422\u043E\u0447\u0435\u043A',
                        primary.points.length.toString()),
                    _detail(
                        widget.kind == ChartKind.dual
                            ? '\u0421\u0435\u0440\u0438\u0439'
                            : '\u0424\u043E\u0440\u043C\u0430\u0442',
                        widget.kind == ChartKind.dual
                            ? widget.series.length.toString()
                            : widget.kind.name),
                    _detail('Min',
                        '${_value(primary.points.isEmpty ? 0 : primary.points.map((p) => p.value).reduce(math.min))}${widget.unit}'),
                    _detail('\u0421\u0440\u0435\u0434\u043D\u0435\u0435',
                        '${_value(primary.points.isEmpty ? 0 : primary.points.fold<double>(0, (sum, p) => sum + p.value) / primary.points.length)}${widget.unit}'),
                  ]),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  LineChartData _lineData(bool fill) {
    final count = widget.series
        .fold<int>(0, (max, item) => math.max(max, item.points.length));
    final maxY = widget.series
        .expand((item) => item.points)
        .fold<double>(0, (max, point) => math.max(max, point.value));
    return LineChartData(
      minX: 0,
      maxX: math.max(0, count - 1).toDouble(),
      minY: 0,
      maxY: maxY == 0 ? 1 : maxY * 1.18,
      borderData: FlBorderData(show: false),
      gridData: _grid(),
      titlesData: _titles(widget.series.first.points),
      lineTouchData: LineTouchData(
        touchCallback: (event, response) {
          final spot = response?.lineBarSpots?.isNotEmpty == true
              ? response!.lineBarSpots!.first
              : null;
          if (spot != null) setState(() => _selected = spot.spotIndex);
          if (event is FlTapUpEvent) _expand();
        },
        touchTooltipData: LineTouchTooltipData(
          tooltipBorderRadius: BorderRadius.circular(14),
          tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          tooltipMargin: 10,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipColor: (_) => const Color(0xFF09111E).withOpacity(0.92),
          getTooltipItems: (spots) => spots
              .map((spot) => LineTooltipItem(
                  '${widget.series[spot.barIndex].label}\n${_value(spot.y)}${widget.unit}',
                  GoogleFonts.inter(
                      color: PulseColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700)))
              .toList(),
        ),
      ),
      lineBarsData: widget.series
          .map((series) => LineChartBarData(
                spots: [
                  for (int i = 0; i < series.points.length; i++)
                    FlSpot(i.toDouble(), series.points[i].value)
                ],
                isCurved: true,
                curveSmoothness: 0.28,
                barWidth: 3.2,
                isStrokeCapRound: true,
                color: series.color,
                gradient: LinearGradient(colors: [
                  series.color.withOpacity(0.72),
                  PulseColors.textPrimary.withOpacity(0.92)
                ]),
                belowBarData: BarAreaData(
                    show: fill && identical(series, widget.series.first),
                    gradient: LinearGradient(
                        colors: [
                          series.color.withOpacity(0.26),
                          series.color.withOpacity(0.02)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter)),
                dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                            radius: index == _selected ? 4.8 : 3.0,
                            color: index == _selected
                                ? PulseColors.textPrimary
                                : series.color,
                            strokeWidth: index == _selected ? 3 : 1.6,
                            strokeColor: series.color)),
              ))
          .toList(),
    );
  }

  BarChartData _barData() {
    final points = widget.series.first.points;
    final maxY =
        points.fold<double>(0, (max, point) => math.max(max, point.value));
    final padded = maxY == 0 ? 1.0 : maxY * 1.2;
    return BarChartData(
      minY: 0,
      maxY: padded,
      borderData: FlBorderData(show: false),
      gridData: _grid(),
      titlesData: _titles(points),
      barTouchData: BarTouchData(
        touchCallback: (event, response) {
          final spot = response?.spot;
          if (spot != null) {
            setState(() => _selected = spot.touchedBarGroupIndex);
          }
          if (event is FlTapUpEvent) {
            _expand();
          }
        },
        touchTooltipData: BarTouchTooltipData(
          tooltipBorderRadius: BorderRadius.circular(14),
          tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          tooltipMargin: 10,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipColor: (_) => const Color(0xFF09111E).withOpacity(0.92),
          getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              '${points[group.x].label}\n${_value(rod.toY)}${widget.unit}',
              GoogleFonts.inter(
                  color: PulseColors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ),
      ),
      barGroups: [
        for (int i = 0; i < points.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
                toY: points[i].value,
                width: 18,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                gradient: LinearGradient(
                    colors: i == _selected
                        ? [PulseColors.textPrimary, widget.accent]
                        : [
                            widget.accent.withOpacity(0.88),
                            widget.accent.withOpacity(0.35)
                          ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter),
                backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: padded,
                    color: PulseColors.textPrimary.withOpacity(0.04)))
          ])
      ],
    );
  }

  FlGridData _grid() => FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (value) => FlLine(
          color: widget.accent.withOpacity(value == 0 ? 0.22 : 0.09),
          strokeWidth: value == 0 ? 1.1 : 0.8,
          dashArray: const [4, 4]));

  FlTitlesData _titles(List<ChartPoint> points) {
    final interval = points.length <= 4
        ? 1.0
        : math.max(1, (points.length / 4).floor()).toDouble();
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
          sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                  value == value.roundToDouble()
                      ? value.toInt().toString()
                      : value.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                      color: PulseColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)))),
      bottomTitles: AxisTitles(
          sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                    meta: meta,
                    space: 10,
                    child: Text(points[index].label,
                        style: GoogleFonts.inter(
                            color: PulseColors.textPrimary
                                .withOpacity(index == _selected ? 0.92 : 0.42),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)));
              })),
    );
  }

  String _value(double value) {
    if (value.abs() >= 1000) return _compact(value.round());
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  String _compact(num value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final reverse = text.length - i;
      buffer.write(text[i]);
      if (reverse > 1 && reverse % 3 == 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  Widget _metric(String value, String label, Color accent) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: accent.withOpacity(0.1),
            border: Border.all(color: accent.withOpacity(0.22))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: PulseColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  color: PulseColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _detail(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: PulseColors.background.withOpacity(0.14)),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Particle burst animation
// ---------------------------------------------------------------------------

class _BurstSeed {
  const _BurstSeed(
      this.angle, this.distance, this.size, this.opacity, this.mix);
  final double angle;
  final double distance;
  final double size;
  final double opacity;
  final double mix;

  factory _BurstSeed.random(math.Random random) => _BurstSeed(
        random.nextDouble() * math.pi * 2,
        44 + random.nextDouble() * 140,
        2 + random.nextDouble() * 4,
        0.4 + random.nextDouble() * 0.5,
        random.nextDouble(),
      );
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter(this.accent, this.progress, this.seeds);

  final Color accent;
  final double progress;
  final List<_BurstSeed> seeds;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final fade = 1 - Curves.easeOutQuart.transform(progress);
    final radius = ui.lerpDouble(
        20, size.shortestSide * 0.44, Curves.easeOutCubic.transform(progress))!;
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = accent.withOpacity(0.32 * fade));
    for (final seed in seeds) {
      final distance = seed.distance * Curves.easeOut.transform(progress);
      final offset = Offset(center.dx + math.cos(seed.angle) * distance,
          center.dy + math.sin(seed.angle) * distance);
      final paint = Paint()
        ..color = Color.lerp(PulseColors.textPrimary, accent, seed.mix)!
            .withOpacity(fade * seed.opacity)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
      canvas.drawCircle(offset, seed.size * fade, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
