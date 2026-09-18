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

  bool _isEmergencyAlert(Map<String, dynamic> item) {
    final cat = (item['category'] ?? '').toString().toLowerCase();
    final txt = (item['text'] ?? '').toString().toLowerCase();
    final hasEmergency = cat.contains('чп') || cat.contains('чрезвыч') || txt.contains('чп') || txt.contains('чрезвыч') || txt.contains('пожар') || txt.contains('взрыв');
    return hasEmergency;
  }

  @override
  Widget build(BuildContext context) {
    String text = '';
    IconData leadingIcon = Icons.campaign_rounded;
    Color bg = widget.isNightMode ? const Color(0xB30A101C) : const Color(0xDDF0F8FF);
    Color border = widget.accent.withAlpha(90);

    if (widget.customWarningText != null && widget.customWarningText!.isNotEmpty) {
      text = widget.customWarningText!;
      leadingIcon = Icons.warning_amber_rounded;
      bg = const Color(0xDDF97316); // Amber/Orange warning
      border = const Color(0xFFFED7AA);
    } else if (widget.useWeatherOnly) {
      text = widget.data.weatherMarquee;
      leadingIcon = Icons.wb_cloudy_rounded;
    } else if (widget.useCityOnly) {
      final List<Map<String, dynamic>> itemsToProcess = widget.selectedCategory != null
          ? widget.data.items.where((i) {
              if (i['type'] != 'channel') return false;
              final cat = (i['category'] ?? 'Прочее').toString().trim().toLowerCase();
              final sel = widget.selectedCategory!.trim().toLowerCase();
              return cat == sel;
            }).toList()
          : widget.data.items;

      final filtered = itemsToProcess.where(_isEmergencyAlert).toList();

      if (filtered.isEmpty) {
        return const SizedBox.shrink();
      }

      text = filtered.map((i) => i['text'].toString()).join('   •   ');

      final hasSeriousEmergency = filtered.any((i) =>
          i['severity'].toString().toLowerCase() == 'high' &&
          (i['category'].toString().toLowerCase().contains('чп') ||
           i['text'].toString().toLowerCase().contains('чп') ||
           i['text'].toString().toLowerCase().contains('пожар') ||
           i['text'].toString().toLowerCase().contains('взрыв')));

      final hasEmergency = filtered.any((i) =>
          i['category'].toString().toLowerCase().contains('чп') ||
          i['text'].toString().toLowerCase().contains('чп') ||
          i['text'].toString().toLowerCase().contains('пожар') ||
          i['text'].toString().toLowerCase().contains('взрыв'));

      final hasAccident = filtered.any((i) =>
          i['category'].toString().toLowerCase().contains('авари') ||
          i['category'].toString().toLowerCase().contains('дтп') ||
          i['text'].toString().toLowerCase().contains('авари') ||
          i['text'].toString().toLowerCase().contains('дтп') ||
          i['text'].toString().toLowerCase().contains('столкн'));

      final hasCrime = filtered.any((i) =>
          i['category'].toString().toLowerCase().contains('кримин') ||
          i['category'].toString().toLowerCase().contains('преступ') ||
          i['text'].toString().toLowerCase().contains('кримин') ||
          i['text'].toString().toLowerCase().contains('преступ') ||
          i['text'].toString().toLowerCase().contains('краж') ||
          i['text'].toString().toLowerCase().contains('драка') ||
          i['text'].toString().toLowerCase().contains('убий'));

      if (hasSeriousEmergency) {
        bg = const Color(0xDDEB3B3B);
        border = const Color(0xFFFCA5A5);
        leadingIcon = Icons.warning_rounded;
      } else if (hasEmergency) {
        bg = const Color(0xDDFF7D1A);
        border = const Color(0xFFFED7AA);
        leadingIcon = Icons.warning_amber_rounded;
      } else if (hasAccident) {
        bg = const Color(0xDDEAB308);
        border = const Color(0xFFFEF08A);
        leadingIcon = Icons.car_crash_rounded;
      } else if (hasCrime) {
        bg = const Color(0xDD8B5CF6);
        border = const Color(0xFFDDD6FE);
        leadingIcon = Icons.local_police_rounded;
      }
    }

    bg = Colors.white;
    border = Colors.black.withOpacity(0.12);

    text = text.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0.0, 1.2),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeIn,
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              top: BorderSide(
                color: border,
              ),
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
    );
  }
}
