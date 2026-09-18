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
    String? photo,
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
        title: 'ВАШ ГОРОД · ЖИВОЙ',
        description: 'Нижневартовск в реальном времени: камеры, погода, сигналы жителей. Это ваш город — и вы здесь главный.',
        icon: Icons.favorite_rounded,
        photo: 'onboard_city_1.jpg',
        alignment: Alignment.center,
        indicator: null,
      ),
      (
        title: 'СМОТРИТЕ ГОРОД ГЛАЗАМИ КАМЕР',
        description: '126 городских камер прямо в приложении. Проверьте дорогу, двор или парковку — в один тап.',
        icon: Icons.videocam_rounded,
        photo: 'onboard_city_2.jpg',
        alignment: Alignment.centerRight,
        indicator: const Positioned(
          right: 70,
          top: 300,
          child: _OnboardingPulseIndicator(axis: Axis.horizontal, pointsRight: true),
        ),
      ),
      (
        title: 'ГОРОД СЛЫШИТ ВАС',
        description: 'Замечали яму, сломанный фонарь или потеряли питомца? Нажмите «+» — фотография распознается автоматически, а соседи поддержат.',
        icon: Icons.add_circle_outline_rounded,
        photo: 'onboard_city_3.jpg',
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
        title: 'ДОБРО ПОЖАЛОВАТЬ ДОМОЙ',
        description: 'Всё готово. Карта города, бюро находок, 3D-двойник и погода ждут вас. Хорошего дня, Нижневартовск!',
        icon: Icons.waving_hand_rounded,
        photo: 'onboard_city_4.jpg',
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
                color: const Color(0xFF0E2438).withOpacity(0.45),
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
                      constraints: const BoxConstraints(maxHeight: 480),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.97),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withOpacity(0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0EA5E9).withOpacity(0.25),
                            blurRadius: 30,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Реальное фото города (живой кадр с городской камеры)
                          if (step.photo != null)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(27)),
                              child: Image.network(
                                'http://45.153.68.59/${step.photo}',
                                height: 168,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 168,
                                  color: const Color(0xFFE0F2FE),
                                  child: const Icon(Icons.location_city_rounded,
                                      size: 64, color: Color(0xFF0284C7)),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(22.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Иконка-бейдж на светлом фоне
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF0EA5E9).withOpacity(0.12),
                                    border: Border.all(
                                      color: const Color(0xFF0EA5E9).withOpacity(0.6),
                                      width: 1.4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0EA5E9).withOpacity(0.25),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    step.icon,
                                    color: const Color(0xFF0284C7),
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Заголовок
                                Text(
                                  step.title,
                                  style: const TextStyle(
                                    color: Color(0xFF0F2A3F),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.3,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Описание
                                Text(
                                  step.description,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF33566E),
                                    fontSize: 13.5,
                                    fontFamily: 'Inter',
                                    height: 1.5,
                                  ),
                                ),
                                const Spacer(),
                                // Кнопка действия
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
