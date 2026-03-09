import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class InfographicScreen extends StatefulWidget {
  const InfographicScreen({super.key});

  @override
  State<InfographicScreen> createState() => _InfographicScreenState();
}

class _InfographicScreenState extends State<InfographicScreen> {
  static const _summaryUrl =
      'https://xpainxohbdoruakcijyq.supabase.co/rest/v1/infographic_data?data_type=eq.summary&select=data';
  static const _supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';

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
    try {
      final response = await http.get(
        Uri.parse(_summaryUrl),
        headers: {
          'apikey': _supabaseKey,
          'Authorization': 'Bearer $_supabaseKey',
        },
      ).timeout(const Duration(seconds: 8));
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

    final asset = await rootBundle.loadString('assets/infographic_data.json');
    return jsonDecode(asset) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _maps(_data?['blocks']);
    return Scaffold(
      backgroundColor: const Color(0xFF030711),
      body: Stack(
        children: [
          const Positioned.fill(child: _InfographicBackdrop()),
          SafeArea(
            child: _loading && _data == null
                ? _loadingState()
                : _error != null && _data == null
                    ? _errorState()
                    : RefreshIndicator(
                        color: const Color(0xFF00E5FF),
                        backgroundColor: const Color(0xFF09111E),
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

  Widget _topBar() {
    return _GlassPanel(
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
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\u041D\u0430\u0442\u0438\u0432\u043D\u044B\u0439 \u0432\u0438\u0437\u0443\u0430\u043B\u044C\u043D\u044B\u0439 \u043E\u0442\u0447\u0435\u0442',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

  Widget _hero() {
    final data = _data!;
    final blocks = _maps(data['blocks']);
    final chartCount = blocks.fold<int>(0, (sum, block) {
      return sum +
          _maps(block['items'])
              .where((item) => _isChart(_s(item['type'])))
              .length;
    });
    return _GlassPanel(
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
                      _s(data['city']),
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_s(data['region'])} • ${_date(_s(data['updated_at']))}',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.72),
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
              color: Colors.white.withOpacity(0.78),
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
                  _fmt(_n(data['population_current'])),
                  const Color(0xFF7C4DFF)),
              _pill(Icons.dataset_rounded, 'Datasets',
                  _s(data['total_datasets']), const Color(0xFFF8D24A)),
              _pill(Icons.grid_view_rounded, '\u0411\u043B\u043E\u043A\u0438',
                  blocks.length.toString(), const Color(0xFF21F3C3)),
              _pill(
                  Icons.square_foot_rounded,
                  '\u041F\u043B\u043E\u0449\u0430\u0434\u044C',
                  '${_n(data['area_km2']).toStringAsFixed(1)} km²',
                  const Color(0xFF38BDF8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _block(Map<String, dynamic> block) {
    final accent = _accent(_s(block['id']), _s(block['trend']));
    final items = _maps(block['items']);
    final news =
        items.where((item) => _s(item['type']) == 'news_card').toList();
    final content =
        items.where((item) => _s(item['type']) != 'news_card').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      accent.withOpacity(0.85),
                      accent.withOpacity(0.25)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(_icon(_s(block['icon'])),
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _s(block['title']),
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _trend(_s(block['trend'])),
                      style: GoogleFonts.inter(
                        color: accent.withOpacity(0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassPanel(
          accent: accent,
          padding: const EdgeInsets.all(16),
          child: Text(
            _s(block['analysis']),
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.76),
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...content.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _itemCard(item, accent),
              )),
        ],
        if (news.isNotEmpty) _newsStrip(news, accent),
      ],
    );
  }

  Widget _itemCard(Map<String, dynamic> item, Color accent) {
    final type = _s(item['type']);
    if (_isChart(type)) {
      return _ChartCard(
        title: _s(item['title']),
        accent: accent,
        unit: _unit(_s(item['title'])),
        hint: type == 'dual_chart'
            ? '\u041D\u0430\u0436\u043C\u0438\u0442\u0435 \u043D\u0430 \u043B\u0438\u043D\u0438\u0438, \u0447\u0442\u043E\u0431\u044B \u0440\u0430\u0441\u043A\u0440\u044B\u0442\u044C \u0441\u0440\u0430\u0432\u043D\u0435\u043D\u0438\u0435'
            : '\u041D\u0430\u0436\u043C\u0438\u0442\u0435 \u043D\u0430 \u0433\u0440\u0430\u0444\u0438\u043A, \u0447\u0442\u043E\u0431\u044B \u0440\u0430\u0441\u043A\u0440\u044B\u0442\u044C \u0442\u0440\u0435\u043D\u0434',
        kind: type == 'bar_chart'
            ? _ChartKind.bar
            : (type == 'dual_chart' ? _ChartKind.dual : _ChartKind.line),
        series: _series(item, accent),
      );
    }

    return _GlassPanel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _s(item['title']),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _factChips(item, accent),
          ),
        ],
      ),
    );
  }

  List<Widget> _factChips(Map<String, dynamic> item, Color accent) {
    final type = _s(item['type']);
    if (type == 'stat') {
      return [
        _factChip(_s(item['title']), _s(item['val']), accent, _s(item['sub']))
      ];
    }
    if (type == 'grid' || type == 'list') {
      return _maps(item['values']).asMap().entries.map((entry) {
        final value = entry.value;
        final label = _s(value['label']).trim().isEmpty
            ? '\u041F\u043E\u0437\u0438\u0446\u0438\u044F ${entry.key + 1}'
            : _s(value['label']);
        return _factChip(label, _s(value['val']), accent, '');
      }).toList();
    }
    if (type == 'progress_list') {
      return _maps(item['values']).map((value) {
        return _factChip(_s(value['label']),
            '${_n(value['percent']).toStringAsFixed(0)}%', accent, '');
      }).toList();
    }
    return [_factChip(_s(item['title']), '-', accent, '')];
  }

  Widget _newsStrip(List<Map<String, dynamic>> items, Color accent) {
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
              child: _GlassPanel(
                accent: accent,
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _s(item['img']) == '-'
                            ? Container(color: const Color(0xFF0B1528))
                            : Image.network(
                                _s(item['img']),
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
                              _s(item['title']),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _s(item['url']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.58),
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

  List<_Series> _series(Map<String, dynamic> item, Color accent) {
    final type = _s(item['type']);
    final data = _maps(item['data']);
    if (type == 'dual_chart') {
      return [
        _Series(
          _s(item['series_a_label'], fallback: 'A'),
          const Color(0xFF00E5FF),
          _points(data, ['birth', 'series_a', 'value']),
        ),
        _Series(
          _s(item['series_b_label'], fallback: 'B'),
          const Color(0xFFF8D24A),
          _points(data, ['marriages', 'series_b', 'value_2']),
        ),
      ];
    }
    return [
      _Series(_s(item['title']), accent,
          _points(data, ['value', 'salary', 'gid', 'count']))
    ];
  }

  List<_Point> _points(List<Map<String, dynamic>> rows, List<String> keys) {
    return rows.asMap().entries.map((entry) {
      final row = entry.value;
      return _Point(
          _s(row['year'], fallback: '${entry.key + 1}'), _pick(row, keys));
    }).toList();
  }

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
    if (value is num) {
      return value.toDouble();
    }
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
    if (lower.contains('\u20bd') || lower.contains('зарплат')) return '\u20bd';
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
      case 'news':
        return const Color(0xFFFF7C5C);
      case 'eco':
        return const Color(0xFF80ED99);
      default:
        return trend == 'stable'
            ? const Color(0xFF8B9BB5)
            : const Color(0xFF4D8DFF);
    }
  }

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
      default:
        return Icons.insights_rounded;
    }
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(text,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  Widget _pill(IconData icon, String label, String value, Color accent) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 8),
          Text('$label • $value',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ]),
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
                  color: Colors.white.withOpacity(0.56),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.52), fontSize: 10.5)),
          ],
        ]),
      );

  Widget _warningBanner(String message) => _GlassPanel(
        accent: const Color(0xFFF59E0B),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
                  '\u041F\u043E\u043A\u0430\u0437\u0430\u043D \u043B\u043E\u043A\u0430\u043B\u044C\u043D\u044B\u0439 \u0441\u043D\u0438\u043C\u043E\u043A \u0434\u0430\u043D\u043D\u044B\u0445. $message',
                  style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 12,
                      height: 1.45))),
        ]),
      );

  Widget _loadingState() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _topBar(),
          const SizedBox(height: 16),
          ...const [188.0, 108.0, 268.0, 232.0].map((height) => Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: _GlassPanel(
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
          child: _GlassPanel(
            accent: const Color(0xFFFF6B6B),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 38),
              const SizedBox(height: 16),
              Text(
                  '\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044C \u0438\u043D\u0444\u043E\u0433\u0440\u0430\u0444\u0438\u043A\u0443',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(_error ?? 'unknown error',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.5)),
              const SizedBox(height: 18),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ]),
          ),
        ),
      );
}

