import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/pulse_colors.dart';
import '../../../widgets/category_icon_3d.dart';
import '../../../utils/situation_helper.dart';
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
        // Страницы сигналов
        SizedBox(
          height: 110,
          child: PageView.builder(
            controller: _pageController,
            itemCount: filteredSignals.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              widget.onSignalFocused(filteredSignals[index]);
            },
            itemBuilder: (context, index) {
              final item = filteredSignals[index];
              final category = (item['category'] ?? 'Прочее').toString();
              final title = (item['title'] ?? item['summary'] ?? 'Городской сигнал').toString();
              final address = (item['address'] ?? 'Нижневартовск').toString();
              final status = (item['status'] ?? 'open').toString();
              final imageUrls = SituationHelper.extractImageUrls(item);
              final hasUserPhoto = imageUrls.isNotEmpty;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: GestureDetector(
                  onTap: () {
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
                        // Превью фото сигнала
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                            border: Border.all(
                              color: hasUserPhoto ? accentGlow.withOpacity(0.4) : Colors.white.withOpacity(0.1),
                              width: 1.2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                hasUserPhoto
                                    ? Image.network(
                                        imageUrls.first,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => CategoryIcon3D(category: category, size: 36),
                                      )
                                    : CategoryIcon3D(category: category, size: 40),
                                if (hasUserPhoto)
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.65),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 10),
                                    ),
                                  ),
                              ],
                            ),
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
