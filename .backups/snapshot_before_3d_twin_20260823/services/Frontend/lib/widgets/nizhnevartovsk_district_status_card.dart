// lib/widgets/nizhnevartovsk_district_status_card.dart
//
// Интерактивная сводка микрорайонов и коммунального статуса Нижневартовска.
//
// Включает:
//   • Микрорайоны 1–16, Прибрежный, Старый Вартовск, РЭБ Флота, 2П-2;
//   • Телеметрия: давление теплосетей, температура подачи, онлайн жителей, аварии.

import 'package:flutter/material.dart';

class NizhnevartovskDistrictStatusCard extends StatefulWidget {
  const NizhnevartovskDistrictStatusCard({super.key});

  @override
  State<NizhnevartovskDistrictStatusCard> createState() => _NizhnevartovskDistrictStatusCardState();
}

class _NizhnevartovskDistrictStatusCardState extends State<NizhnevartovskDistrictStatusCard> {
  int _selectedDistrictIndex = 0;

  final List<Map<String, dynamic>> _districts = [
    {
      'name': '1–5 МКР (Центр)',
      'online': 1420,
      'heatTemp': '+74°C',
      'heatPressure': '8.6 атм',
      'status': 'Стабильно',
      'incidents': 0,
    },
    {
      'name': '6–10 МКР',
      'online': 1850,
      'heatTemp': '+72°C',
      'heatPressure': '8.4 атм',
      'status': 'Стабильно',
      'incidents': 0,
    },
    {
      'name': '11–16 МКР (Восточный)',
      'online': 2130,
      'heatTemp': '+73°C',
      'heatPressure': '8.5 атм',
      'status': 'Стабильно',
      'incidents': 0,
    },
    {
      'name': 'Прибрежный (Набережная)',
      'online': 980,
      'heatTemp': '+75°C',
      'heatPressure': '8.7 атм',
      'status': 'Стабильно',
      'incidents': 0,
    },
    {
      'name': 'Старый Вартовск',
      'online': 760,
      'heatTemp': '+71°C',
      'heatPressure': '8.2 атм',
      'status': 'Стабильно',
      'incidents': 0,
    },
    {
      'name': 'РЭБ Флота / 2П-2',
      'online': 410,
      'heatTemp': '+70°C',
      'heatPressure': '8.1 атм',
      'status': 'Стабильно',
      'incidents': 0,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final d = _districts[_selectedDistrictIndex];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_city_rounded, color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'МИКРОРАЙОНЫ ВАРТОВСКА',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'ЖКХ и коммунальная телеметрия',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Сети в норме',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Горизонтальный скролл микрорайонов
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _districts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _districts[index];
                final isSel = index == _selectedDistrictIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDistrictIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF00E5FF).withOpacity(0.25) : Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSel ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.1),
                        width: isSel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      item['name'],
                      style: TextStyle(
                        color: isSel ? Colors.white : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Сетка показателей выбранного микрорайона
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _buildDistrictMetric(
                Icons.people_alt_rounded,
                'Жителей онлайн',
                '${d['online']}',
                const Color(0xFF00E5FF),
              ),
              _buildDistrictMetric(
                Icons.thermostat_rounded,
                'Теплоноситель',
                d['heatTemp'],
                const Color(0xFFF59E0B),
              ),
              _buildDistrictMetric(
                Icons.speed_rounded,
                'Давление ГВС',
                d['heatPressure'],
                const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictMetric(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 8.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
