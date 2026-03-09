import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/scheduler.dart';

import 'map_screen.dart';
import 'gravity_splash_screen.dart';
import 'cyber_splash_screen.dart';
import '../services/sound_service.dart';

enum SplashState { loading, ready, exploding }

// Различные варианты дизайна для оригинальности
enum SplashDesign { particles, aurora, network, gravity, cyber }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  SplashState _state = SplashState.loading;
  late SplashDesign _design;

  // Controllers
  late AnimationController _breathingController;
  late AnimationController _waveController;

  // Sensors
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    // Рандомный выбор сплэша при каждом запуске
    final designs = SplashDesign.values;
    _design = designs[math.Random().nextInt(designs.length)];

    _setupAnimations();
    _setupSensors();
    _simulateLoading();

    debugPrint('Выбран дизайн сплэша: ${_design.name}');
    SoundService().playSplashDesign(_design.name);
  }

  Color get _themeColor {
    switch (_design) {
      case SplashDesign.particles:
        return const Color(0xFF00D9FF); // Cyan
      case SplashDesign.aurora:
        return const Color(0xFF10B981); // Emerald
      case SplashDesign.network:
        return const Color(0xFF8B5CF6); // Purple
      case SplashDesign.gravity:
        return const Color(0xFF00E5FF); // Cyan
      case SplashDesign.cyber:
        return const Color(0xFF00E5FF); // Cyan
    }
  }

  Widget _buildBackground() {
    switch (_design) {
      case SplashDesign.particles:
        return ParticleField(tiltX: _tiltX, tiltY: _tiltY);
      case SplashDesign.aurora:
        return AuroraField(tiltX: _tiltX, tiltY: _tiltY);
      case SplashDesign.network:
        return NetworkField(tiltX: _tiltX, tiltY: _tiltY, themeColor: _themeColor);
      case SplashDesign.gravity:
        return const SizedBox.shrink();
      case SplashDesign.cyber:
        return const SizedBox.shrink();
    }
  }

  int _eventCount = 0;

  void _setupAnimations() {
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _breathingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_state == SplashState.ready) {
           SoundService().playPulse();
        }
        _setDiverseRhythm();
        _breathingController.forward(from: 0.0);
      }
    });
    _breathingController.forward();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _waveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToMap();
      }
    });
  }

  void _setDiverseRhythm() {
    // Чем больше проблем на карте, тем быстрее бьется "пульс"
    int baseMs = 1800;
    if (_eventCount > 0) {
      baseMs = math.max(600, 1800 - (_eventCount * 12)).toInt();
    }
    // Разнообразие "стука": добавляем 0..200мс рандом
    int variation = math.Random().nextInt(200);
    
    _breathingController.duration = Duration(milliseconds: baseMs + variation);
  }

  Future<void> _fetchMapEvents() async {
    const supabaseUrl = 'https://xpainxohbdoruakcijyq.supabase.co/rest/v1/reports?select=id';
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';
    
    try {
      final res = await http.get(
        Uri.parse(supabaseUrl),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey'
        }
      ).timeout(const Duration(seconds: 4));
      
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _eventCount = data.length;
          });
        }
      }
    } catch (_) {}
  }

  void _setupSensors() {
    try {
      _accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
        if (!mounted) return;
        setState(() {
          _tiltX = (_tiltX * 0.8) + (event.x * 0.2);
          _tiltY = (_tiltY * 0.8) + (event.y * 0.2);
        });
      });
    } catch (_) {
      // Игнорируем
    }
  }

  Future<void> _simulateLoading() async {
    // Ждём анимацию + параллельно качаем кол-во жалоб
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2500)),
      _fetchMapEvents(),
    ]);

    if (!mounted) return;
    setState(() {
      _state = SplashState.ready;
    });
  }

  void _handleCoreTap() {
    if (_state != SplashState.ready) return;
    HapticFeedback.heavyImpact();

    setState(() {
      _state = SplashState.exploding;
    });
    SoundService().stopSplash();
    _waveController.forward();
  }

  void _navigateToMap() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => const MapScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _waveController.dispose();
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dedicated full-screen splash screens
    if (_design == SplashDesign.gravity) {
      return const GravitySplashScreen();
    }
    if (_design == SplashDesign.cyber) {
      return const CyberSplashScreen();
    }

    final baseColor = _themeColor;

    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Тёмный фон
      body: Stack(
        children: [
          // 1. Случайный фоновый слой
          Positioned.fill(
            child: _buildBackground(),
          ),

          // 2. Тексты UI
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                const SizedBox(height: 200), // Место под ядро
                const Spacer(),
                Text(
                  'ПУЛЬС ГОРОДА',
                  style: TextStyle(
                    color: baseColor.withOpacity(0.8),
                    fontSize: 14,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 8.0),
                const Text(
                  'ПУЛЬС ГОРОДА',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
                const Spacer(flex: 2),
                
                // Статус
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: _state == SplashState.loading
                        ? Text(
                            'СКАНИРОВАНИЕ ИНФРАСТРУКТУРЫ...',
                            key: const ValueKey('loading'),
                            style: TextStyle(
                              color: baseColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 4,
                            ),
                          )
                        : _state == SplashState.ready
                            ? const Text(
                                'НАЖМИТЕ, ЧТОБЫ ЗАПУСТИТЬ ПУЛЬС',
                                key: ValueKey('ready'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              )
                            : const SizedBox(key: ValueKey('exploding')),
                  ),
                ),
              ],
            ),
          ),

          // 3. Интерактивное ядро по центру
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(-_tiltX * 2, _tiltY * 2),
              child: GestureDetector(
                onTap: _handleCoreTap,
                child: MouseRegion(
                  cursor: _state == SplashState.ready 
                      ? SystemMouseCursors.click 
                      : SystemMouseCursors.basic,
                  child: AnimatedBuilder(
                    animation: _breathingController,
                    builder: (context, child) {
                      final val = _breathingController.value;
                      // Двойной стук сердца (lub-dub)
                      double heartbeat = 0.0;
                      if (val < 0.2) {
                        heartbeat = math.sin((val / 0.2) * math.pi);
                      } else if (val >= 0.3 && val < 0.5) {
                        heartbeat = math.sin(((val - 0.3) / 0.2) * math.pi) * 0.8;
                      }

                      final isReady = _state == SplashState.ready;
                      final isExploding = _state == SplashState.exploding;
                      
                      final scale = isExploding 
                          ? 0.0 
                          : isReady 
                              ? 1.0 + (heartbeat * 0.2)
                              : 0.8 + (math.sin(val * math.pi) * 0.08);

                      final opacity = isExploding ? 0.0 : isReady ? 1.0 : 0.5;
                      
                      final coreColor = isReady ? baseColor : const Color(0xFF334155);

                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: coreColor.withOpacity(0.2),
                              border: Border.all(
                                color: coreColor.withOpacity(0.5),
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: coreColor.withOpacity(isReady ? 0.8 : 0.2),
                                  blurRadius: isReady ? 40 + (heartbeat * 20) : 40,
                                  spreadRadius: isReady ? (10 + heartbeat * 20) : 0,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: coreColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.8),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: isReady 
                                    ? const Icon(Icons.fingerprint, color: Colors.white, size: 32.0)
                                    : const SizedBox(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // 4. Эффект расходящейся волны (переход на карту)
          if (_state == SplashState.exploding)
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                final size = MediaQuery.of(context).size;
                final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
                final currentRadius = _waveController.value * maxRadius;

                return Positioned(
                  left: size.width / 2 - currentRadius,
                  top: size.height / 2 - currentRadius,
                  child: Container(
                    width: currentRadius * 2,
                    height: currentRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          baseColor,
                          baseColor.withOpacity(0.8),
                          const Color(0xFF020617).withOpacity(0.0),
                        ],
                        stops: const [0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ==========================================
// DESIGN 1: Particles (Существующий)
// ==========================================
class ParticleField extends StatefulWidget {
  final double tiltX;
  final double tiltY;

  const ParticleField({super.key, required this.tiltX, required this.tiltY});

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField> with SingleTickerProviderStateMixin {
  late List<Particle> particles;
  late Ticker _ticker;
  final math.Random random = math.Random();

  @override
  void initState() {
    super.initState();
    particles = List.generate(80, (index) => Particle.random(random));
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        for (var p in particles) {
          p.update(elapsed.inMilliseconds / 1000.0);
        }
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ParticlesPainter(particles: particles, tiltX: widget.tiltX, tiltY: widget.tiltY),
    );
  }
}

class Particle {
  double x, y;
  double baseSize;
  double speed;
  double phase;
  Color color;

  Particle({
    required this.x, required this.y,
    required this.baseSize, required this.speed,
    required this.phase, required this.color,
  });

  factory Particle.random(math.Random rnd) {
    final colors = [
      const Color(0xFF00D9FF), 
      const Color(0xFF2196F3), 
      const Color(0xFF334155),
    ];
    return Particle(
      x: rnd.nextDouble(),
      y: rnd.nextDouble(),
      baseSize: rnd.nextDouble() * 3 + 1,
      speed: rnd.nextDouble() * 0.05 + 0.01,
      phase: rnd.nextDouble() * math.pi * 2,
      color: colors[rnd.nextInt(colors.length)].withOpacity(rnd.nextDouble() * 0.5 + 0.1),
    );
  }

  void update(double dt) {
    y -= speed * dt * 0.1;
    if (y < -0.1) y = 1.1;
  }
}

class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final double tiltX;
  final double tiltY;

  ParticlesPainter({required this.particles, required this.tiltX, required this.tiltY});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;

    for (var p in particles) {
      final alphaMult = (math.sin(time * p.speed * 10 + p.phase) + 1.0) / 2.0;
      paint.color = p.color.withOpacity(p.color.opacity * alphaMult);

      final parallaxFactor = p.baseSize * 5.0;
      final px = p.x * size.width - (tiltX * parallaxFactor);
      final py = p.y * size.height + (tiltY * parallaxFactor);

      final drawX = px % size.width;
      final drawY = py % size.height;

      if (alphaMult > 0.8) {
        final glowPaint = Paint()
          ..color = paint.color.withOpacity(paint.color.opacity * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(Offset(drawX, drawY), p.baseSize * 2, glowPaint);
      }
      canvas.drawCircle(Offset(drawX, drawY), p.baseSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlesPainter oldDelegate) => true;
}


// ==========================================
// DESIGN 2: Aurora Waves (Северное сияние)
// ==========================================
class AuroraField extends StatefulWidget {
  final double tiltX;
  final double tiltY;

  const AuroraField({super.key, required this.tiltX, required this.tiltY});

  @override
  State<AuroraField> createState() => _AuroraFieldState();
}

class _AuroraFieldState extends State<AuroraField> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AuroraSplashPainter(time: _time, tiltX: widget.tiltX, tiltY: widget.tiltY),
    );
  }
}

class AuroraSplashPainter extends CustomPainter {
  final double time;
  final double tiltX;
  final double tiltY;

  AuroraSplashPainter({required this.time, required this.tiltX, required this.tiltY});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFF10B981), // Emerald
      const Color(0xFF00D9FF), // Cyan
      const Color(0xFF059669), // Darker Emerald
    ];

    for (int j = 0; j < colors.length; j++) {
      final path = Path();
      // Полупрозрачная широкая линия с размытием
      final blurPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 25.0
        ..color = colors[j].withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0);

      // Яркая тонкая линия ядра сияния
      final corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = colors[j].withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      bool isFirst = true;

      // Рисуем волну сияния
      for (double i = -50; i <= size.width + 50; i += 20) {
        final normX = i / size.width;
        final y = size.height * 0.5 
            + math.sin(normX * math.pi * 1.5 + time * (0.8 + j * 0.3)) * 120 
            + math.cos(normX * math.pi * 2.5 - time * 0.6) * 60
            + tiltY * 20 * (j + 1)
            + (j * 40 - 40); // Сдвиг слоев друг относительно друга

        final drawX = i - tiltX * 20 * (j + 1);

        if (isFirst) {
          path.moveTo(drawX, y);
          isFirst = false;
        } else {
          path.lineTo(drawX, y);
        }
      }

      canvas.drawPath(path, blurPaint);
      canvas.drawPath(path, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant AuroraSplashPainter oldDelegate) => true;
}


// ==========================================
// DESIGN 3: Network Data Grid (Матрица/Связи)
// ==========================================
class NetworkField extends StatefulWidget {
  final double tiltX;
  final double tiltY;
  final Color themeColor;

  const NetworkField({super.key, required this.tiltX, required this.tiltY, required this.themeColor});

  @override
  State<NetworkField> createState() => _NetworkFieldState();
}

class NetworkNode {
  double x, y;
  double vx, vy;
  NetworkNode(this.x, this.y, this.vx, this.vy);
}

class _NetworkFieldState extends State<NetworkField> with SingleTickerProviderStateMixin {
  late List<NetworkNode> nodes;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  final math.Random random = math.Random();

  @override
  void initState() {
    super.initState();
    // Инициализуем ноды случайными позициями и скоростями
    nodes = List.generate(50, (i) => NetworkNode(
      random.nextDouble(),
      random.nextDouble(),
      (random.nextDouble() - 0.5) * 0.05,
      (random.nextDouble() - 0.5) * 0.05,
    ));

    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      final dt = (elapsed - _lastElapsed).inMilliseconds / 1000.0;
      _lastElapsed = elapsed;

      setState(() {
        for (var n in nodes) {
          n.x += n.vx * dt;
          n.y += n.vy * dt;
          
          if (n.x < -0.1) n.vx = n.vx.abs();
          if (n.x > 1.1) n.vx = -n.vx.abs();
          if (n.y < -0.1) n.vy = n.vy.abs();
          if (n.y > 1.1) n.vy = -n.vy.abs();
        }
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: NetworkPainter(
        nodes: nodes, 
        tiltX: widget.tiltX, 
        tiltY: widget.tiltY,
        themeColor: widget.themeColor,
      ),
    );
  }
}

class NetworkPainter extends CustomPainter {
  final List<NetworkNode> nodes;
  final double tiltX;
  final double tiltY;
  final Color themeColor;

  NetworkPainter({required this.nodes, required this.tiltX, required this.tiltY, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.fill;
      
    final linePaint = Paint()
      ..strokeWidth = 1.0;

    // Учитываем параллакс при расчёте координат
    final actualNodes = nodes.map((n) {
      return Offset(
        n.x * size.width - tiltX * 30, 
        n.y * size.height + tiltY * 30
      );
    }).toList();

    for (int i = 0; i < actualNodes.length; i++) {
       // Свечение ноды
       final glowPaint = Paint()
          ..color = themeColor.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
       canvas.drawCircle(actualNodes[i], 4.0, glowPaint);
       
       // Центр ноды
       canvas.drawCircle(actualNodes[i], 2.0, pointPaint);
       
       // Соединяем близкие ноды
       for (int j = i + 1; j < actualNodes.length; j++) {
          final dist = (actualNodes[i] - actualNodes[j]).distance;
          if (dist < 100) {
             linePaint.color = themeColor.withOpacity(0.6 * (1.0 - (dist / 100)));
             canvas.drawLine(actualNodes[i], actualNodes[j], linePaint);
          }
       }
    }
  }

  @override
  bool shouldRepaint(covariant NetworkPainter oldDelegate) => true;
}
