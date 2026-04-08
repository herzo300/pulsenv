import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import 'infographic/widgets/index.dart';

class InfographicScreen extends StatefulWidget {
  const InfographicScreen({super.key});

  @override
  State<InfographicScreen> createState() => _InfographicScreenState();
}

class _InfographicScreenState extends State<InfographicScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _fetch();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<Map<String, dynamic>> _fetch() async {
    if (MapConfig.hasBackendConfig) {
      try {
        final response = await http
            .get(
              Uri.parse(
                '${MapConfig.backendApiBaseUrl}/infographic_data?data_type=eq.summary&select=data',
              ),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is List && decoded.isNotEmpty) {
            final row = decoded.first;
            if (row is Map<String, dynamic> &&
                row['data'] is Map<String, dynamic>) {
              return row['data'] as Map<String, dynamic>;
            }
          }
        }
      } catch (_) {
        // Fall through to local snapshot.
      }
    }

    final asset = await rootBundle.loadString('assets/infographic_data.json');
    return jsonDecode(asset) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _maps(_data?['blocks']);
    return Scaffold(
      backgroundColor: PulseColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: InfographicBackdrop()),
          const Positioned.fill(
              child: IgnorePointer(
                  child: AppScreenBackground(child: SizedBox.shrink()))),
          SafeArea(
            child: _loading && _data == null
                ? _loadingState()
                : _error != null && _data == null
                    ? _errorState()
                    : RefreshIndicator(
                        color: PulseColors.primary,
                        backgroundColor: PulseColors.surface,
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          children: [
                            _topBar(),
                            const SizedBox(height: 16),
                            if (_data != null) ...[
                              _hero(),
                              const SizedBox(height: 16),
                              _overviewStrip(blocks),
                              const SizedBox(height: 16),
                              ...blocks.expand((block) =>
                                  [_block(block), const SizedBox(height: 16)]),
                            ],
                            if (_error != null && _data != null)
                              _warningBanner(_error!),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Top bar
  // -----------------------------------------------------------------------

  Widget _topBar() {
    return GlassPanel(
      accent: const Color(0xFF00E5FF),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _circleButton(Icons.arrow_back_ios_new_rounded,
              () => Navigator.of(context).pop()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u041F\u0423\u041B\u042C\u0421 \u0414\u0410\u041D\u041D\u042B\u0425',
                  style: AppTextStyles.section.copyWith(
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\u041D\u0430\u0442\u0438\u0432\u043D\u044B\u0439 \u0432\u0438\u0437\u0443\u0430\u043B\u044C\u043D\u044B\u0439 \u043E\u0442\u0447\u0435\u0442',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _circleButton(Icons.refresh_rounded, _load),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Hero
  // -----------------------------------------------------------------------

  Widget _hero() {
    final data = _data!;
    final blocks = _maps(data['blocks']);
    final chartCount = blocks.fold<int>(0, (sum, block) {
      return sum +
          _maps(block['items'])
              .where((item) => _isChart(_s(item['type'])))
              .length;
    });
    return InfographicHero(
      city: _s(data['city']),
      region: _s(data['region']),
      updatedAt: _date(_s(data['updated_at'])),
      chartCount: chartCount,
      population: _fmt(_n(data['population_current'])),
      datasets: _s(data['total_datasets']),
      blocks: blocks.length.toString(),
      area: '${_n(data['area_km2']).toStringAsFixed(1)} km\u00B2',
    );
  }

  // -----------------------------------------------------------------------
  // Executive overview strip
  // -----------------------------------------------------------------------

  Widget _overviewStrip(List<Map<String, dynamic>> blocks) {
    final growth = blocks
        .where((block) => {
              'growth',
              'moderate_growth',
              'strong_growth',
              'recovery'
            }.contains(_s(block['trend'])))
        .length;
    final stable =
        blocks.where((block) => _s(block['trend']) == 'stable').length;
    final risk = blocks.length - growth - stable;

    Map<String, dynamic>? strongestChart;
    Map<String, dynamic>? strongestBlock;
    double strongestDelta = 0;

    for (final block in blocks) {
      for (final item in _maps(block['items'])) {
        if (!_isChart(_s(item['type']))) continue;
        final delta = _chartDelta(item);
        if (delta == null) continue;
        if (strongestChart == null || delta.abs() > strongestDelta.abs()) {
          strongestChart = item;
          strongestBlock = block;
          strongestDelta = delta;
        }
      }
    }

    final narrative = strongestBlock == null
        ? 'Сводка по всем блокам без выраженного численного лидера.'
        : 'Самый сильный численный сигнал сейчас даёт блок "${_s(strongestBlock['title'])}": ${strongestDelta >= 0 ? '+' : ''}${strongestDelta.toStringAsFixed(1)}% по графику "${_s(strongestChart?['title'])}".';

    return ExecutiveOverview(
      growth: growth,
      stable: stable,
      risk: risk,
      narrative: narrative,
    );
  }

  // -----------------------------------------------------------------------
  // Block
  // -----------------------------------------------------------------------

  Widget _block(Map<String, dynamic> block) {
    final accent = _accent(_s(block['id']), _s(block['trend']));
    final items = _maps(block['items']);

    final blockData = BlockData(
      id: _s(block['id']),
      title: _s(block['title']),
      icon: _s(block['icon']),
      trend: _s(block['trend']),
      analysis: _s(block['analysis']),
      items: items
          .map((item) => BlockContentItem(
                type: _s(item['type']),
                title: _s(item['title']),
                val: _s(item['val']),
                sub: _s(item['sub']),
                data: _maps(item['data']),
                values: _maps(item['values']),
                img: _s(item['img']),
                url: _s(item['url']),
              ))
          .toList(),
    );

    return InfographicBlock(
      block: blockData,
      accent: accent,
      seriesBuilder: _seriesForItem,
      chartDelta: _deltaForItem,
      chartNarrative: _narrativeForItem,
      itemNarrative: _itemNarrative,
      blockNarrative: (b, items) => _blockNarrativeFromData(b, items),
      blockSignal: (b, items) => _blockSignalFromData(b, items),
      trendLabel: _trend,
      unit: _unit,
    );
  }

  // -----------------------------------------------------------------------
  // Series / chart helpers (raw Map-based, used by overview strip)
  // -----------------------------------------------------------------------

  List<ChartSeries> _series(Map<String, dynamic> item, Color accent) {
    final type = _s(item['type']);
    final data = _maps(item['data']);
    if (type == 'dual_chart') {
      return [
        ChartSeries(
          _s(item['series_a_label'], fallback: 'A'),
          const Color(0xFF00E5FF),
          _points(data, ['birth', 'series_a', 'value']),
        ),
        ChartSeries(
          _s(item['series_b_label'], fallback: 'B'),
          const Color(0xFFF8D24A),
          _points(data, ['marriages', 'series_b', 'value_2']),
        ),
      ];
    }
    return [
      ChartSeries(_s(item['title']), accent,
          _points(data, ['value', 'salary', 'gid', 'count']))
    ];
  }

  List<ChartPoint> _points(List<Map<String, dynamic>> rows, List<String> keys) {
    return rows.asMap().entries.map((entry) {
      final row = entry.value;
      return ChartPoint(
          _s(row['year'], fallback: '${entry.key + 1}'), _pick(row, keys));
    }).toList();
  }

  double? _chartDelta(Map<String, dynamic> item) {
    final series = _series(item, const Color(0xFF00E5FF));
    if (series.isEmpty || series.first.points.length < 2) return null;
    final points = series.first.points;
    final first = points.first.value;
    final last = points.last.value;
    if (first == 0) return null;
    return ((last - first) / first) * 100;
  }

  String _chartNarrative(Map<String, dynamic> item) {
    final type = _s(item['type']);
    final series = _series(item, const Color(0xFF00E5FF));
    if (series.isEmpty || series.first.points.length < 2) {
      return 'График нужен для визуального чтения динамики этого среза.';
    }
    final main = series.first.points;
    final first = main.first.value;
    final last = main.last.value;
    final delta = first == 0 ? 0.0 : ((last - first) / first) * 100;
    final peak = main.reduce((a, b) => a.value >= b.value ? a : b);
    if (type == 'dual_chart' && series.length > 1) {
      final second = series[1].points;
      final secondPeak = second.reduce((a, b) => a.value >= b.value ? a : b);
      return 'Две серии показывают не только объём, но и расхождение контуров: пик первой линии в ${peak.label}, второй — в ${secondPeak.label}.';
    }
    return 'От ${main.first.label} к ${main.last.label} показатель ${delta >= 0 ? 'вырос' : 'снизился'} на ${delta.abs().toStringAsFixed(1)}%, а локальный пик пришёлся на ${peak.label}.';
  }

  // Typed adapters for InfographicBlock callbacks
  List<ChartSeries> _seriesForItem(BlockContentItem item, Color accent) =>
      _series(_toMap(item), accent);

  double? _deltaForItem(BlockContentItem item) => _chartDelta(_toMap(item));

  String _narrativeForItem(BlockContentItem item) =>
      _chartNarrative(_toMap(item));

  String _blockNarrativeFromData(
      BlockData block, List<BlockContentItem> items) {
    final trend = _trend(block.trend);
    final chartItem = items.cast<BlockContentItem?>().firstWhere(
        (item) => item != null && _isChart(item.type),
        orElse: () => null);
    if (chartItem != null) {
      return '$trend: ${_narrativeForItem(chartItem)}';
    }
    if (items.isEmpty) {
      return 'Блок читается как общий narrative-срез без выраженного численного центра.';
    }
    return '$trend: блок опирается на карточки фактов и статические контрольные показатели.';
  }

  String _blockSignalFromData(BlockData block, List<BlockContentItem> items) {
    final trend = block.trend;
    final chartCount = items.where((item) => _isChart(item.type)).length;
    if (trend == 'decline') return 'ATTENTION';
    if (chartCount >= 2) return 'ANALYTICS';
    if (trend == 'stable') return 'BASELINE';
    return 'LIVE BLOCK';
  }

  String _itemNarrative(BlockContentItem item) {
    final type = item.type;
    if (type == 'stat') {
      return 'Доминирующий показатель блока, который задаёт главный headline без необходимости читать длинный текст.';
    }
    if (type == 'progress_list') {
      final values = item.values;
      final avg = values.isEmpty
          ? 0.0
          : values.fold<double>(0, (sum, value) => sum + _n(value['percent'])) /
              values.length;
      return 'Средний уровень покрытия по списку составляет ${avg.toStringAsFixed(0)}%, поэтому здесь удобно читать зрелость инфраструктуры.';
    }
    final values = item.values;
    if (values.isNotEmpty) {
      final lead = values.first;
      return 'Первая позиция в списке задаёт тон всему набору: ${_s(lead['label'])} со значением ${_s(lead['val'], fallback: '${_n(lead['percent']).toStringAsFixed(0)}%')}.';
    }
    return 'Дополнительный аналитический блок с локальными фактами и опорными значениями.';
  }

  // Convert BlockContentItem back to Map for the raw Map-based helpers
  Map<String, dynamic> _toMap(BlockContentItem item) => {
        'type': item.type,
        'title': item.title,
        'val': item.val,
        'sub': item.sub,
        'data': item.data,
        'values': item.values,
        'img': item.img,
        'url': item.url,
      };

  // -----------------------------------------------------------------------
  // Warning banner
  // -----------------------------------------------------------------------

  Widget _warningBanner(String message) => GlassPanel(
        accent: const Color(0xFFF59E0B),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
                  '\u041F\u043E\u043A\u0430\u0437\u0430\u043D \u043B\u043E\u043A\u0430\u043B\u044C\u043D\u044B\u0439 \u0441\u043D\u0438\u043C\u043E\u043A \u0434\u0430\u043D\u043D\u044B\u0445. $message',
                  style: AppTextStyles.subtitle
                      .copyWith(fontSize: 12, height: 1.45))),
        ]),
      );

  // -----------------------------------------------------------------------
  // Loading / error states
  // -----------------------------------------------------------------------

  Widget _loadingState() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _topBar(),
          const SizedBox(height: 16),
          ...const [188.0, 108.0, 268.0, 232.0].map((height) => Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: GlassPanel(
                  accent: Color(0xFF00E5FF),
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                      height: height,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00E5FF)))),
                ),
              )),
        ],
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassPanel(
            accent: const Color(0xFFFF6B6B),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.insights_rounded,
                  color: PulseColors.textPrimary, size: 38),
              const SizedBox(height: 16),
              Text(
                  '\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044C \u0438\u043D\u0444\u043E\u0433\u0440\u0430\u0444\u0438\u043A\u0443',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.section.copyWith(fontSize: 16)),
              const SizedBox(height: 10),
              Text(_error ?? 'unknown error',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle
                      .copyWith(fontSize: 13, height: 1.5)),
              const SizedBox(height: 18),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ]),
          ),
        ),
      );

  // -----------------------------------------------------------------------
  // Data helpers
  // -----------------------------------------------------------------------

  bool _isChart(String type) =>
      type == 'line_chart' || type == 'bar_chart' || type == 'dual_chart';

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : const [];

  String _s(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  double _n(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  double _pick(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is num || value is String) return _n(value);
    }
    for (final entry in row.entries) {
      if (entry.value is num) return _n(entry.value);
    }
    return 0;
  }

  String _fmt(num value) {
    final text =
        value.toStringAsFixed(value is int ? 0 : (value % 1 == 0 ? 0 : 1));
    final parts = text.split('.');
    final whole = parts.first;
    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      final reverse = whole.length - i;
      buffer.write(whole[i]);
      if (reverse > 1 && reverse % 3 == 1) buffer.write(' ');
    }
    return parts.length == 1 || parts[1] == '0'
        ? buffer.toString()
        : '${buffer.toString()}.${parts[1]}';
  }

  String _unit(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('\u20BD') || lower.contains('зарплат')) return '\u20BD';
    if (lower.contains('%')) return '%';
    return '';
  }

  String _date(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  String _trend(String trend) {
    switch (trend) {
      case 'strong_growth':
        return '\u0421\u0438\u043B\u044C\u043D\u044B\u0439 \u0440\u043E\u0441\u0442';
      case 'moderate_growth':
      case 'growth':
        return '\u0420\u043E\u0441\u0442';
      case 'recovery':
        return '\u0412\u043E\u0441\u0441\u0442\u0430\u043D\u043E\u0432\u043B\u0435\u043D\u0438\u0435';
      case 'stable':
        return '\u0421\u0442\u0430\u0431\u0438\u043B\u044C\u043D\u043E';
      default:
        return '\u0410\u043A\u0442\u0438\u0432\u043D\u044B\u0439 \u0431\u043B\u043E\u043A';
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

  // -----------------------------------------------------------------------
  // Small inline UI helpers
  // -----------------------------------------------------------------------

  Widget _circleButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PulseColors.textPrimary.withOpacity(0.05),
            border:
                Border.all(color: PulseColors.textPrimary.withOpacity(0.08)),
          ),
          child: Icon(icon, color: PulseColors.textPrimary, size: 18),
        ),
      );
}
