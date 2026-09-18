import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

/// 3-step interactive onboarding spotlight for new users.
class OnboardingSpotlightWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingSpotlightWidget({super.key, required this.onComplete});

  @override
  State<OnboardingSpotlightWidget> createState() => _OnboardingSpotlightWidgetState();
}

class _OnboardingSpotlightWidgetState extends State<OnboardingSpotlightWidget> {
  int _currentStep = 0;

  final List<Map<String, String>> _steps = [
    {
      'title': '1. Мониторинг ЖКХ и статуса дома',
      'desc': 'Проверяйте живой статус горячей воды, тепла и электричества по вашему адресу с таймерами включения.',
      'icon': '🏢',
    },
    {
      'title': '2. 241+ Видеокамер Нижневартовска',
      'desc': 'Смотрите живые HLS-потоки перекрестков и дворов. Нажмите и удерживайте камеру для быстрого 3-секундного превью.',
      'icon': '📹',
    },
    {
      'title': '3. Нейросеть-диспетчер «Гермес»',
      'desc': 'Общайтесь с ИИ для генерации претензий, анализа происшествий и голосового поиска по всему городу.',
      'icon': '🤖',
    },
  ];

  void _nextStep() {
    HapticService.instance.medium();
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Stack(
      children: [
        // Semi-transparent backdrop
        ModalBarrier(
          color: Colors.black.withOpacity(0.75),
          dismissible: false,
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step['icon']!,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step['title']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step['desc']!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: List.generate(_steps.length, (index) {
                            final active = index == _currentStep;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: active ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: active ? Colors.cyanAccent : Colors.white24,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                        ElevatedButton(
                          onPressed: _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentStep == _steps.length - 1 ? 'Понятно!' : 'Далее',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
