import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Голографическая 3D аудио-сфера ИИ-диспетчера «Гермес».
/// Реагирует на голос пользователя и воспроизведение ответа ИИ с динамическими частотными волнами.
class HermesVoiceHologramSphere extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final double size;
  final VoidCallback? onTap;

  const HermesVoiceHologramSphere({
    super.key,
    required this.isListening,
    required this.isSpeaking,
    this.size = 130.0,
    this.onTap,
  });

  @override
  State<HermesVoiceHologramSphere> createState() => _HermesVoiceHologramSphereState();
}

class _HermesVoiceHologramSphereState extends State<HermesVoiceHologramSphere>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _waveController;

  final math.Random _rng = math.Random(777);
  late final List<double> _waveformFreqs;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _waveformFreqs = List.generate(32, (i) => 0.2 + _rng.nextDouble() * 0.8);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Color _getPrimaryColor() {
    if (widget.isSpeaking) return const Color(0xFF00E5FF); // Неоновый лазурный (ИИ говорит)
    if (widget.isListening) return const Color(0xFF10B981); // Мятно-зеленый (Слушает)
    return const Color(0xFF818CF8); // Спокойный фиолетовый (Ожидание)
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final primaryColor = _getPrimaryColor();

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size + 30,
            height: size + 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Внешняя светящаяся аура
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final p = _pulseController.value;
                    final multiplier = (widget.isListening || widget.isSpeaking) ? 1.5 : 1.0;
                    return Container(
                      width: size * (0.95 + 0.15 * p * multiplier),
                      height: size * (0.95 + 0.15 * p * multiplier),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity((0.25 + 0.2 * p) * multiplier),
                            blurRadius: 36 * multiplier,
                            spreadRadius: 6 * p,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // 2. Голографический рендерер аудио-сферы
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _rotationController,
                    _pulseController,
                    _waveController,
                  ]),
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(size, size),
                      painter: _HologramSpherePainter(
                        rotProgress: _rotationController.value,
                        pulseProgress: _pulseController.value,
                        waveProgress: _waveController.value,
                        color: primaryColor,
                        isListening: widget.isListening,
                        isSpeaking: widget.isSpeaking,
                        freqs: _waveformFreqs,
                      ),
                    );
                  },
                ),

                // 3. Центральная иконка микрофона / звука
                Icon(
                  widget.isListening
                      ? Icons.mic_rounded
                      : (widget.isSpeaking ? Icons.graphic_eq_rounded : Icons.auto_awesome_rounded),
                  color: Colors.white,
                  size: size * 0.28,
                  shadows: [
                    Shadow(color: primaryColor, blurRadius: 16),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.4)),
            ),
            child: Text(
              widget.isListening
                  ? 'СЛУШАЮ ВАС...'
                  : (widget.isSpeaking ? 'ГЕРМЕС ОТВЕЧАЕТ' : 'ГОЛОСОВОЙ ИИ ГОТОВ'),
              style: TextStyle(
                color: primaryColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HologramSpherePainter extends CustomPainter {
  final double rotProgress;
  final double pulseProgress;
  final double waveProgress;
  final Color color;
  final bool isListening;
  final bool isSpeaking;
  final List<double> freqs;

  _HologramSpherePainter({
    required this.rotProgress,
    required this.pulseProgress,
    required this.waveProgress,
    required this.color,
    required this.isListening,
    required this.isSpeaking,
    required this.freqs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Внутреннее голографическое ядро
    final coreGradient = RadialGradient(
      colors: [
        color.withOpacity(0.6),
        color.withOpacity(0.2),
        Colors.transparent,
      ],
      stops: const [0.0, 0.65, 1.0],
    );
    canvas.drawCircle(
      center,
      radius * 0.85,
      Paint()..shader = coreGradient.createShader(Rect.fromCircle(center: center, radius: radius * 0.85)),
    );

    // Вращающиеся меридианы и параллели сферы
    final ringPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 3; i++) {
      final tilt = (i * math.pi / 3) + (rotProgress * math.pi * 2);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(tilt);
      canvas.scale(1.0, 0.45 + (0.1 * math.sin(rotProgress * math.pi * 2 + i)));
      canvas.drawCircle(Offset.zero, radius * 0.9, ringPaint);
      canvas.restore();
    }

    // Частотные лучи / звуковые волны по экватору
    final isActive = isListening || isSpeaking;
    final waveCount = freqs.length;
    final wavePaint = Paint()
      ..color = Colors.white.withOpacity(isActive ? 0.85 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < waveCount; i++) {
      final angle = (i / waveCount) * math.pi * 2 + (rotProgress * math.pi);
      final freq = freqs[i];
      final waveAmp = isActive
          ? (freq * 14.0 * math.sin(waveProgress * math.pi * 2 + i))
          : (freq * 3.0);

      final r1 = radius * 0.88;
      final r2 = radius * 0.88 + waveAmp;

      final p1 = center + Offset(math.cos(angle) * r1, math.sin(angle) * r1);
      final p2 = center + Offset(math.cos(angle) * r2, math.sin(angle) * r2);

      canvas.drawLine(p1, p2, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HologramSpherePainter oldDelegate) => true;
}
