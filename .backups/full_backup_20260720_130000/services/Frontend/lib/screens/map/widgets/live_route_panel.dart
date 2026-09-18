// lib/screens/map/widgets/live_route_panel.dart
//
// Извлечённая панель активного маршрута / навигации поверх карты.
// Показывает дистанцию, оставшееся время, скорость.
//
// RepaintBoundary — обновление таймера каждую секунду не перерисовывает карту.
//
// Item 6 (CityPulse_Improvements.md): UX/UI и Перформанс.
import 'package:flutter/material.dart';

import '../../../theme/pulse_colors.dart';

/// Данные активного маршрута.
class LiveRouteData {
  const LiveRouteData({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.speedMps,
    this.destinationName,
  });

  final double distanceMeters;
  final int durationSeconds;
  final double speedMps;
  final String? destinationName;

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} м';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} км';
  }

  String get durationLabel {
    final m = durationSeconds ~/ 60;
    if (m < 60) return '$m мин';
    final h = m ~/ 60;
    final remM = m % 60;
    return '$h ч $remM мин';
  }

  String get speedLabel {
    final kmh = speedMps * 3.6;
    if (kmh < 1) return '0 км/ч';
    return '${kmh.round()} км/ч';
  }
}

class LiveRoutePanel extends StatelessWidget {
  const LiveRoutePanel({
    super.key,
    required this.data,
    required this.onClose,
    this.onMinimize,
  });

  final LiveRouteData data;
  final VoidCallback onClose;
  final VoidCallback? onMinimize;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              PulseColors.primary.withValues(alpha: 0.95),
              PulseColors.primary.withValues(alpha: 0.78),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: PulseColors.primary.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.destinationName ?? 'Маршрут активен',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onMinimize != null)
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, color: Colors.white70),
                    onPressed: onMinimize,
                    splashRadius: 18,
                    iconSize: 18,
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: onClose,
                  splashRadius: 18,
                  iconSize: 18,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MetricChip(icon: Icons.straighten_rounded, value: data.distanceLabel),
                const SizedBox(width: 8),
                _MetricChip(icon: Icons.schedule_rounded, value: data.durationLabel),
                const SizedBox(width: 8),
                _MetricChip(icon: Icons.speed_rounded, value: data.speedLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