class _Point {
  const _Point(this.label, this.value);
  final String label;
  final double value;
}

class _Series {
  const _Series(this.label, this.color, this.points);
  final String label;
  final Color color;
  final List<_Point> points;
}

enum _ChartKind { line, bar, dual }

class _ChartCard extends StatefulWidget {
  const _ChartCard({
    required this.title,
    required this.accent,
    required this.kind,
    required this.hint,
    required this.series,
    required this.unit,
  });

  final String title;
  final Color accent;
  final _ChartKind kind;
  final String hint;
  final List<_Series> series;
  final String unit;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard>
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

    return _GlassPanel(
      accent: widget.accent,
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
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(widget.hint,
                        style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.62),
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
                      color: Colors.white.withOpacity(0.05),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.08))),
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
                child: widget.kind == _ChartKind.bar
                    ? BarChart(_barData())
                    : LineChart(_lineData(widget.kind == _ChartKind.line))),
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
                  delta >= 0
                      ? const Color(0xFF21F3C3)
                      : const Color(0xFFFF7C5C)),
              _metric('${_value(maxY)}${widget.unit}', 'Peak',
                  const Color(0xFFF8D24A)),
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
                      color: Colors.white.withOpacity(0.04),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.06))),
                  child: Wrap(spacing: 10, runSpacing: 10, children: [
                    _detail('\u0422\u043E\u0447\u0435\u043A',
                        primary.points.length.toString()),
                    _detail(
                        widget.kind == _ChartKind.dual
                            ? '\u0421\u0435\u0440\u0438\u0439'
                            : '\u0424\u043E\u0440\u043C\u0430\u0442',
                        widget.kind == _ChartKind.dual
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
                      color: Colors.white,
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
                  Colors.white.withOpacity(0.92)
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
                                ? Colors.white
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
                  color: Colors.white,
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
                        ? [Colors.white, widget.accent]
                        : [
                            widget.accent.withOpacity(0.88),
                            widget.accent.withOpacity(0.35)
                          ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter),
                backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: padded,
                    color: Colors.white.withOpacity(0.04)))
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

  FlTitlesData _titles(List<_Point> points) {
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
                      color: Colors.white.withOpacity(0.42),
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
                            color: Colors.white
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
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _detail(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.black.withOpacity(0.14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel(
      {required this.accent,
      required this.child,
      this.padding = const EdgeInsets.all(18)});

  final Color accent;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.085),
                const Color(0xFF111A2B).withOpacity(0.78)
              ],
            ),
            border: Border.all(color: accent.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.46),
                  blurRadius: 28,
                  offset: const Offset(10, 16)),
              BoxShadow(
                  color: Colors.white.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(-8, -8)),
              BoxShadow(
                  color: accent.withOpacity(0.12),
                  blurRadius: 30,
                  spreadRadius: -6),
            ],
          ),
          child: Stack(children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: RadialGradient(
                        center: const Alignment(-0.85, -0.9),
                        radius: 1.3,
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.transparent
                        ]),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _InnerGlowPainter(accent)),
              ),
            ),
            Padding(padding: padding, child: child),
          ]),
        ),
      ),
    );
  }
}

