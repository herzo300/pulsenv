// services/Frontend/lib/screens/onboarding_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      'title': 'ИИ-Диспетчер Нижневартовска',
      'subtitle': 'Автоматическое распознавание ям, мусора и авто-нарушений',
      'desc': 'Мультимодельный аналитик Kimi k3 & GPT-4o мгновенно определяет категорию, тяжесть и адрес по 3450+ домам города.',
      'asset': 'assets/images/onboarding/slide_1_ai_dispatcher.png',
      'image': 'https://images.unsplash.com/photo-1573164713988-8665fc963095?auto=format&fit=crop&q=80&w=1200',
      'icon': Icons.psychology_rounded,
      'color': Color(0xFF00E5FF),
    },
    {
      'title': 'Автономная P2P Mesh-Сеть',
      'subtitle': 'Связь при -40°C и отмене сотовых вышек',
      'desc': 'Передача сигналов между смартфонами жителей через Bluetooth Low Energy и Wi-Fi Direct с 30-дневным серверным хранением.',
      'asset': 'assets/images/onboarding/slide_2_p2p_mesh.png',
      'image': 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80&w=1200',
      'icon': Icons.hub_rounded,
      'color': Color(0xFF3B82F6),
    },
    {
      'title': 'Официальные ГОСТ-Жалобы',
      'subtitle': 'ГОСТ Р 7.0.97-2016 с авто-подписью',
      'desc': 'Генерация готовых PDF-обращений в Администрацию и ГИБДД Нижневартовска с гарантией кириллических шрифтов без ошибок.',
      'asset': 'assets/images/onboarding/slide_3_gost_claims.png',
      'image': 'https://images.unsplash.com/photo-1450133064473-71024230f91b?auto=format&fit=crop&q=80&w=1200',
      'icon': Icons.description_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'title': 'Паводок реки Обь и 3D Погода',
      'subtitle': 'Гидропост Нижневартовска & Усредненный AQI',
      'desc': 'Ежедневный отслеживаемый уровень реки Обь (опасная отметка 980 см), точно убранные скачки качества воздуха и адаптивный фон.',
      'asset': 'assets/images/onboarding/slide_4_ob_weather.png',
      'image': 'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?auto=format&fit=crop&q=80&w=1200',
      'icon': Icons.water_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'title': '100% Реальное Сообщество',
      'subtitle': 'Бюро Находок и Соседская Взаимопомощь',
      'desc': 'Только verified активные жильцы домов без накруток. Интерактивные маркеры потеряшек на карте города и содействие.',
      'asset': 'assets/images/onboarding/slide_5_community.png',
      'image': 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&q=80&w=1200',
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
                    errorBuilder: (context, error, stackTrace) => CachedNetworkImage(
                      imageUrl: slide['image'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: const Color(0xFF0F172A)),
                      errorWidget: (context, url, err) => Container(color: const Color(0xFF0F172A)),
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
                            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0.0),
                            const SizedBox(height: 14),
                            Text(
                              item['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ).animate().fadeIn(duration: 450.ms, delay: 100.ms).slideY(begin: 0.2, end: 0.0),
                            const SizedBox(height: 12),
                            Text(
                              item['desc'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
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
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            height: 6,
                            width: _currentPage == i ? 24 : 6,
                            decoration: BoxDecoration(
                              color: _currentPage == i ? (slide['color'] as Color) : Colors.white24,
                              borderRadius: BorderRadius.circular(3),
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
