// lib/models/cluster.dart
class Cluster {
  final int id;
  final double lat;
  final double lon;
  final int complaintsCount;
  final List<dynamic> complaints;

  Cluster({
    required this.id,
    required this.lat,
    required this.lon,
    required this.complaintsCount,
    required this.complaints,
  });

  factory Cluster.fromJson(Map<String, dynamic> json) {
    return Cluster(
      id: json['cluster_id'],
      lat: (json['center_lat'] as num).toDouble(),
      lon: (json['center_lon'] as num).toDouble(),
      complaintsCount: json['complaints_count'],
      complaints: json['complaints'] ?? [],
    );
  }
}
