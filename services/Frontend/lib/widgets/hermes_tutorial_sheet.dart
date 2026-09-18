// services/Frontend/lib/widgets/hermes_tutorial_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HermesTutorialSheet extends StatefulWidget {
  final VoidCallback? onComplete;

  const HermesTutorialSheet({super.key, this.onComplete});

  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('hermes_tutorial_viewed_v4') ?? false;
    if (!alreadyShown && context.mounted) {
      await show(context);
      await prefs.setBool('hermes_tutorial_viewed_v4', true);
    }
  }

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => const HermesTutorialSheet(),
    );
  }

  @override
  State<HermesTutorialSheet> createState() => _HermesTutorialSheetState();
}

class _HermesTutorialSheetState extends State<HermesTutorialSheet> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _slides = const [
    {
      'image': 'assets/images/hermes_skill_passport.png',
      'color': Color(0xFF00E5FF),
      'badge': '3 450+ ДОМОВ И 43 УК',
      'title': 'Паспорт любого дома и капремонт',
      'description':
          'Полный цифровой паспорт всех многоквартирных домов Нижневартовска: точный год постройки (1974–2024), серия проекта, % износа, класс энергоэффективности, контакты диспетчерской вашей УК и план капремонта Югры до 2030 года.',
      'tip': 'Спросите: «Расскажи историю дома на Ленина 15» или «Какая УК обслуживает Ханты-Мансийскую 21?»',
    },
    {
      'image': 'assets/images/hermes_skill_emergency.png',
      'color': Color(0xFFF59E0B),
      'badge': 'СИНХРОНИЗАЦИЯ 24/7 С ЕДДС 112',
      'title': 'ИИ-Sentinel контроль аварий и отключений',
      'description':
          'Автоматический круглосуточный мониторинг вашего дома. При фиксации аварий Горводоканала, НЭСКО, УТС или сводок ЕДДС 112 Гермес мгновенно присылает уведомление в чат и push-алерт.',
      'tip': 'Нажмите «Включить мониторинг 24/7» в паспорте дома или спросите: «Есть ли отключения воды?»',
    },
    {
      'image': 'assets/images/hermes_skill_flood.png',
      'color': Color(0xFF10B981),
      'badge': 'ЖИВОЕ НЕБО И АКТИРОВКИ',
      'title': 'Погода, индекс AQI и нормы ВОЗ',
      'description':
          'Точные метеоданные, динамический цвет неба с городских камер, расчет школьных актировок ХМАО и показатели PM2.5, NO2, O3 с подробными медицинскими разъяснениями норм ВОЗ при клике.',
      'tip': 'Спросите: «Будет ли актировка завтра?» или «Какое качество воздуха на Комсомольском?»',
    },
    {
      'image': 'assets/images/hermes_skill_parking.png',
      'color': Color(0xFF8B5CF6),
      'badge': '180+ LIVE-КАМЕР ГОРОДА',
      'title': 'Прямой эфир городских камер',
      'description':
          'Просмотр видеопотоков городских камер у перекрёстков и скверов с автопереключением на live-кадры прямо в чате.',
      'tip': 'Спросите: «Покажи камеру на площади Нефтяников» или «Что происходит на Набережной?»',
    },
    {
      'image': 'assets/images/hermes_skill_chat.png',
      'color': Color(0xFFEC4899),
      'badge': 'БЮРО НАХОДОК',
      'title': 'Находки и потеряшки с гео-радаром',
      'description':
          'Объявления о находках и потеряшках с фото, гео-радар поиска с выбором радиуса от 500 м до 5 км и почасовой автосбор новых объявлений из городских пабликов.',
      'tip': 'Спросите: «Найден ли черный кот в 16 микрорайоне?» или нажмите «Нашел/Потерял».',
    },
    {
      'image': 'assets/images/hermes_skill_voice.png',
      'color': Color(0xFF06B6D4),
      'badge': 'ЮРИДИЧЕСКИЙ ИИ-СТАНДАРТ',
      'title': 'Официальные обращения по ФЗ-59',
      'description':
          'Составление юридически безупречных заявлений в Администрацию Нижневартовска, Жилстройнадзор Югры и Прокуратуру со ссылками на СНиП, СанПиН, ГОСТ и автоматическим прикреплением фото.',
      'tip': 'Спросите: «Составь жалобу на яму во дворе по ГОСТ» или «Напиши претензию в УК».',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.84),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A).withOpacity(0.96) : Colors.white.withOpacity(0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, -10),
            )
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF00E5FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'НОВЫЕ НАВЫКИ ГЕРМЕСА',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'ИИ-Диспетчер Нижневартовска 2026',
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 24, color: Colors.white12),

            // Slides PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  final color = slide['color'] as Color;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),
                          // Visual Photo Card from real app
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [color.withOpacity(0.8), color.withOpacity(0.2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: color, width: 2.2),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.35),
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                slide['image'] as String,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withOpacity(0.5)),
                            ),
                            child: Text(
                              slide['badge'] as String,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Title
                          Text(
                            slide['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Description
                          Text(
                            slide['description'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withOpacity(0.80),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Actionable Tip
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline_rounded,
                                    color: Colors.amberAccent, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    slide['tip'] as String,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white70,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Indicator Dots & Navigation Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(
                      _slides.length,
                      (idx) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentIndex == idx ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == idx
                              ? const Color(0xFF00E5FF)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Next / Done Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shadowColor: const Color(0xFF00E5FF).withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (_currentIndex < _slides.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.pop(context);
                        widget.onComplete?.call();
                      }
                    },
                    child: Text(
                      _currentIndex == _slides.length - 1 ? 'Понятно' : 'Далее',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
