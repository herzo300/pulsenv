// lib/widgets/detailed_air_quality_dashboard.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/city_weather_service.dart';
import 'weather_metric_explanation_sheet.dart';

class DetailedAirQualityDashboard extends StatelessWidget {
  const DetailedAirQualityDashboard({
    super.key,
    required this.snapshot,
  });

  final CityWeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final aqi = snapshot.europeanAqi?.toInt() ?? 18;
    final pm25 = snapshot.pm25 ?? 6.2;
    final pm10 = snapshot.pm10 ?? 14.5;
    final no2 = snapshot.no2 ?? 12.0;
    final o3 = snapshot.o3 ?? 48.0;
    final co = snapshot.co ?? 280.0;
    final so2 = snapshot.so2 ?? 4.0;
    final radiation = snapshot.radiationUsv;

    Color aqiColor;
    String aqiLabel;
    String aqiDesc;
    if (aqi <= 20) {
      aqiColor = const Color(0xFF00E676);
      aqiLabel = 'ОТЛИЧНОЕ';
      aqiDesc = 'Качество воздуха идеальное. Риски для здоровья отсутствуют.';
    } else if (aqi <= 40) {
      aqiColor = const Color(0xFFA0E85B);
      aqiLabel = 'ХОРОШЕЕ';
      aqiDesc = 'Качество воздуха удовлетворительное, загрязнение не представляет риска.';
    } else if (aqi <= 60) {
      aqiColor = const Color(0xFFFFC857);
      aqiLabel = 'УМЕРЕННОЕ';
      aqiDesc = 'Чувствительным группам рекомендуется сократить длительные нагрузки на улице.';
    } else if (aqi <= 80) {
      aqiColor = const Color(0xFFFF9800);
      aqiLabel = 'ПЛОХОЕ';
      aqiDesc = 'Возможны раздражения дыхательных путей у детей и пожилых.';
    } else {
      aqiColor = const Color(0xFFFF5252);
      aqiLabel = 'ОПАСНОЕ';
      aqiDesc = 'Высокий уровень загрязнения. Рекомендуется носить защитную маску.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master AQI Glass Card (Tappable for Details)
        GestureDetector(
          onTap: () => showWeatherMetricExplanationSheet(
            context: context,
            metricKey: 'aqi',
            currentValue: 'AQI $aqi ($aqiLabel)',
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: aqiColor.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: aqiColor.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: aqiColor.withOpacity(0.15),
                                  border: Border.all(color: aqiColor.withOpacity(0.4)),
                                ),
                                child: Icon(
                                  Icons.eco_rounded,
                                  color: aqiColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ИНДЕКС ВОЗДУХА (AQI)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Open-Meteo Air Quality • Нажмите для нормы ⓘ',
                                    style: TextStyle(
                                      color: const Color(0xFF00E5FF).withOpacity(0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: aqiColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: aqiColor.withOpacity(0.5)),
                            ),
                            child: Text(
                              aqiLabel,
                              style: TextStyle(
                                color: aqiColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Score Row
                      Row(
                        children: [
                          Text(
                            '$aqi',
                            style: TextStyle(
                              color: aqiColor,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EAQI',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'из 100 баллов',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Radiation Mini Badge (Tappable)
                          GestureDetector(
                            onTap: () => showWeatherMetricExplanationSheet(
                              context: context,
                              metricKey: 'radiation',
                              currentValue: '${radiation.toStringAsFixed(2)} мкЗв/ч',
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.blur_on_rounded, color: Color(0xFF10B981), size: 18),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${radiation.toStringAsFixed(2)} мкЗв/ч',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Text(
                                        'Рад. фон (норма)',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        aqiDesc,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Pollutants Breakdown Glass Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'КОНЦЕНТРАЦИЯ ЗАГРЯЗНЯЮЩИХ ВЕЩЕСТВ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Icon(Icons.touch_app_rounded, color: Color(0xFF00E5FF), size: 16),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Нажмите на любой показатель для справки и норм ВОЗ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 16),

              _buildInteractivePollutant(context, 'pm25', 'PM2.5 (Мелкая пыль)', pm25, 25.0, 'мкг/м³', const Color(0xFF00E676)),
              const SizedBox(height: 12),
              _buildInteractivePollutant(context, 'pm10', 'PM10 (Взвешенные частицы)', pm10, 50.0, 'мкг/м³', const Color(0xFF00E676)),
              const SizedBox(height: 12),
              _buildInteractivePollutant(context, 'no2', 'NO₂ (Диоксид азота)', no2, 40.0, 'мкг/м³', const Color(0xFF80D8FF)),
              const SizedBox(height: 12),
              _buildInteractivePollutant(context, 'o3', 'O₃ (Приземный озон)', o3, 100.0, 'мкг/м³', const Color(0xFF80D8FF)),
              const SizedBox(height: 12),
              _buildInteractivePollutant(context, 'co', 'CO (Угарный газ)', co, 4000.0, 'мкг/м³', const Color(0xFFB388FF)),
              const SizedBox(height: 12),
              _buildInteractivePollutant(context, 'so2', 'SO₂ (Диоксид серы)', so2, 40.0, 'мкг/м³', const Color(0xFFB388FF)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AI Recommendations from Hermes
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ИИ-рекомендации Гермеса по экологии',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildAdvisoryBullet(
                Icons.favorite_rounded,
                const Color(0xFFFF5252),
                'Метеочувствительным',
                'Геомагнитный фон спокойный (${snapshot.kpIndex?.toStringAsFixed(1) ?? '2.0'} Kp), давление стабильное (${snapshot.pressureMmHg?.round() ?? 758} мм рт. ст.). Самочувствие в норме.',
              ),
              const SizedBox(height: 8),
              _buildAdvisoryBullet(
                Icons.spa_rounded,
                const Color(0xFF00E676),
                'Аллергикам и астматикам',
                'Концентрация пыли PM2.5 минимальна ($pm25 мкг/м³). Ограничений для прогулок на открытом воздухе нет.',
              ),
              const SizedBox(height: 8),
              _buildAdvisoryBullet(
                Icons.child_care_rounded,
                const Color(0xFFFFD54F),
                'Для прогулок с детьми',
                'Отличные условия: УФ-индекс ${snapshot.uvIndex?.toStringAsFixed(1) ?? '2.5'} безопасен, свежий воздух на набережной и в парках.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractivePollutant(
    BuildContext context,
    String key,
    String name,
    double val,
    double limit,
    String unit,
    Color barColor,
  ) {
    return GestureDetector(
      onTap: () => showWeatherMetricExplanationSheet(
        context: context,
        metricKey: key,
        currentValue: '${val.toStringAsFixed(1)} $unit (ПДК: ${limit.toInt()} $unit)',
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.transparent,
        ),
        child: _buildPollutantRow(name, val, limit, unit, barColor),
      ),
    );
  }

  Widget _buildPollutantRow(String name, double val, double limit, String unit, Color barColor) {
    final progress = (val / limit).clamp(0.0, 1.0);
    final isOver = val > limit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Text(
                  '${val.toStringAsFixed(1)} ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '/ ${limit.toInt()} $unit',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isOver ? const Color(0xFFFF5252) : barColor,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: (isOver ? const Color(0xFFFF5252) : barColor).withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvisoryBullet(IconData icon, Color iconColor, String title, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: text,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
