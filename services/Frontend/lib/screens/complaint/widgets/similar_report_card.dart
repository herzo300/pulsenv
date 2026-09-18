import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;

import '../../../map/map_config.dart';

class SimilarReportCard extends StatefulWidget {
  const SimilarReportCard({
    super.key,
    required this.checkingSimilar,
    this.similarReport,
    required this.defaultCategory,
    required this.onSupport,
    this.latitude,
    this.longitude,
  });

  final bool checkingSimilar;
  final Map<String, dynamic>? similarReport;
  final String defaultCategory;
  final VoidCallback onSupport;
  final double? latitude;
  final double? longitude;

  @override
  State<SimilarReportCard> createState() => _SimilarReportCardState();
}

class _SimilarReportCardState extends State<SimilarReportCard> {
  int _placeCount = -1;
  List<String> _recurring = const [];
  bool _placeLoaded = false;

  @override
  void didUpdateWidget(covariant SimilarReportCard old) {
    super.didUpdateWidget(old);
    final moved = old.latitude != widget.latitude || old.longitude != widget.longitude;
    if (moved && widget.latitude != null && widget.longitude != null) {
      _loadPlaceMemory();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.latitude != null && widget.longitude != null) {
      _loadPlaceMemory();
    }
  }

  Future<void> _loadPlaceMemory() async {
    try {
      final resp = await http
          .get(Uri.parse(
              '${MapConfig.backendApiBaseUrl}/reports/place-history?lat=${widget.latitude}&lng=${widget.longitude}&radius_m=250&limit=12'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _placeCount = (data['count'] as num?)?.toInt() ?? 0;
          _recurring = (data['recurring_categories'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          _placeLoaded = true;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.checkingSimilar) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF172032),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Expanded(
              child: Text('Проверяем, есть ли уже такая же проблема рядом...',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    }

    if (widget.similarReport == null && !_placeLoaded) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.similarReport != null) _buildSimilarCard(context),
        if (_placeLoaded && _placeCount > 0) ...[
          const SizedBox(height: 12),
          _buildPlaceMemoryCard(),
        ],
      ],
    );
  }

  Widget _buildSimilarCard(BuildContext context) {
    final report = widget.similarReport!;
    final distanceMeters = report['distance_meters'];
    final likes = report['likes_count'] ?? 0;
    final supporters = report['supporters'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2438),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E5FF).withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF00E5FF)),
              SizedBox(width: 10),
              Expanded(
                child: Text('Похоже, проблема уже отмечена',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (report['title'] as String?)?.trim().isNotEmpty == true
                ? report['title'] as String
                : (report['description'] as String?) ??
                    'Существующее обращение',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '${report['category'] ?? widget.defaultCategory} • ${distanceMeters ?? 'рядом'} м • адрес: ${report['address'] ?? 'не указан'}',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 12),

          // Dynamic interaction counters:
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.thumb_up_rounded, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 6),
                    Text('$likes', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Text('$supporters', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated pulse & shimmer button:
          SizedBox(
            width: double.infinity,
            child: Animate(
              effects: [
                ShimmerEffect(delay: const Duration(seconds: 1), duration: const Duration(seconds: 2)),
                ScaleEffect(begin: const Offset(1, 1), end: const Offset(1.03, 1.03), duration: const Duration(seconds: 1), curve: Curves.easeInOut),
              ],
              onPlay: (controller) => controller.repeat(),
              child: FilledButton.icon(
                onPressed: widget.onSupport,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('У меня такая же', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceMemoryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2438),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Память места: $_placeCount ${_placeCount == 1 ? 'сигнал' : 'сигналов'} здесь ранее',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          if (_recurring.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Повторяющаяся проблема ($_recurring) — лучше добавить обновление к существующей истории, чем создавать дубль.',
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
