import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Микроклиматическая сетка датчиков по районам Нижневартовска.
class MicroclimateDistrictGrid extends StatefulWidget {
  final Function(String districtName)? onSelectDistrict;

  const MicroclimateDistrictGrid({
    super.key,
    this.onSelectDistrict,
  });

  @override
  State<MicroclimateDistrictGrid> createState() => _MicroclimateDistrictGridState();
}

class _MicroclimateDistrictGridState extends State<MicroclimateDistrictGrid> {
  int _selectedIdx = 0;

  final List<Map<String, dynamic>> _stations = [
    {
      'id': 'center',
      'name': 'Центр • Парк Победы',
      'temp': '-11°C',
      'wind': '3 м/с ЮЗ',
      'humidity': '78%',
      'comfort': 'Комфортно',
      'comfortColor': Color(0xFF10B981),
      'badge': 'Защищен от ветра',
      'icon': Icons.nature_people_rounded,
    },
    {
      'id': 'embankment',
      'name': 'Набережная р. Обь',
      'temp': '-13°C',
      'wind': '8 м/с Ю',
      'humidity': '88%',
      'comfort': 'Ветрено',
      'comfortColor': Color(0xFF38BDF8),
      'badge': 'Высокая влажность',
      'icon': Icons.water_rounded,
    },
    {
      'id': 'industrial',
      'name': 'Промзона • Индустриальная',
      'temp': '-14°C',
      'wind': '5 м/с З',
      'humidity': '74%',
      'comfort': 'Прохладно',
      'comfortColor': Color(0xFFF59E0B),
      'badge': 'Открытая местность',
      'icon': Icons.factory_rounded,
    },
    {
      'id': 'coastal',
      'name': 'Прибрежный • 16 мкр',
      'temp': '-12°C',
      'wind': '4 м/с ЮЗ',
      'humidity': '82%',
      'comfort': 'Умеренно',
      'comfortColor': Color(0xFF10B981),
      'badge': 'Новые кварталы',
      'icon': Icons.apartment_rounded,
    },
    {
      'id': 'old_vartovsk',
      'name': 'Старый Вартовск • Лопарева',
      'temp': '-15°C',
      'wind': '2 м/с Штиль',
      'humidity': '84%',
      'comfort': 'Морозно',
      'comfortColor': Color(0xFF818CF8),
      'badge': 'Частный сектор',
      'icon': Icons.cottage_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
                ),
                child: const Icon(Icons.sensors_rounded, color: Color(0xFF00E5FF), size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'МИКРОКЛИМАТ ПО РАЙОНАМ ГОРОДА',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '5 СТАНЦИЙ ОНЛАЙН',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _stations.length,
            itemBuilder: (ctx, idx) {
              final s = _stations[idx];
              final isSel = _selectedIdx == idx;
              final color = isSel ? const Color(0xFF00E5FF) : Colors.white24;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedIdx = idx);
                  widget.onSelectDistrict?.call(s['name'] as String);
                },
                child: Container(
                  width: 175,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF00E5FF).withOpacity(0.14)
                        : const Color(0xFF0F172A).withOpacity(0.75),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSel ? const Color(0xFF00E5FF) : Colors.white12,
                      width: isSel ? 1.5 : 1.0,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.2),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(s['icon'] as IconData, color: isSel ? const Color(0xFF00E5FF) : Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s['name'] as String,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            s['temp'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (s['comfortColor'] as Color).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s['comfort'] as String,
                              style: TextStyle(
                                color: s['comfortColor'] as Color,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '💨 ${s['wind']}',
                            style: const TextStyle(color: Colors.white60, fontSize: 9.5),
                          ),
                          Text(
                            '💧 ${s['humidity']}',
                            style: const TextStyle(color: Colors.white60, fontSize: 9.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
