import 'package:flutter/material.dart';
import 'premium/pulse_liquid_glass.dart';
import 'dynamic_tile_background.dart';

/// Generative UI Renderer for LLM AI Digest Events
class GenerativeUiRenderer extends StatelessWidget {
  final Map<String, dynamic> jsonSpec;

  const GenerativeUiRenderer({super.key, required this.jsonSpec});

  @override
  Widget build(BuildContext context) {
    final componentType = jsonSpec['type'] as String? ?? 'card';
    final title = jsonSpec['title'] as String? ?? '';
    final body = jsonSpec['body'] as String? ?? '';
    final severity = jsonSpec['severity'] as String? ?? 'info';
    final metrics = jsonSpec['metrics'] as List<dynamic>? ?? [];

    switch (componentType) {
      case 'urgency_banner':
        return _buildUrgencyBanner(title, body, severity);
      case 'metric_summary':
        return _buildMetricSummary(title, metrics);
      case 'neighborhood_event':
        return _buildEventCard(title, body, jsonSpec);
      default:
        return _buildDefaultCard(title, body);
    }
  }

  Widget _buildUrgencyBanner(String title, String body, String severity) {
    final color = severity == 'critical'
        ? Colors.redAccent
        : (severity == 'warning' ? Colors.orangeAccent : Colors.cyanAccent);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSummary(String title, List<dynamic> metrics) {
    return PulseLiquidGlass(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: metrics.map((m) {
              final label = m['label'] as String? ?? '';
              final val = m['value'] as String? ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(val, style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.extrabold, fontSize: 18)),
                    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(String title, String body, Map<String, dynamic> spec) {
    final district = spec['district'] as String? ?? 'Нижневартовск';
    final weather = spec['weather'] == 'rain' ? TileWeather.rain : TileWeather.clear;

    return DynamicTileBackground(
      weather: weather,
      category: TileCategory.general,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(district, style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.w600, fontSize: 12)),
                const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.35)),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCard(String title, String body) {
    return PulseLiquidGlass(
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
