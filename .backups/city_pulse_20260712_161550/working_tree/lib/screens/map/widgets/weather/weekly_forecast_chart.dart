import 'package:flutter/material.dart';

class WeeklyForecastChart extends StatefulWidget {
  const WeeklyForecastChart({
    super.key,
    required this.isNightMode,
    required this.accent,
  });

  final bool isNightMode;
  final Color accent;

  @override
  State<WeeklyForecastChart> createState() => _WeeklyForecastChartState();
}

class _WeeklyForecastChartState extends State<WeeklyForecastChart> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> forecastData = [
      {'day': 'Пн', 'temp': 18, 'aqi': 24},
      {'day': 'Вт', 'temp': 20, 'aqi': 35},
      {'day': 'Ср', 'temp': 15, 'aqi': 18},
      {'day': 'Чт', 'temp': 12, 'aqi': 15},
      {'day': 'Пт', 'temp': 14, 'aqi': 40},
      {'day': 'Сб', 'temp': 22, 'aqi': 50},
      {'day': 'Вс', 'temp': 24, 'aqi': 30},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Прогноз температуры и активности на неделю',
          style: TextStyle(
            color: widget.isNightMode ? Colors.white70 : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(forecastData.length, (index) {
              final item = forecastData[index];
              final temp = item['temp'] as int;
              final double targetHeight = 25 + ((temp - 10).clamp(0, 15) * 4.5);
              
              final double start = (index * 0.1).clamp(0.0, 1.0);
              final double end = (start + 0.4).clamp(0.0, 1.0);
              
              final curvedAnim = CurvedAnimation(
                parent: _ctrl,
                curve: Interval(start, end, curve: Curves.easeOutBack),
              );

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FadeTransition(
                      opacity: curvedAnim,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(curvedAnim),
                        child: Text(
                          '$temp°',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.isNightMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedBuilder(
                      animation: curvedAnim,
                      builder: (context, _) {
                        return Container(
                          height: curvedAnim.value * targetHeight,
                          width: 14,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                widget.accent,
                                widget.accent.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: widget.accent.withOpacity(0.3 * curvedAnim.value),
                                blurRadius: 10 * curvedAnim.value,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['day'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isNightMode ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
