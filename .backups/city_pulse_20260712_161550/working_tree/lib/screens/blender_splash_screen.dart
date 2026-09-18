import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/living/aura_living_engine.dart';
import '../widgets/aura_living_background.dart';

class BlenderSplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const BlenderSplashScreen({super.key, this.onComplete});

  @override
  State<BlenderSplashScreen> createState() => _BlenderSplashScreenState();
}

class _BlenderSplashScreenState extends State<BlenderSplashScreen> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _spinController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Play welcome sound (ElevenLabs voice-over/audio welcome)
    _playWelcomeSound();

    // Complete splash screen after 3.8 seconds
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (mounted) {
        if (widget.onComplete != null) {
          widget.onComplete!();
        } else {
          context.go('/map');
        }
      }
    });
  }

  Future<void> _playWelcomeSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/menu_welcome.mp3'), volume: 0.85);
    } catch (e) {
      debugPrint("Failed to play welcome sound: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _spinController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Black Gold Techno aesthetic
    final scene = AuraLivingScene(
      weather: AuraWeather.cosmos,
      practice: AuraPractice.home,
      palette: const [Color(0xFF0A0A0A), Color(0xFFFFD700), Color(0xFFD4AF37)],
      speed: 1.8,
      bloom: 1.0,
      particleDensity: 0.9,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: AuraLivingBackground(
        scene: scene,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Levitation physics
              final yOffset = math.sin(_controller.value * 2 * math.pi) * 12.0;
              // Scaling and fade in
              final scale = const Interval(0.0, 0.4, curve: Curves.easeOutBack).transform(_controller.value);
              final opacity = const Interval(0.0, 0.3, curve: Curves.easeIn).transform(_controller.value);

              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, yOffset),
                  child: Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Holographic Golden Spinner
                        AnimatedBuilder(
                          animation: _spinController,
                          builder: (context, _) {
                            return Transform.rotate(
                              angle: _spinController.value * 2 * math.pi,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFD700).withAlpha(160),
                                    width: 2.0,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFD4AF37).withAlpha(100),
                                          width: 1.5,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                    ),
                                    // Golden pointer/accent line
                                    Positioned(
                                      top: 4,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFD700),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFFFFD700),
                                              blurRadius: 10,
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
                          },
                        ),
                        const SizedBox(height: 24),
                        // Techno typography card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.35), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.18),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'СИСТЕМА ИНИЦИАЛИЗАЦИИ',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 11,
                                  letterSpacing: 4.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'CITY PULSE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
