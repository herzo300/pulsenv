/// Minimal chart card — clean line/bar charts without extra chrome.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

class _ChartCardState extends State<ChartCard> {
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    if (widget.series.isNotEmpty && widget.series.first.points.isNotEmpty) {
      _selected = widget.series.first.points.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textPrimary = scheme.onSurface;
    final textMuted = scheme.onSurface.withOpacity(0.62);
    final panel = scheme.surface.withOpacity(
      Theme.of(context).brightness == Brightness.dark ? 0.72 : 0.96,
    );

    final primary = widget.series.first;
    final selected = primary.points.isEmpty
        ? null
        : primary.points[_selected.clamp(0, primary.points.length - 1)];
    final latest = primary.points.isEmpty ? null : primary.points.last;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.manrope(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (latest != null)
                Text(
                  '${_value(latest.value)}${widget.unit}',
                  style: GoogleFonts.manrope(
                    color: widget.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 168,
            child: widget.kind == ChartKind.bar
                ? BarChart(_barData(textMuted))
                : LineChart(_lineData(widget.kind == ChartKind.line, textMuted)),
          ),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Text(
              '${selected.label} · ${_value(selected.value)}${widget.unit}',
              style: GoogleFonts.manrope(
                color: textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  LineChartData _lineData(bool fill, Color textMuted) {
    final count = widget.series
        .fold<int>(0, (max, item) => math.max(max, item.points.length));
    final maxY = widget.series
        .expand((item) => item.points)
        .fold<double>(0, (max, point) => math.max(max, point.value));
    return LineChartData(
      minX: 0,
      maxX: math.max(0, count - 1).toDouble(),
      minY: 0,
      maxY: maxY == 0 ? 1 : maxY * 1.16,
      borderData: FlBorderData(show: false),
      gridData: _grid(textMuted),
      titlesData: _titles(widget.series.first.points, textMuted),
      lineTouchData: LineTouchData(
        touchCallback: (event, response) {
          final spot = response?.lineBarSpots?.isNotEmpty == true
              ? response!.lineBarSpots!.first
              : null;
          if (spot != null) setState(() => _selected = spot.spotIndex);
        },
        touchTooltipData: LineTouchTooltipData(
          tooltipBorderRadius: BorderRadius.circular(10),
          getTooltipColor: (_) => const Color(0xE6081524),
          getTooltipItems: (spots) => spots
              .map(
                (spot) => LineTooltipItem(
                  '${_value(spot.y)}${widget.unit}',
                  GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      lineBarsData: widget.series
          .map(
            (series) => LineChartBarData(
              spots: [
                for (int i = 0; i < series.points.length; i++)
                  FlSpot(i.toDouble(), series.points[i].value),
              ],
              isCurved: true,
              curveSmoothness: 0.32,
              barWidth: 2.8,
              isStrokeCapRound: true,
              color: series.color,
              belowBarData: BarAreaData(
                show: fill && identical(series, widget.series.first),
                gradient: LinearGradient(
                  colors: [
                    series.color.withOpacity(0.22),
                    series.color.withOpacity(0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: index == _selected ? 4 : 2.5,
                  color: index == _selected ? Colors.white : series.color,
                  strokeWidth: index == _selected ? 2.2 : 0,
                  strokeColor: series.color,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  BarChartData _barData(Color textMuted) {
    final points = widget.series.first.points;
    final maxY =
        points.fold<double>(0, (max, point) => math.max(max, point.value));
    final padded = maxY == 0 ? 1.0 : maxY * 1.18;
    return BarChartData(
      minY: 0,
      maxY: padded,
      borderData: FlBorderData(show: false),
      gridData: _grid(textMuted),
      titlesData: _titles(points, textMuted),
      barTouchData: BarTouchData(
        touchCallback: (event, response) {
          final spot = response?.spot;
          if (spot != null) {
            setState(() => _selected = spot.touchedBarGroupIndex);
          }
        },
        touchTooltipData: BarTouchTooltipData(
          tooltipBorderRadius: BorderRadius.circular(10),
          getTooltipColor: (_) => const Color(0xE6081524),
          getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
            '${_value(rod.toY)}${widget.unit}',
            GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      barGroups: [
        for (int i = 0; i < points.length; i++)
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: points[i].value,
                width: 14,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                gradient: LinearGradient(
                  colors: [
                    i == _selected ? Colors.white : widget.accent,
                    widget.accent.withOpacity(0.35),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ],
          ),
      ],
    );
  }

  FlGridData _grid(Color textMuted) => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: textMuted.withOpacity(value == 0 ? 0.28 : 0.12),
          strokeWidth: 0.8,
        ),
      );

  FlTitlesData _titles(List<ChartPoint> points, Color textMuted) {
    final interval = points.length <= 4
        ? 1.0
        : math.max(1, (points.length / 4).floor()).toDouble();
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 34,
          getTitlesWidget: (value, meta) => Text(
            value == value.roundToDouble()
                ? value.toInt().toString()
                : value.toStringAsFixed(1),
            style: GoogleFonts.manrope(
              color: textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: interval,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= points.length) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              space: 6,
              child: Text(
                points[index].label,
                style: GoogleFonts.manrope(
                  color: textMuted.withOpacity(index == _selected ? 1 : 0.55),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _value(double value) {
    if (value.abs() >= 1000) return value.round().toString();
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }
}
