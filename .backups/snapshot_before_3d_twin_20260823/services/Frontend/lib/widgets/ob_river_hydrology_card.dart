import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../map/map_config.dart';
import '../screens/map/widgets/video_dialog.dart';

/// Объединенный мега-блок «Гидропост и Паводок реки Обь» в Нижневартовске.
/// Включает:
///  • Live-камеру с набережной Оби;
///  • Температуру воздуха и воды;
///  • Текущий уровень реки Обь с волновой шкалой;
///  • Интерактивный 3-летний график паводка (2024–2026);
///  • Сектора риска (Набережная, РЭБ Флота, СОНТ).
class ObRiverHydrologyCard extends StatefulWidget {
  final double? currentLevelCm;
  final double? dailyChangeCm;
  final double? criticalLevelCm;
  final double? airTempC;

  const ObRiverHydrologyCard({
    super.key,
    this.currentLevelCm,
    this.dailyChangeCm,
    this.criticalLevelCm,
    this.airTempC,
  });

  @override
  State<ObRiverHydrologyCard> createState() => _ObRiverHydrologyCardState();
}

class _ObRiverHydrologyCardState extends State<ObRiverHydrologyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  int _selectedSectorIndex = 0;
  bool _showChart = true;

  double _levelCm = 712.0;
  double _changeCm = -2.0;
  double _critCm = 940.0;
  double _waterTempC = 14.2;
  double _airTempC = 16.0;

  // Water levels in cm for Nizhnevartovsk (Ob river) for 3 years: 2024, 2025, 2026
  final Map<int, List<double>> _floodData = {
    2024: [520, 690, 880, 945, 981, 930, 850], // 2024 Peak: 981 cm (Record)
    2025: [480, 630, 795, 890, 840, 770, 710], // 2025 Peak: 890 cm (Moderate)
    2026: [460, 600, 745, 780, 740, 712, 695], // 2026 Peak: 780 cm (Current: 712 cm)
  };

  final List<String> _chartDates = [
    '01.05', '15.05', '01.06', '15.06', '01.07', '15.07', '31.07'
  ];

  final List<Map<String, dynamic>> _sectors = [
    {
      'name': 'Набережная Оби',
      'location': 'Створ ул. Пикмана / Ф. Салманова',
      'safetyLevelCm': 980.0,
      'risk': 'Безопасно',
      'riskColor': const Color(0xFF10B981),
      'description': 'Берегоукрепление и гранитный парапет выдерживают до 10.5 м.',
    },
    {
      'name': 'РЭБ Флота / Старый Вартовск',
      'location': 'Протока Вартовская',
      'safetyLevelCm': 890.0,
      'risk': 'Мониторинг',
      'riskColor': const Color(0xFF38BDF8),
      'description': 'Дороги сухие, проезд свободный, патрулирование гидропостов.',
    },
    {
      'name': 'СОНТ «Буровик» / Островной',
      'location': 'Пойма реки Обь',
      'safetyLevelCm': 850.0,
      'risk': 'Безопасно',
      'riskColor': const Color(0xFF10B981),
      'description': 'Низменная пойма. Регулярное патрулирование МЧС и гидропостов.',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.currentLevelCm != null) _levelCm = widget.currentLevelCm!;
    if (widget.dailyChangeCm != null) _changeCm = widget.dailyChangeCm!;
    if (widget.criticalLevelCm != null) _critCm = widget.criticalLevelCm!;
    if (widget.airTempC != null) _airTempC = widget.airTempC!;

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fetchLiveHydrology();
  }

  Future<void> _fetchLiveHydrology() async {
    try {
      final url = Uri.parse('${MapConfig.backendApiBaseUrl}/flood/status');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (mounted) {
          setState(() {
            _levelCm = (data['current_level_cm'] as num?)?.toDouble() ?? _levelCm;
            _changeCm = (data['daily_change_cm'] as num?)?.toDouble() ?? _changeCm;
            _waterTempC = (data['water_temp_c'] as num?)?.toDouble() ?? _waterTempC;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _openEmbankmentCamera() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => const VideoPlayerDialog(
        title: 'Камера Набережной реки Обь (Прайд)',
        url: 'https://nginx01.pride-net.ru/cam_60l8/index.m3u8',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelRatio = (_levelCm / _critCm).clamp(0.0, 1.2);
    final sector = _sectors[_selectedSectorIndex];
    final isWarning = _levelCm >= 850.0;
    final themeColor = isWarning ? const Color(0xFFF59E0B) : const Color(0xFF00E5FF);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColor.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.14),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. Header ───
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor.withOpacity(0.6)),
                ),
                child: Icon(Icons.water_drop_rounded, color: themeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ГИДРОПОСТ И ПАВОДОК РЕКИ ОБЬ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'Нижневартовск • Гидроствор реки Обь',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (sector['riskColor'] as Color).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (sector['riskColor'] as Color).withOpacity(0.5)),
                ),
                child: Text(
                  sector['risk'] as String,
                  style: TextStyle(
                    color: sector['riskColor'] as Color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ─── 2. Live Camera Banner ───
          GestureDetector(
            onTap: _openEmbankmentCamera,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0284C7).withOpacity(0.3),
                    const Color(0xFF0F172A).withOpacity(0.9),
                  ],
                ),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=800'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'LIVE КАМЕРА НАБЕРЕЖНОЙ',
                            style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Створ ул. Пикмана',
                        style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00E5FF).withOpacity(0.3),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 16),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Нажмите для просмотра видео в реальном времени',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.fullscreen_rounded, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ─── 3. Temperatures & Level ───
          Row(
            children: [
              // Уровень реки
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_levelCm.round()}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          shadows: [
                            Shadow(color: themeColor.withOpacity(0.6), blurRadius: 14),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5, left: 4),
                        child: Text(
                          'см',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Text('над нулем поста', style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                ],
              ),
              const Spacer(),
              // Температура воды в Оби
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.water_rounded, color: Color(0xFF00E5FF), size: 12),
                        SizedBox(width: 4),
                        Text('ВОДА В ОБИ', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${_waterTempC.toStringAsFixed(1)}°C',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Температура воздуха
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 12),
                        SizedBox(width: 4),
                        Text('ВОЗДУХ', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_airTempC > 0 ? "+" : ""}${_airTempC.round()}°C',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── 4. Wave Gauge ───
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 22,
              child: Stack(
                children: [
                  Container(color: Colors.white.withOpacity(0.06)),
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      return FractionallySizedBox(
                        widthFactor: levelRatio.clamp(0.05, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00E5FF).withOpacity(0.7),
                                (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF007AFF)).withOpacity(0.9),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('0 см', style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                          Text(
                            'Опасный уровень: ${_critCm.round()} см',
                            style: const TextStyle(color: Color(0xFFFF9500), fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── 5. Toggle 3-Year Comparison Chart ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ДИНАМИКА ПАВОДКА (2024–2026)',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showChart = !_showChart);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _showChart ? 'Свернуть' : 'Развернуть график',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_showChart) ...[
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 200,
                    getDrawingHorizontalLine: (val) => FlLine(color: Colors.white10, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 8.5)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) {
                          final idx = v.toInt();
                          if (idx >= 0 && idx < _chartDates.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_chartDates[idx], style: const TextStyle(color: Colors.white54, fontSize: 9)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 400,
                  maxY: 1050,
                  lineBarsData: [
                    // 2024
                    LineChartBarData(
                      spots: _floodData[2024]!.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      color: Colors.redAccent.withOpacity(0.6),
                      barWidth: 1.8,
                      dotData: const FlDotData(show: false),
                    ),
                    // 2025
                    LineChartBarData(
                      spots: _floodData[2025]!.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      color: Colors.amberAccent.withOpacity(0.6),
                      barWidth: 1.8,
                      dotData: const FlDotData(show: false),
                    ),
                    // 2026 (Текущий)
                    LineChartBarData(
                      spots: _floodData[2026]!.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      color: const Color(0xFF00E5FF),
                      barWidth: 3.0,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF00E5FF).withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Легенда
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: Colors.redAccent, label: '2024 (Пик 981 см)'),
                SizedBox(width: 12),
                _LegendItem(color: Colors.amberAccent, label: '2025 (Пик 890 см)'),
                SizedBox(width: 12),
                _LegendItem(color: Color(0xFF00E5FF), label: '2026 (Текущий 712 см)'),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // ─── 6. Sectors Chips & Description ───
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_sectors.length, (idx) {
                final s = _sectors[idx];
                final isSelected = _selectedSectorIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      s['name'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: themeColor,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    side: BorderSide(color: isSelected ? themeColor : Colors.white12),
                    onSelected: (val) {
                      if (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedSectorIndex = idx);
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: themeColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sector['description'] as String,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
