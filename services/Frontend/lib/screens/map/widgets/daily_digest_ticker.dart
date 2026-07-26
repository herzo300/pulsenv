import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:skeletonizer/skeletonizer.dart';
import '../../../map/map_config.dart';
import '../../../theme/pulse_colors.dart';
import '../../../services/city_provider.dart';

/// Premium daily digest ticker with Liquid-Glass styling.
///
/// Design upgrades applied (UI/UX Pro Max):
///   • BackdropFilter glass-morphism instead of flat solid background
///   • Animated AI sparkle icon with pulsing glow
///   • Smooth auto-scroll for long text (marquee)
///   • Swipe-to-dismiss with opacity transition
class DailyDigestTicker extends StatefulWidget {
  const DailyDigestTicker({super.key});

  static bool hasBeenShownThisSession = false;

  @override
  State<DailyDigestTicker> createState() => _DailyDigestTickerState();
}

class _DailyDigestTickerState extends State<DailyDigestTicker>
    with TickerProviderStateMixin {
  String _digestText = 'Загрузка дайджеста мероприятий...';
  bool _isVisible = true;
  bool _isLoading = true;

  late AnimationController _glowController;
  late AnimationController _dismissController;
  late Animation<double> _dismissOpacity;
  ScrollController? _scrollController;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dismissOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.easeOut),
    );

    if (DailyDigestTicker.hasBeenShownThisSession) {
      _isVisible = false;
    } else {
      DailyDigestTicker.hasBeenShownThisSession = true;
      _glowController.repeat(reverse: true);
      _fetchDigest();
    }
  }

  Future<void> _fetchDigest() async {
    try {
      final cityParam = CityProvider().activeCity.backendCityParam;
      final response = await http
          .get(Uri.parse('${MapConfig.backendApiBaseUrl}/daily-digest?city=$cityParam'))
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _digestText =
                data['ai_summary']?.toString().trim().isNotEmpty == true
                    ? data['ai_summary'].toString()
                    : 'Новых мероприятий за сегодня нет.';
            _isLoading = false;
          });
          _startAutoScroll();
          return;
        }
        setState(() {
          _digestText = 'Сводка за день формируется...';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _digestText = 'Нажмите, чтобы открыть Дайджест';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _digestText = 'Нажмите, чтобы открыть Дайджест';
          _isLoading = false;
        });
      }
    }
  }

  void _openDigest() {
    if (!mounted) return;
    context.pushNamed('ai-digest');
  }

  void _startAutoScroll() {
    _scrollController = ScrollController();
    int passCount = 0;
    _scrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_scrollController == null || !_scrollController!.hasClients) return;
      final max = _scrollController!.position.maxScrollExtent;
      final current = _scrollController!.offset;
      if (current >= max) {
        passCount++;
        if (passCount >= 2) {
          _dismiss();
          return;
        }
        _scrollController!.animateTo(0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut);
      } else {
        _scrollController!.animateTo(
          (current + 180).clamp(0.0, max),
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _dismiss() {
    _dismissController.forward().then((_) {
      if (mounted) setState(() => _isVisible = false);
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _dismissController.dispose();
    _scrollTimer?.cancel();
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isNightMode = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _dismissOpacity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: isNightMode
                    ? [
                        const Color(0xE00D1625),
                        const Color(0xE01A102F),
                      ]
                    : [
                        const Color(0xE5F3F7FA),
                        const Color(0xE5EEF2FF),
                      ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: (isNightMode ? Colors.white : Colors.black).withOpacity(0.08),
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isNightMode ? Colors.black : Colors.grey).withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openDigest,
                child: Row(
                  children: [
                    // Animated AI sparkle with glow
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.yellowAccent.withOpacity(
                                    0.3 + 0.3 * _glowController.value),
                                blurRadius: 8 + 6 * _glowController.value,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.yellowAccent,
                            size: 17,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    // Digest text with auto scroll
                    Expanded(
                      child: Skeletonizer(
                        enabled: _isLoading,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Text(
                            _isLoading
                                ? 'Это очень длинный текст заполнитель для скелетона сводки дня'
                                : _digestText,
                            style: TextStyle(
                              color: isNightMode ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Dismiss button with ripple
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _dismiss,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            color: (isNightMode ? Colors.white : Colors.black).withOpacity(0.7),
                            size: 17,
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
    );
  }
}
