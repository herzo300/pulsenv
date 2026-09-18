// Typed models for Flutter app — replaces Map with dynamic keys throughout the codebase.

/// Represents a citizen complaint/report on the map.
class Complaint {
  final int id;
  final String? title;
  final String? description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String? status;
  final int? userId;
  final List<String> images;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? verificationScore;

  const Complaint({
    required this.id,
    this.title,
    this.description,
    this.address,
    this.latitude,
    this.longitude,
    this.category,
    this.status,
    this.userId,
    this.images = const [],
    this.createdAt,
    this.updatedAt,
    this.verificationScore,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String?,
      description: json['description'] as String?,
      address: json['address'] as String?,
      latitude: _toDouble(json['lat'] ?? json['latitude']),
      longitude: _toDouble(json['lng'] ?? json['longitude']),
      category: json['category'] as String?,
      status: json['status'] as String?,
      userId: json['user_id'] as int?,
      images: _parseStringList(json['images']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      verificationScore: _toDouble(json['verification_score']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'status': status,
      'user_id': userId,
      'images': images,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'verification_score': verificationScore,
    };
  }

  bool get hasLocation => latitude != null && longitude != null;
  bool get isOpen => status == 'open' || status == 'новая';
  bool get isResolved => status == 'resolved' || status == 'решена';
}

/// Represents a city camera for live streaming.
class Camera {
  final String id;
  final String name;
  final String? street;
  final String? district;
  final String? streamUrl;
  final double? latitude;
  final double? longitude;
  final String? provider;
  final String? viewDesc;
  final int viewAngle;
  final bool isOnline;

  const Camera({
    required this.id,
    required this.name,
    this.street,
    this.district,
    this.streamUrl,
    this.latitude,
    this.longitude,
    this.provider,
    this.viewDesc,
    this.viewAngle = 90,
    this.isOnline = true,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id']?.toString() ?? json['s']?.toString() ?? '',
      name: json['n'] as String? ?? json['name'] as String? ?? 'Камера',
      street: json['street'] as String? ?? json['st'] as String?,
      district: json['district'] as String? ?? json['d'] as String?,
      streamUrl: json['s'] as String? ?? json['stream_url'] as String?,
      latitude: _toDouble(json['lat'] ?? json['latitude']),
      longitude: _toDouble(json['lng'] ?? json['longitude']),
      provider: json['provider'] as String? ?? json['p'] as String?,
      viewDesc: json['view_desc'] as String? ?? json['view_type'] as String?,
      viewAngle: json['view_angle'] as int? ?? 90,
      isOnline: json['online'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'street': street,
      'district': district,
      'stream_url': streamUrl,
      'latitude': latitude,
      'longitude': longitude,
      'provider': provider,
      'view_desc': viewDesc,
      'view_angle': viewAngle,
      'online': isOnline,
    };
  }

  bool get hasLocation => latitude != null && longitude != null;
}

/// Aggregated city statistics.
class CityStats {
  final int total;
  final int resolved;
  final int active;

  const CityStats({
    required this.total,
    required this.resolved,
    required this.active,
  });

  factory CityStats.fromJson(Map<String, dynamic> json) {
    return CityStats(
      total: json['total'] as int? ?? 0,
      resolved: json['resolved'] as int? ?? 0,
      active: json['active'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'resolved': resolved,
      'active': active,
    };
  }
}

// ── Helper utilities ──────────────────────────────────────────────

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<String> _parseStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.map((e) => e.toString()).toList();
  return [];
}
