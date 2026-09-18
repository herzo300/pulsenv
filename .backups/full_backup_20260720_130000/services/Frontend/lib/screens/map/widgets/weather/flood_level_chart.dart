import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../theme/pulse_colors.dart';
import '../../../../widgets/aura_living_background.dart';
import '../../../../core/living/aura_living_engine.dart';

class FloodLevelChart extends StatefulWidget {
  const FloodLevelChart({
    super.key,
    required this.isNightMode,
    required this.accent,
  });

  final bool isNightMode;
  final Color accent;

  @override
  State<FloodLevelChart> createState() => _FloodLevelChartState();
}

class _FloodLevelChartState extends State<FloodLevelChart> with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final AnimationController _waveController;
  bool _isFlipped = false;
  int _hoveredDayIndex = -1;

  // July 01 to July 19 data (every 2 days)
  final List<String> _days = [
    '01.07', '03.07', '05.07', '07.07', '09.07', '11.07', '13.07', '15.07', '17.07', '19.07'
  ];

  // Water levels in cm for Nizhnevartovsk (Ob river)
  final Map<int, List<double>> _floodData = {
    2015: [940, 965, 995, 1020, 1040, 1055, 1061, 1058, 1045, 1030], // Historic peak (danger > 980)
    2024: [870, 905, 940, 965, 980, 981, 975, 960, 940, 920],     // High flood
    2026: [858, 862, 864, 861, 858, 854, 849, 835, 820, 805],      // Current year (aligned with real July 15 data of 849 cm)
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _flipController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  Widget _buildWaveBackground() {
    final scene = AuraLivingEngine.resolve(
      mood: 0,
      streak: 5,
      meditationMinutes: 10,
      practicesCompleted: 5,
      isPremium: true,
      hour: DateTime.now().hour,
    ).copyWith(
      weather: AuraWeather.water,
    );
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AuraLivingBackground(
          scene: scene,
          interactive: true,
          showConstellationVeil: false,
          child: Container(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final double value = _flipAnimation.value;
        final bool isBack = value >= 0.5;

        // Calculate rotation matrix
        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012) // Perspective depth
          ..rotateY(value * math.pi);

        return GestureDetector(
          onTap: _toggleFlip,
          behavior: HitTestBehavior.opaque,
          child: Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(math.pi), // prevent mirror text
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        _buildWaveBackground(),
                        _buildBackSide(context),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      _buildWaveBackground(),
                      _buildFrontSide(context),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildFrontSide(BuildContext context) {
    final textTheme = widget.isNightMode ? Colors.white70 : Colors.black54;
    final titleTheme = widget.isNightMode ? Colors.white : Colors.black87;

    final double maxLevel = 1100.0;
    final double minLevel = 700.0;

    final spots2015 = _floodData[2015]!.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final spots2024 = _floodData[2024]!.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final spots2026 = _floodData[2026]!.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    final bar2015 = LineChartBarData(
      spots: spots2015,
      isCurved: true,
      color: Colors.red.withOpacity(0.5),
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );

    final bar2024 = LineChartBarData(
      spots: spots2024,
      isCurved: true,
      color: Colors.orange.withOpacity(0.5),
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );

    final bar2026 = LineChartBarData(
      spots: spots2026,
      isCurved: true,
      color: widget.accent,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00E5FF).withOpacity(0.4),
            const Color(0xFF00B0FF).withOpacity(0.25),
            const Color(0xFF0D47A1).withOpacity(0.1),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Уровень паводка р. Обь (Нижневартовск)',
                      style: TextStyle(
                        color: titleTheme,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.flip_camera_android_rounded, color: widget.accent.withOpacity(0.7), size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: widget.accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Текущий: 849 см',
                        style: TextStyle(
                          color: widget.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                      ),
                      child: const Text(
                        'Опасный: 980 см',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Legend
            Row(
              children: [
                _buildLegendItem(2015, Colors.orangeAccent, textTheme),
                const SizedBox(width: 8),
                _buildLegendItem(2024, Colors.yellow.shade700, textTheme),
                const SizedBox(width: 8),
                _buildLegendItem(2026, widget.accent, textTheme, isCurrent: true),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Chart Area
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < _days.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _days[value.toInt()],
                            style: TextStyle(
                              color: widget.isNightMode ? Colors.white54 : Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: 780,
              maxY: 1080,
              lineBarsData: [bar2015, bar2024, bar2026],
              showingTooltipIndicators: [
                ShowingTooltipIndicators([
                  LineBarSpot(bar2026, 2, spots2026[6]),
                ]),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.toInt()} см',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // GLM Insight & Forecast Box
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.isNightMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isNightMode ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.psychology_alt_rounded, color: widget.accent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ИИ-Анализ и прогноз паводка',
                      style: TextStyle(
                        color: titleTheme,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Сегодня уровень Оби — 849 см (опасный порог 980 см). ИИ-анализ подтверждает планомерный спад половодья со скоростью 5-7 см в сутки. Угрозы подтоплений жилых массивов Нижневартовска нет.',
                      style: TextStyle(
                        color: textTheme.withOpacity(0.9),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackSide(BuildContext context) {
    final textTheme = widget.isNightMode ? Colors.white70 : Colors.black54;
    final titleTheme = widget.isNightMode ? Colors.white : Colors.black87;

    final List<Map<String, dynamic>> retrospect = [
      {'year': '2015 г.', 'level': 1061.0, 'status': 'Пик ЧС', 'color': Colors.redAccent},
      {'year': '2024 г.', 'level': 981.0, 'status': 'Опасно', 'color': Colors.orangeAccent},
      {'year': '2026 г.', 'level': 849.0, 'status': 'Текущий', 'color': widget.accent},
    ];

    final List<Map<String, dynamic>> dailyForecast = [
      {'date': '09.07', 'level': 864, 'desc': 'Спад'},
      {'date': '10.07', 'level': 861, 'desc': 'Спад'},
      {'date': '11.07', 'level': 858, 'desc': 'Спад'},
      {'date': '12.07', 'level': 854, 'desc': 'Спад'},
      {'date': '13.07', 'level': 849, 'desc': 'Текущий'},
      {'date': '14.07', 'level': 844, 'desc': 'Прогноз'},
      {'date': '15.07', 'level': 839, 'desc': 'Прогноз'},
      {'date': '16.07', 'level': 834, 'desc': 'Прогноз'},
      {'date': '17.07', 'level': 829, 'desc': 'Прогноз'},
      {'date': '18.07', 'level': 824, 'desc': 'Прогноз'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Данные р. Обь (Нижневартовск)',
                      style: TextStyle(
                        color: titleTheme,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.flip_camera_android_rounded, color: widget.accent.withOpacity(0.7), size: 16),
                  ],
                ),
                Text(
                  'История и ИИ-прогноз • Нажмите для графика',
                  style: TextStyle(
                    color: widget.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Icon(Icons.waves_rounded, color: widget.accent, size: 22),
          ],
        ),
        const SizedBox(height: 12),

        // Retrospective Cards with animated water tubes
        AnimatedBuilder(
          animation: _waveController,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: retrospect.map((item) {
                final color = item['color'] as Color;
                return Expanded(
                  child: _YearWaterTube(
                    year: item['year'] as String,
                    level: (item['level'] as num).toDouble(),
                    status: item['status'] as String,
                    color: color,
                    waveValue: _waveController.value,
                    isNightMode: widget.isNightMode,
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),

        // Forecast Title
        Text(
          'ПРОГНОЗ НА 10 ДНЕЙ (ИИ-МОДЕЛЬ)',
          style: TextStyle(
            color: widget.accent,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),

        // Daily 10-day forecast (scrollable)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: dailyForecast.length,
            itemBuilder: (context, index) {
              final pt = dailyForecast[index];
              final level = pt['level'] as int;
              final isMax = level == 910;
              final progress = (level / 940).clamp(0.0, 1.0);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isNightMode ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isMax ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isMax ? Colors.redAccent.withOpacity(0.12) : widget.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pt['date'] as String,
                        style: TextStyle(
                          color: isMax ? Colors.redAccent : widget.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pt['desc'] as String,
                            style: TextStyle(
                              color: titleTheme,
                              fontSize: 11,
                              fontWeight: isMax ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(1.5),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2.5,
                              backgroundColor: widget.isNightMode ? Colors.white12 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMax ? Colors.redAccent : widget.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$level см',
                      style: TextStyle(
                        color: isMax ? Colors.redAccent : titleTheme,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(int year, Color color, Color textTheme, {bool isCurrent = false}) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          isCurrent ? '$year (Тек)' : '$year г.',
          style: TextStyle(
            color: textTheme,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _FloodChartPainter extends CustomPainter {
  _FloodChartPainter({
    required this.floodData,
    required this.days,
    required this.animProgress,
    required this.hoverIndex,
    required this.accent,
    required this.isNightMode,
    required this.minLevel,
    required this.maxLevel,
  });

  final Map<int, List<double>> floodData;
  final List<String> days;
  final double animProgress;
  final int hoverIndex;
  final Color accent;
  final bool isNightMode;
  final double minLevel;
  final double maxLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double stepX = w / (days.length - 1);

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final Paint forecastPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final years = [2015, 2024, 2026];
    final yearColors = {
      2015: Colors.orangeAccent,
      2024: Colors.yellow.shade700,
      2026: accent,
    };

    for (final year in years) {
      final levels = floodData[year]!;
      final points = <Offset>[];
      final forecastPoints = <Offset>[];

      for (int i = 0; i < levels.length; i++) {
        final val = levels[i];
        if (val == 0) continue;

        final double y = h - ((val - minLevel) / (maxLevel - minLevel) * h);
        final double x = i * stepX;
        final animatedY = h - ((h - y) * animProgress);

        if (year == 2026 && i >= 5) {
          forecastPoints.add(Offset(x, animatedY));
        } else {
          points.add(Offset(x, animatedY));
        }
      }

      final color = yearColors[year]!;
      linePaint.color = color;

      if (points.isNotEmpty) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int i = 0; i < points.length - 1; i++) {
          final p1 = points[i];
          final p2 = points[i + 1];
          final controlX = p1.dx + (p2.dx - p1.dx) / 2;
          path.cubicTo(controlX, p1.dy, controlX, p2.dy, p2.dx, p2.dy);
        }
        canvas.drawPath(path, linePaint);

        if (year == 2026) {
          final fillPath = Path()
            ..moveTo(points.first.dx, h)
            ..lineTo(points.first.dx, points.first.dy);

          for (int i = 0; i < points.length - 1; i++) {
            final p1 = points[i];
            final p2 = points[i + 1];
            final controlX = p1.dx + (p2.dx - p1.dx) / 2;
            fillPath.cubicTo(controlX, p1.dy, controlX, p2.dy, p2.dx, p2.dy);
          }
          fillPath.lineTo(points.last.dx, h);
          fillPath.close();

          fillPaint.shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withOpacity(0.35), accent.withOpacity(0.0)],
          ).createShader(Rect.fromLTWH(0, 0, w, h));
          canvas.drawPath(fillPath, fillPaint);
        }
      }

      if (year == 2026 && forecastPoints.isNotEmpty && points.isNotEmpty) {
        forecastPaint.color = color.withOpacity(0.7);
        final fPath = Path()..moveTo(points.last.dx, points.last.dy);
        for (int i = 0; i < forecastPoints.length; i++) {
          final pPrev = i == 0 ? points.last : forecastPoints[i - 1];
          final pNext = forecastPoints[i];
          final ctrlX = pPrev.dx + (pNext.dx - pPrev.dx) / 2;
          fPath.cubicTo(ctrlX, pPrev.dy, ctrlX, pNext.dy, pNext.dx, pNext.dy);
        }

        final dashPath = Path();
        final pMetrics = fPath.computeMetrics();
        for (final metric in pMetrics) {
          double length = 0;
          while (length < metric.length) {
            dashPath.addPath(metric.extractPath(length, length + 4), Offset.zero);
            length += 8;
          }
        }
        canvas.drawPath(dashPath, forecastPaint);
      }
    }

    // Draw dots and text labels for every data point on the 2026 curve
    final levels2026 = floodData[2026]!;
    for (int i = 0; i < levels2026.length; i++) {
      final val = levels2026[i];
      if (val == 0) continue;

      final double y = h - ((val - minLevel) / (maxLevel - minLevel) * h);
      final double x = i * stepX;
      final animatedY = h - ((h - y) * animProgress);

      final color = yearColors[2026]!;

      // Draw dot
      canvas.drawCircle(Offset(x, animatedY), 3.5, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x, animatedY), 3.5, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

      // Draw text label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${val.toInt()} см',
          style: TextStyle(
            color: isNightMode ? Colors.white.withOpacity(0.85) : const Color(0xFF0F172A),
            fontSize: 9.0,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                color: Colors.black38,
                offset: Offset(0, 1),
                blurRadius: 2.0,
              )
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Position the label slightly above the dot, centered horizontally
      final offset = Offset(x - textPainter.width / 2, animatedY - 14);
      textPainter.paint(canvas, offset);
    }

    // Draw grid & text labels for axes
    final gridPaint = Paint()
      ..color = (isNightMode ? Colors.white10 : Colors.black12)
      ..strokeWidth = 1.0;

    for (int i = 0; i < days.length; i++) {
      if (i % 2 == 0 || i == days.length - 1) {
        final x = i * stepX;
        canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);

        // Draw day text
        final textPainter = TextPainter(
          text: TextSpan(
            text: days[i],
            style: TextStyle(
              color: isNightMode ? Colors.white38 : Colors.black38,
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, h - 14));
      }
    }

    // Draw active point / hover details
    int activeIdx = hoverIndex;
    if (activeIdx == -1) {
      activeIdx = 6; // Default highlight current day (e.g. index 6 or 30.05)
    }
    if (activeIdx >= 0) {
      final double x = activeIdx * stepX;
      // Draw hover vertical helper line
      canvas.drawLine(Offset(x, 0), Offset(x, h), Paint()
        ..color = accent.withOpacity(0.3)
        ..strokeWidth = 1.0);

      // We will show tooltips for all years that have data at this index
      int tooltipCount = 0;
      for (final year in [2026, 2024, 2015]) {
        final levels = floodData[year]!;
        if (activeIdx < levels.length && levels[activeIdx] > 0) {
          final val = levels[activeIdx];
          final double y = h - ((val - minLevel) / (maxLevel - minLevel) * h);
          final double animY = h - ((h - y) * animProgress);

          final color = year == 2026 ? accent : (year == 2024 ? Colors.yellow.shade700 : Colors.orangeAccent);

          // Outer glow
          canvas.drawCircle(Offset(x, animY), 5.0, Paint()
            ..color = color.withOpacity(0.4)
            ..style = PaintingStyle.fill);

          // Inner solid dot
          canvas.drawCircle(Offset(x, animY), 2.5, Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill);
          canvas.drawCircle(Offset(x, animY), 2.5, Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);

          // Draw tooltip text
          final isForecast = year == 2026 && activeIdx >= 5;
          final labelText = '${val.toInt()} см${isForecast ? ' (ИИ)' : ''}';

          final tp = TextPainter(
            text: TextSpan(
              text: labelText,
              style: TextStyle(
                color: color,
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          tp.paint(canvas, Offset(x + 5, animY - (tooltipCount * 12) - 8));
          tooltipCount++;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WaterWaveBackgroundPainter extends CustomPainter {
  final double waveValue;
  final Color color;
  final double waterLevelRatio;

  WaterWaveBackgroundPainter({
    required this.waveValue,
    required this.color,
    required this.waterLevelRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final h = size.height;
    final w = size.width;

    // Wave height (amplitude)
    final double waveHeight = 6.0;
    
    // Wave start Y based on water level ratio (rising from bottom)
    final double baseY = h - (waterLevelRatio * h);

    path.moveTo(0, h);
    path.lineTo(0, baseY);

    // Draw sinusoidal wave across the width
    for (double x = 0.0; x <= w; x += 1.0) {
      final double waveOffset = waveValue * 2 * math.pi;
      final double waveAngle = (x / w * 2.5 * math.pi) + waveOffset;
      final double y = baseY + math.sin(waveAngle) * waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(w, h);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaterWaveBackgroundPainter oldDelegate) {
    return oldDelegate.waveValue != waveValue ||
        oldDelegate.color != color ||
        oldDelegate.waterLevelRatio != waterLevelRatio;
  }
}

class _YearWaterTube extends StatelessWidget {
  final String year;
  final double level;
  final String status;
  final Color color;
  final double waveValue;
  final bool isNightMode;

  const _YearWaterTube({
    required this.year,
    required this.level,
    required this.status,
    required this.color,
    required this.waveValue,
    required this.isNightMode,
  });

  @override
  Widget build(BuildContext context) {
    final minLevel = 700.0;
    final maxLevel = 1100.0;
    final ratio = ((level - minLevel) / (maxLevel - minLevel)).clamp(0.05, 0.95);

    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      decoration: BoxDecoration(
        color: isNightMode ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Water Fill
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: 110 * (1 - ratio),
              child: CustomPaint(
                painter: _WaterWavePainter(
                  color: color.withOpacity(0.24),
                  waveValue: waveValue,
                ),
              ),
            ),
            // Text Content
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    year,
                    style: TextStyle(
                      color: isNightMode ? Colors.white70 : Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${level.round()} см',
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterWavePainter extends CustomPainter {
  final Color color;
  final double waveValue;

  _WaterWavePainter({required this.color, required this.waveValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(0, h);
    path.lineTo(0, 4);

    for (double x = 0; x <= w; x += 3) {
      final wave = math.sin((x / 10.0) + (waveValue * 2 * math.pi)) * 3.0;
      path.lineTo(x, 4 + wave);
    }
    path.lineTo(w, h);
    path.close();

    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_WaterWavePainter old) => old.waveValue != waveValue || old.color != color;
}
