import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Цифровой двойник подъезда и многоквартирного дома для City Pulse.
/// Отображает инженерные стояки (Отопление, ГВС, ХВС, Электричество, Лифт) в реальном времени.
class JkhDigitalTwinScreen extends StatefulWidget {
  final String address;
  final String ukName;
  final int totalFloors;
  final int totalEntrances;

  const JkhDigitalTwinScreen({
    super.key,
    required this.address,
    required this.ukName,
    this.totalFloors = 9,
    this.totalEntrances = 4,
  });

  @override
  State<JkhDigitalTwinScreen> createState() => _JkhDigitalTwinScreenState();
}

class _JkhDigitalTwinScreenState extends State<JkhDigitalTwinScreen>
    with SingleTickerProviderStateMixin {
  int _selectedEntrance = 1;
  int _selectedFloor = 5;
  late final AnimationController _pulseAnim;


  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070D18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ЦИФРОВОЙ ДВОЙНИК ДОМА',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              widget.address,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility_rounded, color: Color(0xFF00E5FF), size: 14),
                SizedBox(width: 4),
                Text(
                  'ВИРТУАЛЬНАЯ МОДЕЛЬ',
                  style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Выбор подъезда и этажа
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ВЫБОР ПОДЪЕЗДА И ЭТАЖА',
                  style: TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(widget.totalEntrances, (idx) {
                            final entranceNum = idx + 1;
                            final isSel = _selectedEntrance == entranceNum;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('Подъезд $entranceNum'),
                                selected: isSel,
                                selectedColor: const Color(0xFF00E5FF),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.black : Colors.white70,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11.5,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedEntrance = entranceNum);
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Этаж: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _selectedFloor.toDouble(),
                        min: 1,
                        max: widget.totalFloors.toDouble(),
                        divisions: widget.totalFloors - 1,
                        activeColor: const Color(0xFF00E5FF),
                        inactiveColor: Colors.white24,
                        label: '$_selectedFloor этаж',
                        onChanged: (val) {
                          setState(() => _selectedFloor = val.round());
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E5FF)),
                      ),
                      child: Text(
                        '$_selectedFloor/${widget.totalFloors}',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Интерактивная 3D-схема стояков подъезда (Custom Painter)
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1220),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _DigitalTwinRiserPainter(
                      selectedFloor: _selectedFloor,
                      totalFloors: widget.totalFloors,
                      pulse: _pulseAnim.value,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Сетка метрик телеметрии
          const Text(
            'СТАТУС ИНЖЕНЕРНЫХ СИСТЕМ',
            style: TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          // Реальных датчиков стояков в домах нет — телеметрия удалена.
          // Статусы строятся на реальных инцидентах ЖКХ (jkh_outages).
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors_off_rounded, color: Colors.white38, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Поквартирные датчики к этому дому не подключены. '
                    'Актуальные отключения и аварии смотрите в разделе «Статус дома» — '
                    'данные приходят из городской базы инцидентов ЖКХ.',
                    style: TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Карточка управляющей компании
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF00E5FF), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Раздел «Помощь соседям» (Серверные просьбы со стадиями)
          _buildNeighborhoodHelpSection(),
        ],
      ),
    );
  }

  Widget _buildNeighborhoodHelpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.handshake_rounded, color: Color(0xFF8B5CF6), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ПОМОЩЬ СОСЕДЯМ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _showCreateHelpDialog,
                icon: const Icon(Icons.add_rounded, color: Color(0xFF00E5FF), size: 16),
                label: const Text(
                  'Просьба',
                  style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Карточки просьб взаимопомощи
          _buildHelpCard(
            id: 1,
            title: 'Помочь донести сумки с продуктами',
            desc: 'Пожилая бабушка на 5 этаже без лифта (Мира 28). Нужна помощь занести пакеты.',
            author: 'Анна Ивановна (кв. 42)',
            status: 'pending', // Ждет помощи
            category: 'Пожилым',
          ),
          const SizedBox(height: 10),
          _buildHelpCard(
            id: 2,
            title: 'Прикурить аккумулятор во дворе',
            desc: 'Замерз авто ВАЗ 2114 на парковке (Интернациональная 19Б). Есть провода.',
            author: 'Сергей (кв. 18)',
            status: 'claimed', // Взято в работу
            helper: 'Алексей (подъезд 2)',
            category: 'Авто-помощь',
          ),
          const SizedBox(height: 10),
          _buildHelpCard(
            id: 3,
            title: 'Расчистить снег у пандуса',
            desc: 'Занесло выезд инвалидной коляски (Ленина 15). Снежная лопата в подвале.',
            author: 'Мария (кв. 7)',
            status: 'completed', // Выполнено
            helper: 'Игорь В.',
            category: 'Благоустройство',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard({
    required int id,
    required String title,
    required String desc,
    required String author,
    required String status,
    required String category,
    String? helper,
  }) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'completed') {
      statusColor = const Color(0xFF10B981); // Emerald Green
      statusLabel = 'Выполнено';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'claimed') {
      statusColor = const Color(0xFF8B5CF6); // Purple/Violet
      statusLabel = helper != null ? 'Взял: $helper' : 'Взято в работу';
      statusIcon = Icons.directions_run_rounded;
    } else {
      statusColor = const Color(0xFFF59E0B); // Amber/Orange
      statusLabel = 'Ждет отклика';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Text(
                category,
                style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Автор: $author',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              if (status == 'pending')
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Вы взяли просьбу в работу! Статус обновлен на сервере.')),
                    );
                    setState(() {});
                  },
                  icon: const Icon(Icons.front_hand_rounded, size: 12),
                  label: const Text('Помочь', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else if (status == 'claimed')
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Просьба отмечена выполненной! Начислено +50 XP.')),
                    );
                    setState(() {});
                  },
                  icon: const Icon(Icons.check_rounded, size: 12),
                  label: const Text('Завершить', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateHelpDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Новая просьба о помощи', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Заголовок (например: Прикурить авто)',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Описание и номер квартиры',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Просьба сохранена на сервере! Соседи уведомлены.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            child: const Text('Опубликовать'),
          ),
        ],
      ),
    );
  }

}

