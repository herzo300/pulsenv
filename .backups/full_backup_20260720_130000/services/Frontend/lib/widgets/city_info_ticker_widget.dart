import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import 'app_ui.dart';

class CityInfoTickerWidget extends StatefulWidget {
  final String city;
  const CityInfoTickerWidget({super.key, required this.city});

  @override
  State<CityInfoTickerWidget> createState() => _CityInfoTickerWidgetState();
}

class _CityInfoTickerWidgetState extends State<CityInfoTickerWidget> with SingleTickerProviderStateMixin {
  bool _visible = false;
  String _tickerText = 'Загрузка городских данных...';
  int _satisfactionJkh = 85;
  int _satisfactionAdmin = 88;
  Timer? _visibilityTimer;
  Timer? _fetchTimer;
  late ScrollController _scrollController;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fetchDataAndShow();

    // Trigger visibility cycle: shows up for 40 seconds, then hides, and triggers again every 3 minutes (simulating 30 mins)
    _visibilityTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _fetchDataAndShow();
    });
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    _fetchTimer?.cancel();
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDataAndShow() async {
    try {
      final resp = await BackendApiService.instance.get('/api/dispatcher/predictive-jkh?city=${widget.city}');
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true) {
          final jkhScore = data['satisfaction_jkh'] ?? 85;
          final adminScore = data['satisfaction_admin'] ?? 88;
          final List<dynamic> goodEvents = data['good_events'] ?? [];
          final List<dynamic> alerts = data['alerts'] ?? [];

          // Compile ticker text
          final List<String> parts = [];
          
          // Add satisfaction indexes
          parts.add('📊 ИНДЕКС УДОВЛЕТВОРЕННОСТИ: ЖКХ — $jkhScore%, Администрация — $adminScore%');

          // Add positive events
          if (goodEvents.isNotEmpty) {
            parts.add('🌟 СОБЫТИЯ ГОРОДА: ${goodEvents.join("  ★  ")}');
          }

          // Add predictive alerts
          final warnings = alerts.where((a) => a['risk_level'] == 'Критический' || a['risk_level'] == 'Повышенный').toList();
          if (warnings.isNotEmpty) {
            final warnTexts = warnings.map((w) => '⚠️ ВНИМАНИЕ: ${w['address']} — ${w['description']}').join("  ✦  ");
            parts.add('🚨 ПРЕДУПРЕЖДЕНИЯ ЖКХ: $warnTexts');
          } else {
            parts.add('🛡️ МОНИТОРИНГ ЖКХ: Работа тепло- и водосетей города стабильна.');
          }

          if (mounted) {
            setState(() {
              _tickerText = parts.join('   |   ');
              _satisfactionJkh = jkhScore;
              _satisfactionAdmin = adminScore;
              _visible = true;
            });
            
            // Start scrolling animation
            _startScrolling();

            // Hide ticker after 40 seconds
            _fetchTimer?.cancel();
            _fetchTimer = Timer(const Duration(seconds: 40), () {
              if (mounted) {
                setState(() => _visible = false);
                _scrollTimer?.cancel();
              }
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching predictive ticker alerts: $e');
    }
  }

  void _startScrolling() {
    _scrollTimer?.cancel();
    // Delay slightly to allow layout calculations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0.0);
      
      const speed = 35.0; // Pixels per second
      final maxScroll = _scrollController.position.maxScrollExtent;
      final duration = Duration(seconds: (maxScroll / speed).round() + 2);

      _animateScroll(maxScroll, duration);
    });
  }

  void _animateScroll(double target, Duration duration) {
    if (!mounted || !_scrollController.hasClients || !_visible) return;
    _scrollController.animateTo(
      target,
      duration: duration,
      curve: Curves.linear,
    ).then((_) {
      if (mounted && _visible && _scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
        final maxScroll = _scrollController.position.maxScrollExtent;
        _animateScroll(maxScroll, duration);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.12),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: AppPanel(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            borderColor: Colors.blueAccent.withOpacity(0.25),
            backgroundColor: const Color(0xFF0F0F1A).withOpacity(0.85),
            child: Row(
              children: [
                // Glowing info badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'ЖКХ ${_satisfactionJkh}% · АДМ ${_satisfactionAdmin}%',
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Marquee running text view
                Expanded(
                  child: SizedBox(
                    height: 20,
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 1,
                      itemBuilder: (context, index) {
                        return Center(
                          child: Text(
                            _tickerText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
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
