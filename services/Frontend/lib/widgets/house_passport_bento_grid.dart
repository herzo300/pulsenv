// lib/widgets/house_passport_bento_grid.dart
//
// Унифицированный Bento-паспорт дома: Здоровье дома, характеристики, история,
// телеметрия, управляющая компания и автоматический мониторинг ИИ-Гермесом.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../services/house_intelligence_service.dart';
import '../services/hermes_house_sentinel_service.dart';

class HousePassportBentoGrid extends StatefulWidget {
  final String address;
  final bool isDark;

  const HousePassportBentoGrid({
    super.key,
    required this.address,
    this.isDark = true,
  });

  @override
  State<HousePassportBentoGrid> createState() => _HousePassportBentoGridState();
}

class _HousePassportBentoGridState extends State<HousePassportBentoGrid> {
  late Future<HouseIntelligenceModel> _intelFuture;

  @override
  void initState() {
    super.initState();
    _intelFuture = HouseIntelligenceService.instance.getHouseIntelligence(widget.address);
  }

  @override
  void didUpdateWidget(covariant HousePassportBentoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) {
      _intelFuture = HouseIntelligenceService.instance.getHouseIntelligence(widget.address);
    }
  }

  void _showFullHistoryModal(BuildContext context, HouseIntelligenceModel intel) {
    HapticFeedback.mediumImpact();
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_edu_rounded, color: Color(0xFFFFD54F), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ЛЕТОПИСЬ И ПАСПОРТ ДОМА',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            intel.address,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'УК: ${intel.ukName} · ${intel.ukPhone}',
                            style: TextStyle(
                              color: textColor.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Историческая справка
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_stories_rounded, color: Color(0xFF00E5FF), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'ИСТОРИЯ СТРОИТЕЛЬСТВА И РАЙОНА',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            intel.chronicle,
                            style: TextStyle(
                              color: textColor.withOpacity(0.9),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Застройщик: ${intel.builder}',
                                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Ввод: ${intel.commissioningDate}',
                                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Проведенные капитальные ремонты
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.checklist_rounded, color: Color(0xFF10B981), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'ВЫПОЛНЕННЫЕ КАПИТАЛЬНЫЕ РАБОТЫ',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...intel.completedRepairs.map((r) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${r['year']} г.',
                                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      r['work']?.toString() ?? '',
                                      style: TextStyle(color: textColor, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // План Югорского фонда капремонта
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.engineering_rounded, color: Color(0xFFFFD54F), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'ПЛАН КАПРЕМОНТА ДО 2030 ГОДА',
                                style: TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Следующий этап: ${intel.nextRepairYear} год',
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            intel.plannedWorks,
                            style: TextStyle(color: textColor.withOpacity(0.85), fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Оператор: ${intel.capexOperator} (Сбор взносов: ${intel.fundCollectedPct}%)',
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B).withOpacity(0.78) : Colors.white.withOpacity(0.92);
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return FutureBuilder<HouseIntelligenceModel>(
      future: _intelFuture,
      builder: (context, snapshot) {
        final intel = snapshot.data ?? HouseIntelligenceService.instance.buildDeterministicModel(widget.address);
        final healthScore = intel.healthScore;

        Color statusColor;
        String statusText;
        if (healthScore >= 85) {
          statusText = 'Отличное (Класс A/B+)';
          statusColor = const Color(0xFF10B981);
        } else if (healthScore >= 70) {
          statusText = 'Стабильное (Класс C)';
          statusColor = const Color(0xFF00E5FF);
        } else {
          statusText = 'Требует внимания (Класс D)';
          statusColor = const Color(0xFFF59E0B);
        }

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: statusColor.withOpacity(0.45), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.10),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── СЕКЦИЯ 1: ЗДОРОВЬЕ ДОМА И ИНДЕКС ───
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: healthScore / 100.0,
                            strokeWidth: 7,
                            backgroundColor: statusColor.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$healthScore%',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ИНДЕКС',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.favorite_rounded, color: Color(0xFFFF5252), size: 15),
                              const SizedBox(width: 5),
                              Text(
                                'ЗДОРОВЬЕ ДОМА',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${intel.series} • Износ: ${intel.wearPercentage}%',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              fontSize: 10,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: dividerColor),

              // ─── СЕКЦИЯ 2: ГОД ПОСТРОЙКИ, ХАРАКТЕРИСТИКИ И УК ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Год постройки и серия
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.foundation_rounded, color: Color(0xFFFFD54F), size: 14),
                              const SizedBox(width: 5),
                              Text(
                                'ГОД ПОСТРОЙКИ',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${intel.buildYear} год',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${intel.floors} эт. • ${intel.entrances} под. • ${intel.apartments} кв.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              fontSize: 9.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          GestureDetector(
                            onTap: () => _showFullHistoryModal(context, intel),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.history_edu_rounded, color: Color(0xFFFFD54F), size: 12),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Летопись дома ⓘ',
                                    style: TextStyle(
                                      color: const Color(0xFFFFD54F).withOpacity(0.9),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(width: 1, height: 56, color: dividerColor),
                    const SizedBox(width: 12),

                    // Управляющая компания
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.apartment_rounded, color: Color(0xFF00E5FF), size: 14),
                              const SizedBox(width: 5),
                              Text(
                                'УПРАВЛЯЮЩАЯ КОМПАНИЯ',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            intel.ukName,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final cleanPhone = intel.ukPhone.replaceAll(RegExp(r'[^\d+]'), '');
                              url_launcher.launchUrl(Uri.parse('tel:$cleanPhone'));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withOpacity(0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF00E5FF), size: 11),
                                  const SizedBox(width: 4),
                                  Text(
                                    intel.ukPhone,
                                    style: const TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: dividerColor),

              // ─── СЕКЦИЯ 3: ЖИВЫЕ ПОКАЗАТЕЛИ И ТЕЛЕМЕТРИЯ ДОМА ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricItem(Icons.whatshot_rounded, const Color(0xFFFF6D00), 'Отопление УТС', '+${intel.heatingSupplyC.round()}°C', isDark),
                    Container(width: 1, height: 24, color: dividerColor),
                    _buildMetricItem(Icons.water_drop_rounded, const Color(0xFF00E5FF), 'ГВС СанПиН', '+${intel.hotWaterTempC.round()}°C', isDark),
                    Container(width: 1, height: 24, color: dividerColor),
                    _buildMetricItem(Icons.bolt_rounded, const Color(0xFFFACC15), 'НЭСКО Энерго', '${intel.electricityVoltageV} В', isDark),
                  ],
                ),
              ),

              Divider(height: 1, color: dividerColor),

              // ─── СЕКЦИЯ 4: АКТИВАЦИЯ КРУГЛОСУТОЧНОГО МОНИТОРИНГА ГЕРМЕСОМ ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E5FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.psychology_rounded, color: Colors.black, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ИИ-ГЕРМЕС: МОНИТОРИНГ 24/7',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Контроль ЕДДС, отключений и сводок района',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF).withOpacity(0.18),
                        foregroundColor: const Color(0xFF00E5FF),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
                        ),
                      ),
                      onPressed: () async {
                        await HermesHouseSentinelService.instance.activateHouseMonitoring(widget.address, context: context);
                      },
                      child: const Text('Включить', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem(IconData icon, Color color, String label, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 8.5,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
