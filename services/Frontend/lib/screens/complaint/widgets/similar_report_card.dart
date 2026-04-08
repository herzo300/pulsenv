import 'package:flutter/material.dart';

class SimilarReportCard extends StatelessWidget {
  const SimilarReportCard({
    super.key,
    required this.checkingSimilar,
    this.similarReport,
    required this.defaultCategory,
    required this.onSupport,
  });

  final bool checkingSimilar;
  final Map<String, dynamic>? similarReport;
  final String defaultCategory;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    if (checkingSimilar) {
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

    if (similarReport == null) return const SizedBox.shrink();

    final report = similarReport!;
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
            '${report['category'] ?? defaultCategory} • ${distanceMeters ?? 'рядом'} м • адрес: ${report['address'] ?? 'не указан'}',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSupport,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('У меня такая же'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Поддержали: $likes • присоединились: $supporters',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
