import 'package:flutter/material.dart';

class DetectionSummaryCard extends StatelessWidget {
  const DetectionSummaryCard({
    super.key,
    required this.detectedObjects,
    required this.searchPrompt,
    required this.isSearchCategory,
  });

  final List<dynamic> detectedObjects;
  final String? searchPrompt;
  final bool isSearchCategory;

  @override
  Widget build(BuildContext context) {
    if (detectedObjects.isEmpty) return const SizedBox.shrink();

    final accent =
        isSearchCategory ? const Color(0xFF4ADE80) : const Color(0xFF00E5FF);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10181C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(130)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSearchCategory
                ? '\u041f\u043e\u0434\u0441\u043a\u0430\u0437\u043a\u0438 \u0434\u043b\u044f \u043f\u043e\u0438\u0441\u043a\u0430'
                : '\u041e\u0431\u043d\u0430\u0440\u0443\u0436\u0435\u043d\u043e \u043d\u0430 \u0444\u043e\u0442\u043e',
            style: TextStyle(
                color: accent, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          if (searchPrompt != null) ...[
            const SizedBox(height: 6),
            Text(searchPrompt!,
                style: const TextStyle(color: Colors.white70, height: 1.35)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: detectedObjects
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(24),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accent.withAlpha(90)),
                      ),
                      child: Text(
                        '${item.displayLabel} ${(item.confidence * 100).round()}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
