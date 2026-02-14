import 'package:flutter/material.dart';
import 'dart:math';

/// Заставка «Пульс города Нижневартовск»
/// Нейроморфизм + символы города (нефтяная вышка, кедр, река Обь, северное сияние)
/// Живой пульс, реагирующий на настроение города
class PulseSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final int totalComplaints;
  final int openComplaints;
  final int resolvedComplaints;

  const PulseSplashScreen({
    super.key,
    required this.onComplete,
    this.totalComplaints = 0,
    this.openComplaints = 0,
    this.resolvedComplaints = 0,
  });

  @override
  State<PulseSplashScreen> createState() => _PulseSplashScreenState();
}

class _PulseSplashScreenState extends State<PulseSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _progressCtrl;
  late AnimationController _auroraCtrl;

  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _progressAnim;

  String _statusText = 'Подключение...';
  double _progress = 0;

  // Настроение: good / ok / bad
  String get _mood {
    if (widget.totalComplaints == 0) return 'ok';
    final ratio = widget.resolvedComplaints / widget.totalComplaints;
    if (ratio >= 0.5) return 'good';
    if (ratio >= 0.3) return 'ok';
    return 'bad';
  }

  Color get _moodColor {
    switch (_mood) {
      case 'good': return const Color(0xFF22C55E);
      case 'bad': return const Color(0xFFEF4444);
      default: return const Color(0xFFEAB308);
    }
  }

  String get _moodEmoji {
    switch (_mood) {
      case 'good': return '😊';
      case 'bad': return '😟';
      default: return '😐';
    }
  }

  String get _moodText {
    final r = widget.totalComplaints > 0
        ? (widget.resolvedComplaints * 100 ~/ widget.totalComplaints)
        : 0;
    switch (_mood) {
      case 'good': return '$_moodEmoji Город спокоен — $r% решено';
      case 'bad': return '$_moodEmoji Повышенная активность — ${widget.openComplaints} открытых';
      default: return '$_moodEmoji Умеренная активность';
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _auroraCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.12).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));

    _fadeCtrl.forward();
    _startLoading();
  }

  Future<void> _startLoading() async {
    setState(() { _statusText = 'Подключение к Firebase...'; _progress = 0.1; });
    _progressCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() { _statusText = 'Загрузка жалоб...'; _progress = 0.4; });
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() { _statusText = 'Анализ настроения...'; _progress = 0.7; });
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() { _statusText = 'Карта готова!'; _progress = 1.0; });
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onComplete();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _fadeCtrl.dispose();
    _progressCtrl.dispose();
    _auroraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, child) => Opacity(
        opacity: _fadeAnim.value,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B0F1A),
          ),
          child: Stack(
            children: [
              // Северное сияние (aurora)
              _buildAurora(),
              // Контент
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEmblem(),
                    const SizedBox(height: 16),
                    _buildPulseRings(),
                    const SizedBox(height: 20),
                    _buildTitle(),
                    const SizedBox(height: 6),
                    _buildCity(),
                    const SizedBox(height: 14),
                    _buildMoodText(),
                    const SizedBox(height: 18),
                    _buildStats(),
                    const SizedBox(height: 24),
                    _buildProgressBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Северное сияние — анимированный градиент
  Widget _buildAurora() {
    return AnimatedBuilder(
      animation: _auroraCtrl,
      builder: (context, _) {
        final t = _auroraCtrl.value;
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _AuroraPainter(t, _moodColor),
        );
      },
    );
  }

  /// Эмблема города — нефтяная вышка + кедр + река
  Widget _buildEmblem() {
    return Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0B0F1A),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(6, 6), blurRadius: 12),
          BoxShadow(color: Colors.white.withOpacity(0.03), offset: const Offset(-6, -6), blurRadius: 12),
        ],
      ),
      child: CustomPaint(painter: _EmblemPainter(_moodColor)),
    );
  }

  /// Пульсирующие кольца
  Widget _buildPulseRings() {
    return SizedBox(
      width: 130, height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3 кольца
          for (int i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _ringCtrl,
              builder: (context, _) {
                final delay = i * 0.33;
                final t = ((_ringCtrl.value + delay) % 1.0);
                final scale = 0.5 + t * 0.7;
                final opacity = (1 - t).clamp(0.0, 0.6);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _moodColor.withOpacity(opacity), width: 2),
                    ),
                  ),
                );
              },
            ),
          // Ядро пульса
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_moodColor, _moodColor.withOpacity(0)]),
                  boxShadow: [BoxShadow(color: _moodColor.withOpacity(0.5), blurRadius: 24)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Пульс города',
      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white,
        shadows: [Shadow(color: Color(0x4D3B82F6), blurRadius: 16)]),
    );
  }

  Widget _buildCity() {
    return Text(
      'НИЖНЕВАРТОВСК',
      style: TextStyle(fontSize: 10, letterSpacing: 4, color: Colors.white.withOpacity(0.45),
        fontWeight: FontWeight.w600),
    );
  }

  Widget _buildMoodText() {
    return Text(
      _moodText,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _moodColor),
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statBox('${widget.totalComplaints}', 'проблем'),
        const SizedBox(width: 20),
        _statBox('${widget.openComplaints}', 'открыто'),
        const SizedBox(width: 20),
        _statBox('${widget.resolvedComplaints}', 'решено'),
      ],
    );
  }

  Widget _statBox(String num, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F1A),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(4, 4), blurRadius: 8),
              BoxShadow(color: Colors.white.withOpacity(0.03), offset: const Offset(-4, -4), blurRadius: 8),
            ],
          ),
          child: Text(num, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.45),
          letterSpacing: 1, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _progressAnim,
          builder: (context, _) => Container(
            width: 180, height: 3,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
              color: Colors.white.withOpacity(0.06)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_progressAnim.value * _progress).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(colors: [const Color(0xFF3B82F6), _moodColor]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(_statusText, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.4))),
      ],
    );
  }
}

