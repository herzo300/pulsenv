import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/backend_api_service.dart';
import '../services/sound_service.dart';

class CityInfoTickerWidget extends StatefulWidget {
  final String city;
  const CityInfoTickerWidget({super.key, required this.city});

  @override
  State<CityInfoTickerWidget> createState() => _CityInfoTickerWidgetState();
}

class _CityInfoTickerWidgetState extends State<CityInfoTickerWidget> with SingleTickerProviderStateMixin {
  bool _visible = true;
  String _tickerText = '⚡ НОВОСТИ НИЖНЕВАРТОВСКА: Загрузка оперативной сводки ЕДДС-112 и городских событий...';
  int _satisfactionJkh = 88;
  int _satisfactionAdmin = 91;
  Timer? _refreshTimer;
  late ScrollController _scrollController;
  Timer? _scrollTimer;
  bool _isScrolling = false;

  List<String> _rawNews = [];
  int _currentNewsIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fetchNewsAndShow();

    // Свежие городские данные каждые 5 минут: новости администрации/
    // пабликов, гидропост и городские статусы проверяются регулярно,
    // лента не «залипает» на одних и тех же строках
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_visible) _fetchNewsAndShow();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchNewsAndShow() async {
    try {
      final List<String> newsItems = [];

      // 1. Fetch live predictive JKH and events
      try {
        final resp = await BackendApiService.instance.get('/api/dispatcher/predictive-jkh?city=${widget.city}');
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          if (data['success'] == true) {
            _satisfactionJkh = data['satisfaction_jkh'] ?? 88;
            _satisfactionAdmin = data['satisfaction_admin'] ?? 91;

            final List<dynamic> goodEvents = data['good_events'] ?? [];
            if (goodEvents.isNotEmpty) {
              for (final ev in goodEvents) {
                newsItems.add('🌟 СОБЫТИЕ: $ev');
              }
            }

            final List<dynamic> alerts = data['alerts'] ?? [];
            for (final a in alerts) {
              if (a['risk_level'] == 'Критический' || a['risk_level'] == 'Повышенный') {
                newsItems.add('⚠️ ЖКХ: ${a['address']} — ${a['description']}');
              }
            }
          }
        }
      } catch (_) {}

      // 2. Свежие городские новости и изменения (администрация, паблики)
      try {
        final newsResp = await BackendApiService.instance
            .get('/api/alerts/ticker?city=${widget.city}');
        if (newsResp.statusCode == 200) {
          final data = json.decode(newsResp.body);
          final List<dynamic> items = data['items'] ?? [];
          for (final item in items.take(5)) {
            final text = (item['text'] ?? '').toString();
            if (text.isNotEmpty) {
              // Убираем префикс источника [vk:...]/[hermes:...] для компактности
              final clean = text.replaceAll(RegExp(r'^\[.*?\]\s*'), '');
              if (clean.isNotEmpty) newsItems.add('📰 $clean');
            }
          }
        }
      } catch (_) {}

      // 3. Fresh city reports and signals from the backend feed
      try {
        final reportsResp = await BackendApiService.instance.get('/api/reports?limit=6');
        if (reportsResp.statusCode == 200) {
          final reportsData = json.decode(reportsResp.body);
          final List<dynamic> list = reportsData is List ? reportsData : (reportsData['reports'] ?? []);
          for (final item in list.take(4)) {
            final title = item['title'] ?? item['category'] ?? '';
            final addr = item['address'] ?? '';
            final status = item['status'] == 'resolved' ? '✅ Решено' : '⚡ В работе';
            if (title.toString().isNotEmpty) {
              newsItems.add('$status: $title${addr.toString().isNotEmpty ? " ($addr)" : ""}');
            }
          }
        }
      } catch (_) {}

      // 4. Гидропост: реальный уровень Оби из API (без хардкода)
      try {
        final floodResp = await BackendApiService.instance.get('/api/flood/status');
        if (floodResp.statusCode == 200) {
          final fd = json.decode(floodResp.body);
          final level = fd['current_level_cm'];
          final change = fd['daily_change_cm'];
          final threat = (fd['threat_level'] ?? '').toString();
          if (level != null) {
            final trend = change == null || change == 0
                ? 'стабильно'
                : (change > 0 ? '+$change см за сутки' : '$change см за сутки');
            // Краткое имя угрозы без скобок-расшифровок
            final shortThreat = threat.split('(').first.trim();
            newsItems.add('🌊 ОБЬ: уровень $level см ($trend) — $shortThreat');
          }
        }
      } catch (_) {}

      if (mounted) {
        _rawNews = newsItems;
        _currentNewsIndex = 0;
        _updateDisplayedText();
      }
    } catch (e) {
      debugPrint('Error fetching city news ticker: $e');
    }
  }

  void _updateDisplayedText() {
    if (_rawNews.isEmpty) return;
    // Re-order news items starting from current index
    final ordered = [
      ..._rawNews.sublist(_currentNewsIndex),
      ..._rawNews.sublist(0, _currentNewsIndex),
    ];
    final joined = ordered.join('   ✦   ');
    setState(() {
      _tickerText = '$joined   ✦   $joined';
      _visible = true;
    });

    _startScrolling();
  }

  void _switchToNextNewsAndSpeak() {
    if (_rawNews.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _currentNewsIndex = (_currentNewsIndex + 1) % _rawNews.length;
    });
    _updateDisplayedText();

    // Clean text for clear audio speech playback
    final rawText = _rawNews[_currentNewsIndex];
    final cleanText = rawText
        .replaceAll(RegExp(r'[^\w\sа-яА-ЯёЁ0-9.,-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanText.isNotEmpty) {
      SoundService().speak(cleanText);
    }
  }

  void _startScrolling() {
    _scrollTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0.0);
      _runScrollLoop();
    });
  }

  void _runScrollLoop() {
    if (!mounted || !_scrollController.hasClients || !_visible || _isScrolling) return;
    _isScrolling = true;

    const speed = 32.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      _isScrolling = false;
      return;
    }

    final duration = Duration(milliseconds: ((maxScroll / speed) * 1000).round());

    _scrollController.animateTo(
      maxScroll,
      duration: duration,
      curve: Curves.linear,
    ).then((_) {
      _isScrolling = false;
      if (mounted && _scrollController.hasClients) {
        _scrollTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
            _runScrollLoop();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark
        ? const Color(0xFF070E1A).withOpacity(0.94)
        : const Color(0xFFFFFFFF).withOpacity(0.96);
    final borderColor = isDark
        ? const Color(0xFF00E5FF).withOpacity(0.4)
        : const Color(0xFFCBD5E1);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final badgeTextColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: GestureDetector(
        onTap: _switchToNextNewsAndSpeak,
        // Свайп вниз/вверх — смахнуть бегущую строку с экрана
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          final v = details.primaryVelocity!;
          if (v.abs() > 120) {
            HapticFeedback.lightImpact();
            setState(() => _visible = false);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? const Color(0xFF00E5FF).withOpacity(0.12) : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                // Glowing Live City News Badge
                Container(
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF00E5FF).withOpacity(0.28),
                              const Color(0xFF6366F1).withOpacity(0.22),
                            ]
                          : [
                              const Color(0xFFE0F2FE),
                              const Color(0xFFE0E7FF),
                            ],
                    ),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                    border: Border(
                      right: BorderSide(
                        color: borderColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sensors_rounded,
                        size: 13,
                        color: badgeTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ПУЛЬС',
                        style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),

                // Marquee Scrolling News Text
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (_) => true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(
                          child: Text(
                            _tickerText,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
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

