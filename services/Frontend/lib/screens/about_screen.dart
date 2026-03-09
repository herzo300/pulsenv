import 'package:flutter/material.dart';
import 'dart:math' as math;

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  static const Color _bg = Color(0xFF030310);
  static const Color _card = Color(0xFF0D0D22);
  static const Color _accent = Color(0xFF00D9FF);
  static const Color _glow = Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ПУЛЬС ГОРОДА',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background digital atmosphere
          _buildBackgroundParticles(),
          
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 100),
                // Top Animation
                _buildAnimatedPulseHeader(),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInteractiveMonitor(),
                      const SizedBox(height: 32.0),
                      _buildSectionTitle('МИССИЯ ПРОЕКТА'),
                      _buildTextCard(
                        '«Пульс города» — это не просто приложение, а живой цифровой организм Нижневартовска. Мы объединяем данные и людей, превращая каждое сообщение жителя в импульс для развития городской среды.',
                      ),
                      const SizedBox(height: 32.0),
                      _buildSectionTitle('ИНТЕЛЛЕКТУАЛЬНЫЕ УЗЛЫ'),
                      _buildFeatureItem(Icons.radar_rounded, 'Радар обращений', 'Мгновенная фиксация инцидентов и автоматическое распределение по ведомствам.'),
                      _buildFeatureItem(Icons.query_stats_rounded, 'Индекс благополучия', 'Динамическая оценка состояния районов на основе реальных датасетов.'),
                      _buildFeatureItem(Icons.view_in_ar_rounded, '3D Моделирование', 'Визуализация города в объеме для точной навигации и анализа проблем.'),
                      const SizedBox(height: 32.0),
                      _buildSectionTitle('ЯДРО СИСТЕМЫ'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildTag('Neural Processing'),
                          _buildTag('Realtime Sync'),
                          _buildTag('Postgres Edge'),
                          _buildTag('Flutter Canvas'),
                        ],
                      ),
                      const SizedBox(height: 40.0),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ВЕРСИЯ 2.0.FINAL\nНИЖНЕВАРТОВСК · ЦИФРОВОЕ БУДУЩЕЕ',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40.0),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPulseHeader() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(
            painter: _PulseHeaderPainter(progress: _pulseController.value),
          ),
        );
      },
    );
  }

  Widget _buildInteractiveMonitor() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accent.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: _accent.withAlpha(20),
            blurRadius: 30,
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Grid Lines
            Positioned.fill(
              child: CustomPaint(painter: _MonitorGridPainter()),
            ),
            // Scanner Line
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return Positioned(
                  top: (_pulseController.value * 180) % 180,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, _accent.withAlpha(150), Colors.transparent],
                      ),
                    ),
                  ),
                );
              },
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ПУЛЬС ГОРОДА',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTIVE NODES: 2,152',
                      style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Row(
        children: [
          Container(width: 20, height: 1, color: _accent.withAlpha(100)),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14, height: 1.6, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accent.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withAlpha(40)),
            ),
            child: Icon(icon, color: _accent, size: 24.0),
          ),
          const SizedBox(width: 20.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6.0),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildBackgroundParticles() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.05,
        child: Image.network(
          'https://www.transparenttextures.com/patterns/carbon-fibre.png',
          repeat: ImageRepeat.repeat,
        ),
      ),
    );
  }
}

class _PulseHeaderPainter extends CustomPainter {
  final double progress;
  _PulseHeaderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D9FF).withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final glow = Paint()
      ..color = const Color(0xFF00D9FF).withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    final double midY = size.height / 2;
    
    for (double x = 0; x <= size.width; x += 3) {
      final double normX = x / size.width;
      final double phase = progress * 2 * math.pi - normX * 12;
      
      double h = math.sin(phase) * 15;
      // Add 'beating' effect
      h *= (1.0 + math.sin(progress * 4 * math.pi) * 0.5);
      
      if (x == 0) path.moveTo(x, midY + h);
      else path.lineTo(x, midY + h);
    }

    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MonitorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..strokeWidth = 0.5;

    for (double i = 0; i <= size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
