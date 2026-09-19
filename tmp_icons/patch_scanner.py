# Add meter type selector + animated workers to scanner
p = r'C:\Soobshio_project\services\Frontend\lib\screens\smart_meter_scanner_screen.dart'
src = open(p, encoding='utf-8').read()

# 1) Mutable meter type
old_fields = '''  File? _imageFile;
  bool _isProcessing = false;'''
new_fields = '''  File? _imageFile;
  bool _isProcessing = false;
  late String _meterType = widget.meterType;'''
assert old_fields in src, 'fields anchor'
src = src.replace(old_fields, new_fields, 1)

# 2) Use state var
src = src.replace('switch (widget.meterType) {', 'switch (_meterType) {')
src = src.replace(
    "final key = 'last_reading_${widget.meterType}_${widget.address.hashCode}';",
    "final key = 'last_reading_${_meterType}_${widget.address.hashCode}';")

# 3) Selector + animation after address card
anchor = '''          const SizedBox(height: 16),

          // Область видоискателя / фото счетчика'''
replacement = '''          const SizedBox(height: 12),

          // ─── Селектор типа счетчика (ХВС / ГВС / Электричество) ───
          Row(
            children: [
              Expanded(child: _buildTypeChip('cold_water', '💧 ХВС', const Color(0xFF00E5FF))),
              const SizedBox(width: 8),
              Expanded(child: _buildTypeChip('hot_water', '🔥 ГВС', const Color(0xFFFF5252))),
              const SizedBox(width: 8),
              Expanded(child: _buildTypeChip('electricity', '⚡ Свет', const Color(0xFFFBBF24))),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Анимация: человечки кидают цифры на циферблат ───
          MeterWorkersAnimation(meterColor: _getMeterColor()),
          const SizedBox(height: 12),

          // Область видоискателя / фото счетчика'''
assert anchor in src, 'layout anchor'
src = src.replace(anchor, replacement, 1)

# 4) Add helper + animation classes
addition = r'''
  Widget _buildTypeChip(String type, String label, Color color) {
    final active = _meterType == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _meterType = type);
        _loadPreviousReading();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.22) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? color : Colors.white12, width: active ? 1.6 : 1),
          boxShadow: active
              ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10)]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? color : Colors.white60,
              fontSize: 12,
              fontWeight: active ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Анимация: два человечка кидают цифры (0-9) в «циферблат» счетчика.
class MeterWorkersAnimation extends StatefulWidget {
  final Color meterColor;
  const MeterWorkersAnimation({super.key, required this.meterColor});

  @override
  State<MeterWorkersAnimation> createState() => _MeterWorkersAnimationState();
}

class _MeterWorkersAnimationState extends State<MeterWorkersAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: const Size(double.infinity, 96),
          painter: _MeterWorkersPainter(
            progress: _c.value,
            color: widget.meterColor,
          ),
        ),
      ),
    );
  }
}

class _MeterWorkersPainter extends CustomPainter {
  final double progress;
  final Color color;
  _MeterWorkersPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final workerPaint = Paint()..color = const Color(0xFFE2E8F0);
    final workerPaint2 = Paint()..color = const Color(0xFF93A8C4);
    final dialPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    final dialBorder = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Циферблат по центру
    final dialCenter = Offset(w * 0.5, h * 0.52);
    final dialR = h * 0.34;
    canvas.drawCircle(dialCenter, dialR, dialPaint);
    canvas.drawCircle(dialCenter, dialR, dialBorder);

    // 5 окошек цифр, «щёлкающие» значения
    const slotCount = 5;
    final slotW = dialR * 0.62;
    final digits = [7, 4, 2, 9, 1];
    for (int i = 0; i < slotCount; i++) {
      final sx = dialCenter.dx - slotW * (slotCount / 2) + i * slotW;
      final rect = Rect.fromCenter(
          center: Offset(sx + slotW / 2, dialCenter.dy),
          width: slotW * 0.72,
          height: dialR * 0.62);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = const Color(0xFF1E293B),
      );
      final flip = (progress * 4 + i * 0.31) % 1.0;
      final digit = digits[(i + (flip * 10).toInt()) % 10];
      final tp = TextPainter(
        text: TextSpan(
            text: '$digit',
            style: TextStyle(
                color: color, fontSize: dialR * 0.44, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }

    // Человечки
    _drawWorker(canvas, Offset(w * 0.16, h * 0.75), workerPaint, progress, 1);
    _drawWorker(canvas, Offset(w * 0.84, h * 0.75), workerPaint2, progress, -1);

    // Летящие цифры по параболе от рук к циферблату
    for (int k = 0; k < 2; k++) {
      final phase = (progress + k * 0.5) % 1.0;
      if (phase > 0.82) continue;
      final from = k == 0
          ? Offset(w * 0.16 + 14, h * 0.55)
          : Offset(w * 0.84 - 14, h * 0.55);
      final to = Offset(dialCenter.dx + (k == 0 ? -slotW : slotW), dialCenter.dy);
      final t = phase / 0.82;
      final x = from.dx + (to.dx - from.dx) * t;
      final arc = -math.sin(t * math.pi) * h * 0.34;
      final y = from.dy + (to.dy - from.dy) * t + arc;
      final digitVal = ((phase * 10 + k * 3).toInt()) % 10;
      final tp = TextPainter(
        text: TextSpan(
            text: '$digitVal',
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((t * 2 - 1) * 0.4);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  void _drawWorker(Canvas canvas, Offset feet, Paint paint, double progress, int dir) {
    final h = 34.0;
    final head = Offset(feet.dx, feet.dy - h - 8);
    canvas.drawCircle(head, 8, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(feet.dx, feet.dy - h / 2 - 4), width: 16, height: h * 0.55),
        const Radius.circular(6),
      ),
      paint,
    );
    final legPaint = Paint()
      ..color = paint.color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(feet.translate(-6, 0), Offset(feet.dx - 6, feet.dy - h * 0.28), legPaint);
    canvas.drawLine(feet.translate(6, 0), Offset(feet.dx + 6, feet.dy - h * 0.28), legPaint);
    final swing = math.sin(progress * math.pi * 2) * 0.9;
    final shoulder = Offset(feet.dx, feet.dy - h * 0.78);
    final armLen = 16.0;
    final armAngle = -math.pi / 2 + dir * (0.5 + swing * 0.5);
    final hand = shoulder.translate(math.cos(armAngle) * armLen, math.sin(armAngle) * armLen);
    final armPaint = Paint()
      ..color = paint.color
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(shoulder, hand, armPaint);
  }

  @override
  bool shouldRepaint(_MeterWorkersPainter old) =>
      old.progress != progress || old.color != color;
}
'''
src = src + addition

if "import 'dart:math' as math;" not in src:
    src = src.replace("import 'dart:io';", "import 'dart:io';\nimport 'dart:math' as math;", 1)

open(p, 'w', encoding='utf-8', newline='').write(src)
print('scanner updated OK')