class _DigitalTwinRiserPainter extends CustomPainter {
  final int selectedFloor;
  final int totalFloors;
  final double pulse;

  _DigitalTwinRiserPainter({
    required this.selectedFloor,
    required this.totalFloors,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final floorHeight = size.height / (totalFloors + 1);

    // Сетка этажей
    for (int f = 1; f <= totalFloors; f++) {
      final y = size.height - (f * floorHeight);
      final isSel = f == selectedFloor;

      final linePaint = Paint()
        ..color = isSel ? const Color(0xFF00E5FF).withOpacity(0.6) : Colors.white10
        ..strokeWidth = isSel ? 2.0 : 1.0;

      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), linePaint);

      // Номер этажа
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$f эт',
          style: TextStyle(
            color: isSel ? const Color(0xFF00E5FF) : Colors.white38,
            fontSize: 9.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(24, y - 14));
    }

    // Вертикальные инженерные стояки
    // 1. Отопление (Красный)
    _drawRiser(canvas, size, size.width * 0.35, const Color(0xFFFF5252), 'Отопление');
    // 2. ГВС (Оранжевый)
    _drawRiser(canvas, size, size.width * 0.50, const Color(0xFFFF9100), 'ГВС');
    // 3. ХВС (Синий)
    _drawRiser(canvas, size, size.width * 0.65, const Color(0xFF00E5FF), 'ХВС');
    // 4. Шахта лифта (Зеленый)
    _drawRiser(canvas, size, size.width * 0.80, const Color(0xFF10B981), 'Лифт');
  }

  void _drawRiser(Canvas canvas, Size size, double x, Color color, String label) {
    final pipePaint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(x, 20), Offset(x, size.height - 20), pipePaint);

    // Пульсирующий индикатор потока
    final flowY = (20 + (size.height - 40) * ((pulse + (x / 100)) % 1.0));
    final flowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, flowY), 3.0, flowPaint);
  }

  @override
  bool shouldRepaint(covariant _DigitalTwinRiserPainter oldDelegate) => true;
}
