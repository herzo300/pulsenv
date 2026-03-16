import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _adminTapWindow = Duration(seconds: 4);
  static const int _adminTapTarget = 10;

  static const Color _bg = Color(0xFF030310);
  static const Color _card = Color(0xFF0D0D22);
  static const Color _accent = Color(0xFF00D9FF);

  late AnimationController _pulseController;
  Timer? _adminTapResetTimer;
  int _adminTapCount = 0;

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
    _adminTapResetTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminTap() async {
    _adminTapResetTimer?.cancel();
    _adminTapCount += 1;

    if (_adminTapCount >= _adminTapTarget) {
      _adminTapCount = 0;
      final twoFactorCode = await _promptTwoFactorCode();
      if (!mounted || twoFactorCode == null || twoFactorCode.isEmpty) {
        return;
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(
            initialTwoFactorCode: twoFactorCode,
          ),
        ),
      );
      return;
    }

    _adminTapResetTimer = Timer(_adminTapWindow, () {
      _adminTapCount = 0;
    });
  }

  Future<String?> _promptTwoFactorCode() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B1324),
          title: const Text(
            '2FA код',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: codeController,
            autofocus: true,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Введите код',
              hintStyle: TextStyle(color: Colors.white38),
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(codeController.text.trim()),
              child: const Text('Войти'),
            ),
          ],
        );
      },
    );
    codeController.dispose();
    return code?.trim();
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
          _buildBackgroundParticles(),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 100),
                _buildAnimatedPulseHeader(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInteractiveMonitor(),
                      const SizedBox(height: 32),
                      _buildSectionTitle('МИССИЯ ПРОЕКТА'),
                      _buildTextCard(
                        '«Пульс города» объединяет жителей, городские сервисы и карту инцидентов в одном мобильном контуре. Приложение помогает быстро зафиксировать проблему, увидеть ситуацию в районе и сократить путь от сигнала до реакции.',
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('КЛЮЧЕВЫЕ ВОЗМОЖНОСТИ'),
                      _buildFeatureItem(
                        Icons.radar_rounded,
                        'Радар обращений',
                        'Фиксация инцидентов, маршрутизация по категориям и единая точка сбора городских сигналов.',
                      ),
                      _buildFeatureItem(
                        Icons.query_stats_rounded,
                        'Аналитика в реальном времени',
                        'Сводные данные, карта активности, визуальные сценарии и мониторинг пользовательского трафика.',
                      ),
                      _buildFeatureItem(
                        Icons.view_in_ar_rounded,
                        '3D-моделирование и камеры',
                        'Пространственная навигация по городу, просмотр видеопотоков и быстрый переход к проблемной точке.',
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('ТЕХНОЛОГИЧЕСКОЕ ЯДРО'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _AboutTag(label: 'Realtime Sync'),
                          _AboutTag(label: '3D Tiles'),
                          _AboutTag(label: 'Flutter Canvas'),
                          _AboutTag(label: 'FastAPI Metrics'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('ПРАВИЛА И КОНФИДЕНЦИАЛЬНОСТЬ'),
                      _buildFeatureItem(
                        Icons.privacy_tip_rounded,
                        'Данные и согласие',
                        'Используя приложение, вы соглашаетесь с тем, что часть данных обрабатывается на защищенных международных серверах (распределенная инфраструктура). Данные не передаются третьим лицам без вашего согласия.',
                      ),
                      _buildFeatureItem(
                        Icons.admin_panel_settings_rounded,
                        'Режим администратора',
                        'Скрытый режим для авторизованных сотрудников позволяет управлять геопространственными данными, включая скрытые 3D-модели.',
                      ),
                      const SizedBox(height: 40),
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => unawaited(_handleAdminTap()),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Column(
                              children: [
                                _FooterBeacon(),
                                SizedBox(height: 8),
                                Text(
                                  'ВЕРСИЯ 2.1.ADMIN READY\nНИЖНЕВАРТОВСК · ЦИФРОВОЙ КОНТУР',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
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
            Positioned.fill(
              child: CustomPaint(painter: _MonitorGridPainter()),
            ),
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
                        colors: [
                          Colors.transparent,
                          _accent.withAlpha(150),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ПУЛЬС ГОРОДА',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                  SizedBox(height: 8),
                  _MonitorBadge(),
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
        style: TextStyle(
          color: Colors.white.withAlpha(200),
          fontSize: 14,
          height: 1.6,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String desc,
  ) {
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
              border: Border.all(
                color: _accent.withAlpha(40),
              ),
            ),
            child: Icon(icon, color: _accent, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _AboutTag extends StatelessWidget {
  const _AboutTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FooterBeacon extends StatelessWidget {
  const _FooterBeacon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFF00D9FF),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MonitorBadge extends StatelessWidget {
  const _MonitorBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00D9FF).withAlpha(40),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'CITY SIGNAL ONLINE',
        style: TextStyle(
          color: Color(0xFF00D9FF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PulseHeaderPainter extends CustomPainter {
  const _PulseHeaderPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D9FF).withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final glow = Paint()
      ..color = const Color(0xFF00D9FF).withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    final midY = size.height / 2;

    for (double x = 0; x <= size.width; x += 3) {
      final normX = x / size.width;
      final phase = progress * 2 * math.pi - normX * 12;
      var h = math.sin(phase) * 15;
      h *= 1 + math.sin(progress * 4 * math.pi) * 0.5;

      if (x == 0) {
        path.moveTo(x, midY + h);
      } else {
        path.lineTo(x, midY + h);
      }
    }

    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseHeaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
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

