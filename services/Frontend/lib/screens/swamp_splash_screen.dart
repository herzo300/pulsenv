import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'map_screen.dart';
import '../services/sound_service.dart';

class SwampSplashScreen extends StatefulWidget {
  const SwampSplashScreen({super.key});

  @override
  State<SwampSplashScreen> createState() => _SwampSplashScreenState();
}

class _SwampSplashScreenState extends State<SwampSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _oilPumpController;
  late final AnimationController _pulseController;
  late final AnimationController _terminalController;
  late final AnimationController _fadeController;

  bool _ready = false;
  bool _exiting = false;

  final List<String> _terminalLogs = [];
  final math.Random _rng = math.Random();
  Timer? _logTimer;

  final List<String> _possibleLogs = [
    'INIT: Подключение к датчикам болот...',
    'SCAN: Уровень заболоченности: 84%',
    'RADAR: Обнаружена работающая скважина',
    'GEO: Сдвиг почв в пределах нормы',
    'OIL: Дебит в реальном времени: СТАБИЛЬНЫЙ',
    'PUMP: Скважина #08-A4 работает',
    'WARN: Внимание, повышение уровня сероводорода (ложное)',
    'NET: Получены пакеты телеметрии...',
  ];

  @override
  void initState() {
    super.initState();

    _oilPumpController = AnimationController(
       vsync: this, 
       duration: const Duration(seconds: 3)
    )..repeat(reverse: true);

    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _terminalController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _simulateLoading();
    SoundService().playSplashDesign('cyber'); 
    _startTerminalLogs();
  }

  void _startTerminalLogs() {
    _logTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) return;
      setState(() {
        if (_terminalLogs.length > 8) _terminalLogs.removeAt(0);
        _terminalLogs.add(_possibleLogs[_rng.nextInt(_possibleLogs.length)]);
      });
    });
  }

  Future<void> _simulateLoading() async {
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    setState(() => _ready = true);
    _fadeController.forward();
    SoundService().playPulse();
  }

  void _onEnter() {
    if (!_ready || _exiting) return;
    HapticFeedback.heavyImpact();
    setState(() => _exiting = true);
    SoundService().stopSplash();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => const MapScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _oilPumpController.dispose();
    _pulseController.dispose();
    _terminalController.dispose();
    _fadeController.dispose();
    _logTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0D), // Dark swamp/oil color
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _exiting ? 0.0 : 1.0,
        child: Stack(
          children: [
            // Background topography
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _SwampTopographyPainter(
                      pulseProgress: _pulseController.value,
                    ),
                  );
                },
              ),
            ),
            
            // Oil falling / Digital rain
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: CustomPaint(
                  painter: _OilDropsPainter(time: _oilPumpController.value),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  
                  // Top Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFAABB22), Color(0xFF558833)], // Swampy green-yellow
                    ).createShader(bounds),
                    child: Text(
                      'НЕФТЕЮГАНСКИЙ МОНИТОР', // Oil region reference
                      style: GoogleFonts.russoOne(
                        fontSize: 22,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'КОМПЛЕКСНЫЙ АНАЛИЗ БОЛОТНЫХ МАССИВОВ',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const Spacer(),
                  
                  // Central interactive element (Pump-like or radar)
                  GestureDetector(
                    onTap: _onEnter,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulse = _pulseController.value;
                        final scale = _ready ? 1.0 + (pulse * 0.04) : 0.9;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFAABB22).withOpacity(_ready ? 0.8 : 0.3),
                                width: 2,
                                style: BorderStyle.values[1], // Dashed imitation if drawn manually, but let's just use solid
                              ),
                              boxShadow: _ready ? [
                                BoxShadow(
                                  color: const Color(0xFF558833).withOpacity(0.3 + pulse * 0.2),
                                  blurRadius: 30,
                                  spreadRadius: 8,
                                )
                              ] : [],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Inner radar sweep
                                AnimatedBuilder(
                                  animation: _oilPumpController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _oilPumpController.value * math.pi * 2,
                                      child: Container(
                                        width: 150,
                                        height: 150,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: SweepGradient(
                                            colors: [
                                              Colors.transparent,
                                              const Color(0xFFAABB22).withOpacity(0.4),
                                              const Color(0xFFAABB22).withOpacity(0.8),
                                            ],
                                            stops: const [0.0, 0.8, 1.0],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                ),
                                Center(
                                  child: Text(
                                    _ready ? 'ДОСТУП' : 'БУРЕНИЕ...',
                                    style: GoogleFonts.russoOne(
                                      color: const Color(0xFFAABB22).withOpacity(_ready ? 1.0 : 0.5),
                                      fontSize: 18,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Spacer(),

                  // Terminal logs window
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF050806).withOpacity(0.8),
                        border: Border.all(
                          color: const Color(0xFF558833).withOpacity(0.5),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: const Color(0xFF558833).withOpacity(0.2),
                            child: Row(
                              children: [
                                const Icon(Icons.terminal, color: Color(0xFFAABB22), size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  'СИСТЕМА ТЕЛЕМЕТРИИ V8.4',
                                  style: GoogleFonts.vt323(
                                    color: const Color(0xFFAABB22),
                                    fontSize: 14,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _terminalLogs.length,
                                itemBuilder: (context, index) {
                                  return Text(
                                    '> ${_terminalLogs[index]}',
                                    style: GoogleFonts.vt323(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwampTopographyPainter extends CustomPainter {
  final double pulseProgress;

  _SwampTopographyPainter({required this.pulseProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF558833).withOpacity(0.05 + pulseProgress * 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw wavy contour lines like a topographical map of a swamp
    for (int i = 1; i <= 6; i++) {
      final path = Path();
      final radius = 40.0 * i;
      
      for (double angle = 0; angle < math.pi * 2; angle += 0.2) {
        final noise = math.sin(angle * i * 2) * 10 + math.cos(angle * 3) * 15;
        final actualRadius = radius + noise;
        final x = center.dx + actualRadius * math.cos(angle);
        final y = center.dy + actualRadius * math.sin(angle);
        
        if (angle == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SwampTopographyPainter oldDelegate) => true;
}

class _OilDropsPainter extends CustomPainter {
  final double time;

  _OilDropsPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF223311) // Very dark green-black oil
      ..style = PaintingStyle.fill;

    final rnd = math.Random(42); // Fixed seed for same positions

    for (int i = 0; i < 30; i++) {
      final startX = rnd.nextDouble() * size.width;
      final speed = rnd.nextDouble() * 0.5 + 0.2;
      final yOffset = rnd.nextDouble();
      
      final currentY = ((time * speed + yOffset) % 1.0) * size.height;
      final length = rnd.nextDouble() * 40 + 20;
      final width = rnd.nextDouble() * 3 + 1;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, currentY, width, length),
        const Radius.circular(2),
      );
      
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OilDropsPainter oldDelegate) => true;
}
