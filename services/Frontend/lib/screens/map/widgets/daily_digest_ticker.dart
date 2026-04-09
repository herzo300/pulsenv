import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../map/map_config.dart';
import '../../../theme/pulse_colors.dart';

class DailyDigestTicker extends StatefulWidget {
  const DailyDigestTicker({super.key});

  @override
  State<DailyDigestTicker> createState() => _DailyDigestTickerState();
}

class _DailyDigestTickerState extends State<DailyDigestTicker>
    with SingleTickerProviderStateMixin {
  String _digestText = 'Загрузка сводки дня...';
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _fetchDigest();
  }

  Future<void> _fetchDigest() async {
    try {
      final response = await http
          .get(
            Uri.parse('${MapConfig.backendApiBaseUrl}/daily-digest'),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _digestText =
                data['ai_summary'] ?? 'Новых сигналов за сегодня нет.';
          });
        } else {
          setState(() {
            _digestText = 'Сводка за день формируется...';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _digestText = 'Сводка недоступна (офлайн).';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PulseColors.primary.withAlpha(220),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.yellowAccent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            // Для простой бегущей строки или прокрутки можно использовать SingleChildScrollView + marquee_widget
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                _digestText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _isVisible = false;
              });
            },
            child: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }
}
