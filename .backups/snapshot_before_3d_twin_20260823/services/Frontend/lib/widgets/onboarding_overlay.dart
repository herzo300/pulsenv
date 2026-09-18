import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/pulse_colors.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingOverlay({super.key, required this.onFinished});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  final List<({
    String title,
    String description,
    IconData icon,
    Alignment alignment,
    Widget? indicator,
  })> _steps = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();

    _steps.addAll([
      (
        title: 'ДОБРО ПОЖАЛОВАТЬ',
        description: 'Пульс Города — это интерактивный кибер-монитор Нижневартовска. Мы поможем вам освоить управление!',
        icon: Icons.monitor_heart_rounded,
        alignment: Alignment.center,
        indicator: null,
      ),
      (
        title: 'УПРАВЛЕНИЕ СЛОЯМИ',
        description: 'В боковой панели справа вы можете включать городские камеры, слои ЖКХ и активировать погодные шейдеры.',
        icon: Icons.layers_rounded,
        alignment: Alignment.centerRight,
        indicator: const Positioned(
          right: 70,
          top: 300,
          child: _OnboardingPulseIndicator(axis: Axis.horizontal, pointsRight: true),
        ),
      ),
      (
        title: 'ДОБАВИТЬ СИГНАЛ',
        description: 'Центральная кнопка "+" внизу позволяет быстро сообщить о проблеме. ИИ Гемини автоматически распознает фото!',
        icon: Icons.add_circle_outline_rounded,
        alignment: Alignment.bottomCenter,
        indicator: const Positioned(
          left: 0,
          right: 0,
          bottom: 110,
          child: Center(
            child: _OnboardingPulseIndicator(axis: Axis.vertical, pointsRight: false),
          ),
        ),
      ),
      (
        title: 'ОПЕРАТОР ПОДКЛЮЧЕН',
        description: 'Система готова к работе. Получайте достижения, просматривайте воронку активности и делитесь решениями!',
        icon: Icons.verified_user_rounded,
        alignment: Alignment.center,
        indicator: null,
      ),
    ]);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _animController.reverse().then((_) {
        setState(() {
          _currentStep++;
        });
        _animController.forward();
      });
    } else {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Positioned.fill(
      child: Stack(
        children: [
          // Dark blur backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
              child: Container(
                color: Colors.black.withOpacity(0.55),
              ),
            ),
          ),

          // Custom indicator arrows
          if (step.indicator != null) step.indicator!,

          // Onboarding Dialog Box
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 340),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1424).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: PulseColors.primary.withOpacity(0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PulseColors.primary.withOpacity(0.12),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated Glowing Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: PulseColors.primary.withOpacity(0.15),
                              border: Border.all(
                                color: PulseColors.primary.withOpacity(0.5),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: PulseColors.primary.withOpacity(0.2),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              step.icon,
                              color: PulseColors.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Title
                          Text(
                            step.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontFamily: 'Inter',
                              shadows: [
                                Shadow(
                                  color: PulseColors.primary.withOpacity(0.8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Description
                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              fontFamily: 'Inter',
                              height: 1.45,
                            ),
                          ),
                          const Spacer(),
                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PulseColors.primary,
                                foregroundColor: Colors.black,
                                elevation: 8,
                                shadowColor: PulseColors.primary.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _nextStep,
                              child: Text(
                                _currentStep == _steps.length - 1 ? 'НАЧАТЬ РАБОТУ' : 'ДАЛЕЕ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPulseIndicator extends StatefulWidget {
  final Axis axis;
  final bool pointsRight;

  const _OnboardingPulseIndicator({
    required this.axis,
    required this.pointsRight,
  });

  @override
  State<_OnboardingPulseIndicator> createState() => _OnboardingPulseIndicatorState();
}

class _OnboardingPulseIndicatorState extends State<_OnboardingPulseIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double shift = _animation.value;
        final Offset offset = widget.axis == Axis.horizontal
            ? Offset(widget.pointsRight ? shift : -shift, 0)
            : Offset(0, shift);

        return Transform.translate(
          offset: offset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PulseColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  widget.axis == Axis.horizontal
                      ? (widget.pointsRight ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded)
                      : Icons.arrow_downward_rounded,
                  color: PulseColors.primary,
                  size: 36,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