/// Северное сияние
class _AuroraPainter extends CustomPainter {
  final double t;
  final Color accent;
  _AuroraPainter(this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      final phase = t * 2 * pi + i * pi / 3;
      final cx = size.width * (0.3 + 0.4 * sin(phase));
      final cy = size.height * 0.15 + i * 30;
      paint.shader = RadialGradient(
        colors: [accent.withOpacity(0.06 - i * 0.015), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 200));
      canvas.drawCircle(Offset(cx, cy), 200, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => true;
}

/// Эмблема: нефтяная вышка + кедр + река
class _EmblemPainter extends CustomPainter {
  final Color accent;
  _EmblemPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final paint = Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;

    // Нефтяная вышка (треугольник)
    final vPath = Path()
      ..moveTo(cx, cy - 22)
      ..lineTo(cx - 8, cy + 8)
      ..lineTo(cx + 8, cy + 8)
      ..close();
    canvas.drawPath(vPath, paint..style = PaintingStyle.stroke);
    // Перекладины
    canvas.drawLine(Offset(cx - 4, cy - 6), Offset(cx + 4, cy - 6), paint);
    canvas.drawLine(Offset(cx - 6, cy + 1), Offset(cx + 6, cy + 1), paint);

    // Кедр (слева)
    final treePaint = Paint()..color = accent.withOpacity(0.4)..style = PaintingStyle.fill;
    final tree = Path()
      ..moveTo(cx - 22, cy + 12)
      ..lineTo(cx - 18, cy - 8)
      ..lineTo(cx - 14, cy + 12)
      ..close();
    canvas.drawPath(tree, treePaint);

    // Река (внизу)
    final riverPaint = Paint()..color = accent.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final river = Path()
      ..moveTo(cx - 28, cy + 18)
      ..quadraticBezierTo(cx - 10, cy + 14, cx, cy + 18)
      ..quadraticBezierTo(cx + 10, cy + 22, cx + 28, cy + 18);
    canvas.drawPath(river, riverPaint);
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) => old.accent != accent;
}
