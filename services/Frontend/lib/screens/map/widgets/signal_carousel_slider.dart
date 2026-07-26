import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/pulse_colors.dart';
import '../../../widgets/category_icon_3d.dart';
import 'map_glass_panel.dart';

/// Слайдер сигналов внизу экрана.
/// Отображается когда скрыт основной блок фильтров (_userFiltersHidden == true).
/// При свайпе плавно смещает карту к выбранному сигналу.
/// При тапе на карточку — разворачивает подробное описание вверх над слайдером.
class SignalCarouselSlider extends StatefulWidget {
  final List<Map<String, dynamic>> signals;
  final Function(Map<String, dynamic> signal) onSignalFocused;
  final Function(Map<String, dynamic> signal) onSignalTapped;
  final bool isNightMode;

  const SignalCarouselSlider({
    super.key,
    required this.signals,
    required this.onSignalFocused,
    required this.onSignalTapped,
    required this.isNightMode,
  });

  @override
  State<SignalCarouselSlider> createState() => _SignalCarouselSliderState();
}

class _SignalCarouselSliderState extends State<SignalCarouselSlider> {
  late final PageController _pageController;
  int _currentIndex = 0;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.86);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSignals = widget.signals.where((item) {
      final category = (item['category'] ?? '').toString();
      final isEvent = category == 'Мероприятие' || item['source_kind'] == 'event';
      return !isEvent;
    }).toList();

    if (filteredSignals.isEmpty) return const SizedBox.shrink();

    final isDark = widget.isNightMode;
    final bgFill = isDark ? const Color(0xEA0B1220) : const Color(0xEEFFFFFF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final accentGlow = isDark ? const Color(0xFF00E5FF) : const Color(0xFF2563EB);

    final activeExpandedSignal = (_expandedIndex != null && _expandedIndex! < filteredSignals.length)
        ? filteredSignals[_expandedIndex!]
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Вылетающая вверх деталь сигнала при нажатии
        if (activeExpandedSignal != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: MapGlassPanel(
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.all(16),
              fillColor: bgFill,
              blurSigma: 22,
              borderColors: [
                accentGlow.withOpacity(0.8),
                accentGlow.withOpacity(0.3),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentGlow.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (activeExpandedSignal['category'] ?? 'Прочее').toString().toUpperCase(),
                          style: TextStyle(
                            color: accentGlow,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                        onPressed: () {
                          setState(() {
                            _expandedIndex = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (activeExpandedSignal['title'] ?? activeExpandedSignal['summary'] ?? 'Городской сигнал').toString(),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (activeExpandedSignal['description'] ?? 'Описания нет').toString(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: accentGlow),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (activeExpandedSignal['address'] ?? 'Нижневартовск').toString(),
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          widget.onSignalTapped(activeExpandedSignal);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Подробнее →',
                          style: TextStyle(color: accentGlow, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fade(duration: 200.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
          ),
        // Страницы сигналов
        SizedBox(
          height: 110,
          child: PageView.builder(
            controller: _pageController,
            itemCount: filteredSignals.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _expandedIndex = null; // сворачиваем детали при свайпе
              });
              widget.onSignalFocused(filteredSignals[index]);
            },
            itemBuilder: (context, index) {
              final item = filteredSignals[index];
              final isExpanded = _expandedIndex == index;
              final category = (item['category'] ?? 'Прочее').toString();
              final title = (item['title'] ?? item['summary'] ?? 'Городской сигнал').toString();
              final address = (item['address'] ?? 'Нижневартовск').toString();
              final status = (item['status'] ?? 'open').toString();
              final imageUrls = (item['images'] as List?)?.cast<String>() ?? [];
              final hasUserPhoto = imageUrls.isNotEmpty;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedIndex = isExpanded ? null : index;
                    });
                    widget.onSignalTapped(item);
                  },
                  child: MapGlassPanel(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(12),
                    fillColor: bgFill,
                    blurSigma: 18,
                    borderColors: [
                      _currentIndex == index ? accentGlow.withOpacity(0.6) : Colors.white.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    child: Row(
                      children: [
                        // Иконка или фото
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: hasUserPhoto
                                ? Image.network(
                                    imageUrls.first,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => CategoryIcon3D(category: category, size: 36),
                                  )
                                : CategoryIcon3D(category: category, size: 40),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Контент
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentGlow.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        color: accentGlow,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  _buildStatusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded, size: 12, color: textSecondary),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
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
        // Индикатор точек слайдера
        if (filteredSignals.length > 1)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 4),
            height: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                math.min(filteredSignals.length, 12),
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: _currentIndex == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == i ? accentGlow : (isDark ? Colors.white30 : Colors.black26),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color col = Colors.orangeAccent;
    String text = 'В работе';
    if (status == 'resolved' || status == 'closed') {
      col = const Color(0xFF10B981);
      text = 'Решено';
    } else if (status == 'critical') {
      col = const Color(0xFFEF4444);
      text = 'Важно';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: col.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(color: col, fontSize: 9.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}
