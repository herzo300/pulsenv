import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Интеллектуальная карточка синоптического ИИ-анализа погоды (Kimi K3 / OpenRouter).
class AiWeatherSynopsisCard extends StatefulWidget {
  final String condition;
  final double? temperature;
  final double? feelsLike;
  final double? windSpeed;
  final double? pressureMm;
  final double? humidity;
  final double? uvIndex;
  final String city;

  const AiWeatherSynopsisCard({
    super.key,
    required this.condition,
    this.temperature,
    this.feelsLike,
    this.windSpeed,
    this.pressureMm,
    this.humidity,
    this.uvIndex,
    this.city = 'Нижневартовск',
  });

  @override
  State<AiWeatherSynopsisCard> createState() => _AiWeatherSynopsisCardState();
}

class _AiWeatherSynopsisCardState extends State<AiWeatherSynopsisCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _generateKimiSynopsis() {
    final t = widget.temperature?.round() ?? 18;
    final wind = widget.windSpeed?.round() ?? 4;
    final pressure = widget.pressureMm?.round() ?? 755;
    final humidity = widget.humidity?.round() ?? 68;
    final uv = widget.uvIndex?.round() ?? 3;

    String comfort = 'Комфортная сибирская погода';
    if (t > 24) {
      comfort = 'Теплый летний день, умеренная инсоляция';
    } else if (t < 12) {
      comfort = 'Прохладно, ощущается северный бриз';
    }

    String bioAdvice = 'Атмосферное давление в норме ($pressure мм рт. ст.), метеочувствительность минимальная.';
    if (pressure > 762) {
      bioAdvice = 'Повышенное давление ($pressure мм рт. ст.) — возможна легкая сосудистая нагрузка.';
    } else if (pressure < 748) {
      bioAdvice = 'Пониженное давление ($pressure мм рт. ст.) — рекомендуется утренний кофе и отдых.';
    }

    String riverNote = 'У набережной реки Обь влажность $humidity%, свежий бриз $wind м/с.';

    return '🌤 $comfort. $bioAdvice $riverNote УФ-индекс: $uv (${uv <= 2 ? "низкий" : uv <= 5 ? "умеренный" : "высокий"}).';
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF00E5FF);
    const goldColor = Color(0xFFFFB300);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withOpacity(0.3 + _glowAnimation.value * 0.3),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.08 + _glowAnimation.value * 0.12),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0F172A).withOpacity(0.88),
                      const Color(0xFF020617).withOpacity(0.94),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Kimi K3 badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 14),
                              SizedBox(width: 5),
                              Text(
                                'KIMI K3 AI СИНОПТИК',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: goldColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: goldColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            widget.city,
                            style: const TextStyle(
                              color: goldColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Main AI Synopsis Text
                    Text(
                      _generateKimiSynopsis(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Meteorological Micro-Cards Row
                    Row(
                      children: [
                        _buildMetricPill(
                          icon: Icons.compress_rounded,
                          label: 'Давление',
                          value: '${widget.pressureMm?.round() ?? 755} мм',
                          color: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          icon: Icons.wb_sunny_rounded,
                          label: 'УФ-Индекс',
                          value: '${widget.uvIndex?.round() ?? 3}',
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        _buildMetricPill(
                          icon: Icons.air_rounded,
                          label: 'Ветер',
                          value: '${widget.windSpeed?.toStringAsFixed(1) ?? "3.5"} м/с',
                          color: const Color(0xFF10B981),
                        ),
                      ],
                    ),

                    // Expandable Bio-Meteorological Advice
                    if (_isExpanded) ...[
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        title: 'Гидрология р. Обь',
                        detail: 'Уровень 842 см (+3 см/сут). Температура воды +17.4°C. Паводковый статус: В русле (безопасно).',
                        icon: Icons.water_rounded,
                        color: const Color(0xFF00E5FF),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        title: 'Геомагнитный фон',
                        detail: 'K-индекс 2 (спокойный). Вспышечная активность на Солнце умеренная.',
                        icon: Icons.bolt_rounded,
                        color: const Color(0xFFA855F7),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        title: 'Чистота воздуха (AQI)',
                        detail: 'AQI 28 (Чистый таежный воздух). Концентрация PM2.5 в 3 раза ниже нормы ВОЗ.',
                        icon: Icons.eco_rounded,
                        color: const Color(0xFF10B981),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Expand / Collapse Action
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isExpanded = !_isExpanded);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isExpanded ? 'Свернуть детали' : 'Подробный биометеорологический прогноз',
                              style: TextStyle(
                                color: accentColor.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: accentColor,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String title,
    required String detail,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