class _InnerGlowPainter extends CustomPainter {
  const _InnerGlowPainter(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
        accent.withOpacity(0.22),
        Colors.transparent,
        Colors.white.withOpacity(0.05)
      ], const [
        0,
        0.45,
        1
      ])
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(0.8), const Radius.circular(28)),
        paint);
  }

  @override
  bool shouldRepaint(covariant _InnerGlowPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _InfographicBackdrop extends StatelessWidget {
  const _InfographicBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF030711),
                Color(0xFF071123),
                Color(0xFF02050D)
              ]),
        ),
      ),
      const Positioned(
          top: -140, right: -100, child: _BlurBlob(Color(0x2E00E5FF), 280)),
      const Positioned(
          top: 240, left: -90, child: _BlurBlob(Color(0x247C4DFF), 240)),
      const Positioned(
          bottom: -120, right: 20, child: _BlurBlob(Color(0x1FF8D24A), 260)),
      Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _GridPainter()))),
    ]);
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob(this.color, this.size);
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 64, sigmaY: 64),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color, Colors.transparent])),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.8;
    for (double y = 0; y < size.height; y += 72) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 72) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        ..color = Color.lerp(Colors.white, accent, seed.mix)!
            .withOpacity(fade * seed.opacity)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
      canvas.drawCircle(offset, seed.size * fade, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
