import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:flutter/scheduler.dart';

import 'map_screen.dart';

enum SplashState { loading, ready, exploding }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  SplashState _state = SplashState.loading;

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
    _setupAnimations();
    _setupSensors();
    _simulateLoading();
  }

  void _setupAnimations() {
    // Дыхание ядра
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Взрыв волны перехода
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

  void _setupSensors() {
    try {
      _accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
        if (!mounted) return;
        // Сглаживание значений датчика
        setState(() {
          _tiltX = (_tiltX * 0.8) + (event.x * 0.2);
          _tiltY = (_tiltY * 0.8) + (event.y * 0.2);
        });
      });
    } catch (_) {
      // Игнорируем, если датчики недоступны (web, эмулятор)
    }
  }

  Future<void> _simulateLoading() async {
    // Минимальное время показа красивого экрана загрузки
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    setState(() {
      _state = SplashState.ready;
    });
  }

  void _handleCoreTap() {
    if (_state != SplashState.ready) return;

    // Haptic feedback для тактильности
    HapticFeedback.heavyImpact();

    setState(() {
      _state = SplashState.exploding;
    });

    _waveController.forward();
  }

  void _navigateToMap() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => const MapScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Волна уже перекрыла экран, переходим мгновенно без доп. анимации
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
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Тёмный фон
      body: Stack(
        children: [
          // 1. Фоновый слой с частицами (Параллакс)
          Positioned.fill(
            child: ParticleField(tiltX: _tiltX, tiltY: _tiltY),
          ),

          // 2. Тексты UI
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                const SizedBox(height: 200), // Место под ядро
                const Spacer(),
                const Text(
                  'ПУЛЬС ГОРОДА',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'НИЖНЕВАРТОВСК',
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
                        ? const Text(
                            'СКАНИРОВАНИЕ ИНФРАСТРУКТУРЫ...',
                            key: ValueKey('loading'),
                            style: TextStyle(
                              color: Color(0xFF00D9FF),
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
              // Небольшой параллакс самого ядра
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
                      final isReady = _state == SplashState.ready;
                      final isExploding = _state == SplashState.exploding;
                      
                      // Масштаб зависит от фазы дыхания и состояния
                      final scale = isExploding 
                          ? 0.0 
                          : isReady 
                              ? 1.0 + (_breathingController.value * 0.1)
                              : 0.8 + (_breathingController.value * 0.05);

                      // Прозрачность
                      final opacity = isExploding ? 0.0 : isReady ? 1.0 : 0.5;
                      
                      // Цвет
                      final coreColor = isReady 
                          ? const Color(0xFF00D9FF) 
                          : const Color(0xFF334155);

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
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: coreColor.withOpacity(isReady ? 0.6 : 0.2),
                                  blurRadius: 40,
                                  spreadRadius: isReady ? 10 * _breathingController.value : 0,
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
                                    ? const Icon(Icons.fingerprint, color: Colors.white, size: 32)
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
                // Масштаб волны (чтобы перекрыть весь экран)
                // Зависит от размеров экрана
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
                          const Color(0xFF00D9FF),
                          const Color(0xFF2196F3).withOpacity(0.8),
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
// Частицы и Параллакс
// ==========================================

class ParticleField extends StatefulWidget {
  final double tiltX;
  final double tiltY;

  const ParticleField({
    super.key,
    required this.tiltX,
    required this.tiltY,
  });

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
    // Генерируем начальные частицы
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
      painter: ParticlesPainter(
        particles: particles,
        tiltX: widget.tiltX,
        tiltY: widget.tiltY,
      ),
    );
  }
}

class Particle {
  double x, y; // Относительные координаты от 0.0 до 1.0
  double baseSize;
  double speed;
  double phase;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.baseSize,
    required this.speed,
    required this.phase,
    required this.color,
  });

  factory Particle.random(math.Random rnd) {
    final colors = [
      const Color(0xFF00D9FF), // Cyan
      const Color(0xFF2196F3), // Blue
      const Color(0xFF334155), // Slate
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
    // Медленный вертикальный дрейф
    y -= speed * dt * 0.1;
    if (y < -0.1) y = 1.1;
  }
}

class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final double tiltX;
  final double tiltY;

  ParticlesPainter({
    required this.particles,
    required this.tiltX,
    required this.tiltY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;

    for (var p in particles) {
      // Эффект мерцания (дыхания частиц)
      final alphaMult = (math.sin(time * p.speed * 10 + p.phase) + 1.0) / 2.0;
      paint.color = p.color.withOpacity(p.color.opacity * alphaMult);

      // Параллакс (смещение частиц зависит от размера экрана, размера частицы и наклона)
      // Чем больше частица, тем ближе она к камере, тем сильнее параллакс
      final parallaxFactor = p.baseSize * 5.0;
      final px = p.x * size.width - (tiltX * parallaxFactor);
      final py = p.y * size.height + (tiltY * parallaxFactor);

      // Обертка экрана (чтобы частицы не улетали за края при наклоне)
      final drawX = px % size.width;
      final drawY = py % size.height;

      // Свечение (Glow)
      if (alphaMult > 0.8) {
        final glowPaint = Paint()
          ..color = paint.color.withOpacity(paint.color.opacity * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(Offset(drawX, drawY), p.baseSize * 2, glowPaint);
      }

      canvas.drawCircle(Offset(drawX, drawY), p.baseSize, paint);
    }
    
    // Рисуем легкую абстрактную сетку, символизирующую улицы
    _drawGrid(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.3) // slate-800
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final step = 60.0;
    
    // Сетка тоже немного подвержена параллаксу (глубокий задний фон)
    final offsetX = (-tiltX * 10) % step;
    final offsetY = (tiltY * 10) % step;

    for (double x = offsetX; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = offsetY; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlesPainter oldDelegate) => true;
}
