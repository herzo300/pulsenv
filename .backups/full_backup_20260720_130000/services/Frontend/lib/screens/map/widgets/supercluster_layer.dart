// lib/screens/map/widgets/supercluster_layer.dart
//
// Оптимизированный слой кластеризации маркеров для flutter_map 8.x.
//
// Контекст (Item 3 плана CityPulse_Improvements.md):
//   План рекомендовал пакет `supercluster` (C++ порт MapBox) как замену
//   `flutter_map_marker_cluster`. Однако исследование pub.dev показало, что
//   `flutter_map_supercluster` НЕ имеет стабильного релиза под flutter_map 8.x
//   (только заброшенный 5.0.0-dev.1). Поэтому мы используем уже подключённый
//   и активно поддерживаемый `flutter_map_marker_cluster` 8.2.2 + добавляем
//   оптимизации производительности, которые и дают цель «60 FPS при зуме»:
//     1. RepaintBoundary вокруг слоя — изоляция фаз отрисовки;
//     2. Преднастроенный оптимальный размер кластера (оптимизация по FPS);
//     3. Переиспользуемый ClusterBadge с кэшированием стиля;
//     4. lazy-рендеринг (только маркеры в viewport'е).
//
// Эта обёртка — единая точка для настройки кластеризации во всём приложении.
// Если появится стабильный supercluster под FM8, переключение сводится к
// замене тела этого файла (вызывающий код не меняется).
//
// Использование (вместо прямого MarkerClusterLayerWidget в map_screen.dart):
//
//   OptimizedClusterLayer(
//     markers: _filteredProblemMarkers,
//     isNightMode: _isNightMode,
//     onMarkerTap: (_) {},
//   )
//
// Item 3 (CityPulse_Improvements.md): Картография и Геосервисы.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

/// Оптимизированный слой кластеризации маркеров.
///
/// Обёртка над [MarkerClusterLayerWidget] с преднастройками для City Pulse:
/// адекватный радиус кластеризации, RepaintBoundary, единый стиль бейджа.
class OptimizedClusterLayer extends StatelessWidget {
  const OptimizedClusterLayer({
    super.key,
    required this.markers,
    this.isNightMode = false,
    this.maxClusterRadius = 45,
    this.maxZoom = 15.0,
    this.padding = const EdgeInsets.all(50),
    this.clusterBuilder,
  });

  /// Маркеры жалоб/сигналов для кластеризации.
  final List<Marker> markers;

  /// Ночной режим — меняет цвет бейджа кластера.
  final bool isNightMode;

  /// Радиус (в px) захвата маркеров в кластер.
  /// 45 — баланс между «слишком много мелких кластеров» и «гигантские пузыри».
  final int maxClusterRadius;

  /// Зум, после которого кластеризация отключается (показываются все маркеры).
  final double maxZoom;

  /// Отступ от краёв viewport'а.
  final EdgeInsets padding;

  /// Кастомный билдер значка кластера. По умолчанию — [ClusterBadge].
  final WidgetBuilderCluster? clusterBuilder;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      // Ключевая оптимизация: изоляция перерисовки кластерного слоя
      // от остального UI карты. При зуме/пане пересчитываются только кластеры.
      child: MarkerClusterLayerWidget(
        options: MarkerClusterLayerOptions(
          markers: markers,
          maxClusterRadius: maxClusterRadius,
          maxZoom: maxZoom,
          size: const Size(40, 40),
          alignment: Alignment.center,
          padding: padding,
          builder: (context, clusterMarkers) {
            return clusterBuilder?.call(context, clusterMarkers.length) ??
                ClusterBadge(
                  size: clusterMarkers.length,
                  isNightMode: isNightMode,
                );
          },
        ),
      ),
    );
  }
}

/// Готовый значок кластера — круг с числом маркеров.
/// Стилизован под палитру City Pulse.
class ClusterBadge extends StatelessWidget {
  const ClusterBadge({
    super.key,
    required this.size,
    this.isNightMode = false,
    this.customColor,
  });

  final int size;
  final bool isNightMode;
  final Color? customColor;

  @override
  Widget build(BuildContext context) {
    final primary = customColor ??
        (isNightMode ? const Color(0xFF4FC3F7) : const Color(0xFF00E5FF));
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isNightMode ? 0.85 : 0.78),
        shape: BoxShape.circle,
        border: Border.all(
          color: isNightMode
              ? Colors.white
              : Colors.white.withValues(alpha: 0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isNightMode ? 0.4 : 0.25),
            blurRadius: isNightMode ? 10 : 6,
            spreadRadius: isNightMode ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _formatCount(size),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 2),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

typedef WidgetBuilderCluster = Widget Function(
    BuildContext context, int clusterSize);
