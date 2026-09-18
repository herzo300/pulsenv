// services/Frontend/lib/screens/onboarding_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_router.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'ИИ-Диспетчер «Гермес»',
      'subtitle': 'Мультимодельный анализ городских проблем',
      'desc': 'Гермес на DeepSeek V4.1 Flash отвечает на вопросы о городе, отслеживает законы Думы, а камера телефона распознаёт ямы, мусор и наледь — сигнал создаётся в один тап с адресом и координатами.',
      'asset': 'assets/images/onboarding/slide_1_ai_dispatcher.png',
      'icon': Icons.psychology_rounded,
      'color': Color(0xFF00E5FF),
    },
    {
      'title': 'Живая карта 3500+ домов',
      'subtitle': 'Сигналы, камеры и события в реальном времени',
      'desc': 'Карта Нижневартовска с реестром всех домов на точных координатах, 126 городских камер, радар осадков и свежие сигналы из пабликов — всё обновляется автоматически.',
      'asset': 'assets/images/onboarding/slide_2_p2p_mesh.png',
      'icon': Icons.map_rounded,
      'color': Color(0xFF3B82F6),
    },
    {
      'title': 'Официальные обращения',
      'subtitle': 'ГОСТ-жалобы и диалог с УК',
      'desc': 'Готовые обращения по 59-ФЗ в Администрацию, паспорт дома с реальной УК, плановые отключения ЖКХ и сигналы соседей по вашему адресу — без звонков и очередей.',
      'asset': 'assets/images/onboarding/slide_3_gost_claims.png',
      'icon': Icons.description_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'title': 'Погода и гидропост Оби',
      'subtitle': 'Реальные данные Open-Meteo и NOAA',
      'desc': 'Прогноз на 7 дней, качество воздуха, аврора от kp-индекса, атлас затмений NASA и уровень реки Обь с порогами паводка — только проверенные источники.',
      'asset': 'assets/images/onboarding/slide_4_ob_weather.png',
      'icon': Icons.water_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'title': 'Бюро находок и соседи',
      'subtitle': 'Взаимопомощь без накруток',
      'desc': 'Потеряшки из городских пабликов с фото, соседский чат дома и просьбы о помощи — живые люди, реальные объявления, никаких фейков.',
      'asset': 'assets/images/onboarding/slide_5_community.png',
      'icon': Icons.people_alt_rounded,
      'color': Color(0xFFEC4899),
    },
  ];

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      context.go(AppRouter.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;
    final slide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: Stack(
        children: [
          // Background photo with smooth fade transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: KeyedSubtree(
              key: ValueKey<int>(_currentPage),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    slide['asset'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF060913).withOpacity(0.35),
                          const Color(0xFF060913).withOpacity(0.78),
                          const Color(0xFF060913),
                        ],
                        stops: const [0.0, 0.45, 0.85],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content PageView
          SafeArea(
            child: Column(
              children: [
                // Top Bar with Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (slide['color'] as Color).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(slide['icon'] as IconData, color: slide['color'] as Color, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'CITY PULSE NV',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (!isLast)
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: const Text(
                            'ПРОПУСТИТЬ',
                            style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final item = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: (item['color'] as Color).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: (item['color'] as Color).withOpacity(0.4)),
                              ),
                              child: Text(
                                item['subtitle'].toString().toUpperCase(),
                                style: TextStyle(
                                  color: item['color'] as Color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0.0),
                            const SizedBox(height: 14),
                            Text(
                              item['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ).animate().fadeIn(duration: 450.ms, delay: 100.ms).slideY(begin: 0.15, end: 0.0),
                            const SizedBox(height: 12),
                            Text(
                              item['desc'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.15, end: 0.0),
                            const SizedBox(height: 28),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Page Indicator and Next/Start Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(
                          _slides.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutCubic,
                            margin: const EdgeInsets.only(right: 6),
                            height: 8,
                            width: _currentPage == i ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == i ? (slide['color'] as Color) : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: slide['color'] as Color,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: (slide['color'] as Color).withOpacity(0.5),
                        ),
                        onPressed: () {
                          if (isLast) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Text(
                              isLast ? 'НАЧАТЬ' : 'ДАЛЕЕ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
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
}
