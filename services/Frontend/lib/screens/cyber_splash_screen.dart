import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/sound_service.dart';
import 'map_screen.dart';

/// Splash screen "Cyber Pulse".
/// Keeps the cyberpunk entry point, but aligns typography and layer language
/// with the gravity splash so the whole splash line feels related.
class CyberSplashScreen extends StatefulWidget {
  const CyberSplashScreen({super.key});

  @override
  State<CyberSplashScreen> createState() => _CyberSplashScreenState();
}

class _CyberSplashScreenState extends State<CyberSplashScreen>
    with TickerProviderStateMixin {
  static const Color _deep = Color(0xFF020814);
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _teal = Color(0xFF1DE9B6);
  static const Color _blue = Color(0xFF448AFF);
  static const Color _violet = Color(0xFF7C4DFF);

  late final AnimationController _pulseController;
  late final AnimationController _scanController;
  late final AnimationController _fadeController;
  late final Ticker _ticker;

  final List<_RingData> _rings = [];
  final math.Random _rng = math.Random();
  double _time = 0;
  bool _ready = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.forward && _ready && !_exiting) {
          SoundService().playPulse();
        }
      })
      ..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
        _updateRings(_time);
      });
    })
      ..start();

    _initRings();
    _simulateLoading();
    SoundService().playSplashDesign('cyber');
  }

  void _initRings() {
    const widths = [1.1, 1.4, 1.8, 2.2, 2.6];
    for (int i = 0; i < 5; i++) {
      _rings.add(
        _RingData(
          baseRadius: 72.0 + i * 34.0,
          speed: (_rng.nextDouble() - 0.5) * 1.7,
          phase: _rng.nextDouble() * math.pi * 2,
          color: _ringColor(i),
          segments: 9 + _rng.nextInt(8),
          width: widths[i],
        ),
      );
    }
  }

  Color _ringColor(int index) {
    const colors = [_cyan, _teal, _blue, _violet, _cyan];
    return colors[index % colors.length];
  }

  void _updateRings(double time) {
    for (final ring in _rings) {
      ring.rotation = time * ring.speed + ring.phase;
    }
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(milliseconds: 3100));
    if (!mounted) return;
    setState(() => _ready = true);
    _fadeController.forward();
  }

  void _onEnter() {
    if (!_ready || _exiting) return;
    HapticFeedback.heavyImpact();
    setState(() => _exiting = true);
    SoundService().stopSplash();

    Future.delayed(const Duration(milliseconds: 560), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MapScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 620),
        ),
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _fadeController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _deep,
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 520),
        opacity: _exiting ? 0.0 : 1.0,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CyberBackdropPainter(time: _time),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CyberParticleFieldPainter(time: _time),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CyberPulsePainter(rings: _rings, time: _time),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CyberGridPainter(time: _time),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, _) {
                final scanY = _scanController.value * (size.height + 120) - 60;
                return Positioned(
                  left: 0,
                  right: 0,
                  top: scanY,
                  child: _buildScanLine(size.width),
                );
              },
            ),
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = math.min(
                      392.0,
                      math.max(296.0, constraints.maxWidth - 32),
                    );
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 40,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: cardWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 8),
                                _buildTopChip(),
                                const SizedBox(height: 26),
                                _buildWordmark(),
                                const SizedBox(height: 18),
                                Text(
                                  'Киберслой собирает радары, камеры и '
                                  'городские сигналы в единый сетевой импульс.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withAlpha(176),
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'PULSE · NIZHNEVARTOVSK',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withAlpha(86),
                                    fontSize: 11,
                                    letterSpacing: 3.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                _buildCorePanel(),
                                const SizedBox(height: 28),
                                _buildStatusPanel(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopChip() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
      child: _CyberGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _ready ? _teal : _cyan,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_ready ? _teal : _cyan).withAlpha(140),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _ready ? 'CYBER LINK STABLE' : 'CYBER LINK CALIBRATING',
              style: GoogleFonts.orbitron(
                color: Colors.white.withAlpha(214),
                fontSize: 11,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    return Column(
      children: [
        Text(
          'КИБЕР СЛОЙ',
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            color: _cyan.withAlpha(166),
            fontSize: 12,
            letterSpacing: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_cyan, _teal, _blue, _violet],
            stops: [0.0, 0.28, 0.68, 1.0],
          ).createShader(bounds),
          child: Text(
            'ПУЛЬС СЕТИ',
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: 5.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorePanel() {
    return _CyberGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: _cyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NETWORK CORE',
                  style: GoogleFonts.orbitron(
                    color: Colors.white.withAlpha(208),
                    fontSize: 12,
                    letterSpacing: 2.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _ready ? 'LIVE' : 'BOOT',
                style: GoogleFonts.inter(
                  color: (_ready ? _teal : _cyan).withAlpha(220),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildCoreTrigger(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TelemetryPill(
                  label: 'RINGS',
                  value: _rings.length.toString(),
                  color: _cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TelemetryPill(
                  label: 'SYNC',
                  value: '${68 + (_pulseController.value * 31).round()}%',
                  color: _teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TelemetryPill(
                  label: 'MODE',
                  value: _ready ? 'ARMED' : 'SCAN',
                  color: _blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _ready
                ? 'Коснитесь ядра, чтобы открыть карту без разрыва сцены.'
                : 'Система собирает каналы, камеры и динамический слой данных.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(156),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreTrigger() {
    return GestureDetector(
      onTap: _onEnter,
      child: MouseRegion(
        cursor: _ready ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final heartbeat =
                math.sin(_pulseController.value * math.pi * 2) * 0.08;
            final scale = _ready ? 1.0 + heartbeat : 0.88;
            final glowAlpha = _ready ? 150 + (heartbeat * 220).round() : 60;

            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 142,
                height: 142,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _cyan.withAlpha(_ready ? 176 : 78),
                          width: 1.4,
                        ),
                        gradient: RadialGradient(
                          colors: [
                            _cyan.withAlpha(_ready ? 28 : 10),
                            _violet.withAlpha(_ready ? 22 : 8),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _cyan.withAlpha(glowAlpha.clamp(0, 255)),
                            blurRadius: _ready ? 36 : 18,
                            spreadRadius: _ready ? 4 : 1,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withAlpha(_ready ? 186 : 88),
                          width: 1.1,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _cyan.withAlpha(_ready ? 90 : 30),
                            _blue.withAlpha(_ready ? 50 : 16),
                            _deep.withAlpha(220),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _ready
                              ? const [_cyan, _teal, _blue]
                              : [
                                  _cyan.withAlpha(140),
                                  _blue.withAlpha(110),
                                  _deep,
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withAlpha(_ready ? 42 : 16),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _ready
                            ? Icons.power_settings_new_rounded
                            : Icons.hourglass_bottom_rounded,
                        color: const Color(0xFF021321),
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _ready
          ? _CyberGlassPanel(
              key: const ValueKey('ready'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Text(
                    'АКТИВИРОВАТЬ СИСТЕМУ',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 3.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Карта и 3D-сцена готовы к входу.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(164),
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _CyberGlassPanel(
              key: const ValueKey('loading'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Text(
                    'КАЛИБРОВКА СЕНСОРОВ',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(
                      color: _cyan.withAlpha(220),
                      fontSize: 13,
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: 0.42 + (_pulseController.value * 0.44),
                      backgroundColor: Colors.white.withAlpha(18),
                      valueColor: const AlwaysStoppedAnimation<Color>(_cyan),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Собираем слой города и стабилизируем сетевой контур.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(150),
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildScanLine(double width) {
    return IgnorePointer(
      child: SizedBox(
        height: 46,
        width: width,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 16,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _cyan.withAlpha(20),
                      _teal.withAlpha(36),
                      _cyan.withAlpha(20),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 22,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _cyan.withAlpha(120),
                      Colors.white.withAlpha(160),
                      _cyan.withAlpha(120),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withAlpha(84),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CyberGlassPanel extends StatelessWidget {
  const _CyberGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(22));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xAA00E5FF),
            const Color(0x447C4DFF),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withAlpha(24),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xB30A1220),
                borderRadius: borderRadius,
              ),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TelemetryPill extends StatelessWidget {
  const _TelemetryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(54)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.orbitron(
              color: color.withAlpha(196),
              fontSize: 9,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(230),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingData {
  _RingData({
    required this.baseRadius,
    required this.speed,
    required this.phase,
    required this.color,
    required this.segments,
    required this.width,
  });

  final double baseRadius;
  final double speed;
  final double phase;
  final Color color;
  final int segments;
  final double width;
  double rotation = 0;
}

class _CyberBackdropPainter extends CustomPainter {
  const _CyberBackdropPainter({required this.time});

  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);

    final backgroundPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.15, 0),
        Offset(size.width, size.height),
        const [
          Color(0xFF020814),
          Color(0xFF081220),
          Color(0xFF040A14),
        ],
      );
    canvas.drawRect(rect, backgroundPaint);

    final haloPulse = 0.86 + math.sin(time * 0.8) * 0.14;
    final haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        size.width * 0.42,
        [
          const Color(0xFF00E5FF).withAlpha((22 * haloPulse).round()),
          const Color(0xFF448AFF).withAlpha((18 * haloPulse).round()),
          const Color(0xFF7C4DFF).withAlpha((14 * haloPulse).round()),
          Colors.transparent,
        ],
        const [0.0, 0.22, 0.5, 1.0],
      );
    canvas.drawCircle(center, size.width * 0.46, haloPaint);

    final beamPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.16, size.height * 0.18),
        Offset(size.width * 0.82, size.height * 0.82),
        [
          const Color(0xFF00E5FF).withAlpha(0),
          const Color(0xFF00E5FF).withAlpha(18),
          const Color(0xFF7C4DFF).withAlpha(26),
          const Color(0xFF00E5FF).withAlpha(0),
        ],
        const [0.0, 0.34, 0.62, 1.0],
      )
      ..strokeWidth = 2.2;

    final beamOffset = math.sin(time * 0.75) * 18;
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.22 + beamOffset),
      Offset(size.width * 0.82, size.height * 0.76 + beamOffset),
      beamPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.2 - beamOffset),
      Offset(size.width * 0.28, size.height * 0.78 - beamOffset),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CyberBackdropPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}

class _CyberParticleFieldPainter extends CustomPainter {
  const _CyberParticleFieldPainter({required this.time});

  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 56; i++) {
      final t = time * 0.18 + i * 0.37;
      final x = (math.sin(t * 1.8) * 0.5 + 0.5) * size.width;
      final y = (math.cos(t * 1.2 + i) * 0.5 + 0.5) * size.height;
      final alpha = 14 + ((math.sin(t * 2.3) + 1) * 0.5 * 24).round();
      paint.color =
          (i % 4 == 0 ? const Color(0xFF7C4DFF) : const Color(0xFF00E5FF))
              .withAlpha(alpha);
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.0 : 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberParticleFieldPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}

class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter({required this.time});

  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final verticalPaint = Paint()
      ..color = const Color(0xFF00E5FF).withAlpha(10)
      ..strokeWidth = 1;
    final horizontalPaint = Paint()
      ..color = const Color(0xFF00E5FF).withAlpha(8)
      ..strokeWidth = 1;

    final verticalOffset = (time * 9) % 34;
    final horizontalOffset = (time * 11) % 28;

    for (double x = -34 + verticalOffset; x <= size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), verticalPaint);
    }
    for (double y = -28 + horizontalOffset; y <= size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), horizontalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}

class _CyberPulsePainter extends CustomPainter {
  const _CyberPulsePainter({
    required this.rings,
    required this.time,
  });

  final List<_RingData> rings;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final coreGlow = Paint()
      ..shader = ui.Gradient.radial(
        center,
        size.width * 0.24,
        [
          const Color(0xFF00E5FF).withAlpha(30),
          const Color(0xFF448AFF).withAlpha(20),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(center, size.width * 0.26, coreGlow);

    for (final ring in rings) {
      final radius = ring.baseRadius + math.sin(time * 1.8 + ring.phase) * 4;
      final arcPaint = Paint()
        ..color = ring.color.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.width;
      final tickPaint = Paint()
        ..color = ring.color.withAlpha(84)
        ..strokeWidth = 1;

      final gap = (math.pi * 2) / ring.segments;
      for (int i = 0; i < ring.segments; i++) {
        if (i % 3 == 0) continue;
        final start = ring.rotation + i * gap;
        final sweep = gap * 0.66;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          arcPaint,
        );

        final outer = Offset(
          center.dx + math.cos(start) * (radius + 10),
          center.dy + math.sin(start) * (radius + 10),
        );
        final inner = Offset(
          center.dx + math.cos(start) * (radius + 2),
          center.dy + math.sin(start) * (radius + 2),
        );
        canvas.drawLine(inner, outer, tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyberPulsePainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.rings != rings;
  }
}
