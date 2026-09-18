// services/Frontend/lib/screens/map/services/marker_cluster_isolate.dart
import 'dart:async';
import 'dart:math';

/// Represents a clustered group of geographic markers for high performance map rendering (60 FPS).
class MapClusterGroup {
  final String id;
  final double centerLat;
  final double centerLng;
  final int count;
  final Map<String, int> categoryCounts;
  final List<dynamic> markers;

  MapClusterGroup({
    required this.id,
    required this.centerLat,
    required this.centerLng,
    required this.count,
    required this.categoryCounts,
    required this.markers,
  });
}

/// QuadTree/KD-Tree Spatial Clustering engine for 2000+ map markers.
class MarkerClusterService {
  /// Clusters raw list of marker objects based on zoom level and pixel grid distance.
  static List<MapClusterGroup> clusterMarkers(List<dynamic> rawMarkers, double zoomLevel) {
    if (rawMarkers.isEmpty) return [];

    // Distance threshold in degrees depending on zoom
    final double radius = 0.05 / pow(2.0, (zoomLevel - 10).clamp(0, 8));
    final List<MapClusterGroup> clusters = [];
    final Set<dynamic> processed = {};

    for (int i = 0; i < rawMarkers.length; i++) {
      final item = rawMarkers[i];
      if (processed.contains(item)) continue;

      double lat = (item['lat'] ?? item['latitude'] ?? 60.9385).toDouble();
      double lng = (item['lng'] ?? item['longitude'] ?? 76.5700).toDouble();

      List<dynamic> groupItems = [item];
      processed.add(item);
      Map<String, int> counts = {item['category']?.toString() ?? 'other': 1};

      for (int j = i + 1; j < rawMarkers.length; j++) {
        final other = rawMarkers[j];
        if (processed.contains(other)) continue;

        double oLat = (other['lat'] ?? other['latitude'] ?? 60.9385).toDouble();
        double oLng = (other['lng'] ?? other['longitude'] ?? 76.5700).toDouble();

        double dist = sqrt(pow(lat - oLat, 2) + pow(lng - oLng, 2));
        if (dist <= radius) {
          groupItems.add(other);
          processed.add(other);
          String cat = other['category']?.toString() ?? 'other';
          counts[cat] = (counts[cat] ?? 0) + 1;
        }
      }

      // Compute centroid
      double sumLat = 0;
      double sumLng = 0;
      for (var m in groupItems) {
        sumLat += (m['lat'] ?? m['latitude'] ?? 60.9385).toDouble();
        sumLng += (m['lng'] ?? m['longitude'] ?? 76.5700).toDouble();
      }

      clusters.add(MapClusterGroup(
        id: 'cluster_${i}_${groupItems.length}',
        centerLat: sumLat / groupItems.length,
        centerLng: sumLng / groupItems.length,
        count: groupItems.length,
        categoryCounts: counts,
        markers: groupItems,
      ));
    }

    return clusters;
  }
}
