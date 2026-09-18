import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../services/city_weather_service.dart';

/// Bottom marquee for city alerts and weather warnings.
class CityAlertTicker extends StatefulWidget {
  const CityAlertTicker({
    super.key,
    required this.data,
    required this.isNightMode,
    required this.accent,
    this.useWeatherOnly = false,
    this.useCityOnly = false,
    this.selectedCategory,
    this.customWarningText,
  });

  final CityAlertTickerData data;
  final bool isNightMode;
  final Color accent;
  final bool useWeatherOnly;
  final bool useCityOnly;
  final String? selectedCategory;
  final String? customWarningText;

  @override
  State<CityAlertTicker> createState() => _CityAlertTickerState();
}

class _CityAlertTickerState extends State<CityAlertTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll;
  bool _visible = true;
  int _itemIndex = 0;

  @override
  void initState() {
    super.initState();
    _scroll = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
    _scroll.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _visible = false;
          });
        }
      }
    });
    _scroll.forward();
  }

  List<String> _getNewsList() {
    if (widget.customWarningText != null && widget.customWarningText!.isNotEmpty) {
      return [widget.customWarningText!];
    }
    if (widget.data.items.isNotEmpty) {
      return widget.data.items
          .map((e) => (e['text'] ?? e['title'] ?? widget.data.marquee).toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (widget.data.marquee.isNotEmpty) {
      final parts = widget.data.marquee
          .split(RegExp(r'\s*[|•\n]\s*'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts;
    }
    if (widget.data.weatherMarquee.isNotEmpty) {
      return [widget.data.weatherMarquee];
    }
    return ['Городские новости Нижневартовска обновлены'];
  }

  void _playNextNews() {
    final list = _getNewsList();
    if (list.isEmpty) return;
    setState(() {
      _itemIndex = (_itemIndex + 1) % list.length;
      _visible = true;
    });
    _scroll.reset();
    _scroll.forward();
  }

  @override
  void didUpdateWidget(covariant CityAlertTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.marquee != widget.data.marquee ||
        oldWidget.selectedCategory != widget.selectedCategory ||
        oldWidget.customWarningText != widget.customWarningText) {
      setState(() {
        _visible = true;
      });
      _scroll.reset();
      _scroll.forward();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newsList = _getNewsList();
    if (newsList.isEmpty) return const SizedBox.shrink();

    final text = newsList[_itemIndex % newsList.length].trim();
    if (text.isEmpty) return const SizedBox.shrink();

    IconData leadingIcon = Icons.campaign_rounded;
    Color bg = widget.isNightMode ? const Color(0xB30A101C) : const Color(0xDDF0F8FF);
    Color border = widget.accent.withAlpha(90);

    if (widget.customWarningText != null && widget.customWarningText!.isNotEmpty) {
      leadingIcon = Icons.warning_amber_rounded;
      bg = const Color(0xDDF97316);
      border = const Color(0xFFFED7AA);
    } else {
      leadingIcon = text.contains('градус') || text.contains('°C') || text.contains('ветер')
          ? Icons.wb_cloudy_rounded
          : Icons.newspaper_rounded;
    }

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0.0, 1.2),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeIn,
      child: GestureDetector(
        onTap: _playNextNews,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                top: BorderSide(color: border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  alignment: Alignment.center,
                  color: Colors.black.withOpacity(0.05),
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, _) {
                      final double angle = _scroll.value * 2 * math.pi;
                      final double scale = 1.0 + 0.15 * math.sin(_scroll.value * 2 * math.pi * 4);
                      return Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: angle,
                          child: Icon(
                            leadingIcon,
                            color: const Color(0xFF1E293B),
                            size: 18,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final marqueeWidth = constraints.maxWidth;
                      final estimatedTextWidth = text.length * 7.5;
                      final scrollDistance = marqueeWidth + estimatedTextWidth;

                      return ClipRect(
                        child: AnimatedBuilder(
                          animation: _scroll,
                          builder: (context, _) {
                            final xOffset = marqueeWidth - (_scroll.value * scrollDistance);
                            return Transform.translate(
                              offset: Offset(xOffset, 0),
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
