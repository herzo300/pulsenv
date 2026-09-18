import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationTrack {
  final String id;
  final String name;
  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
  final DateTime date;

  NavigationTrack({
    required this.id,
    required this.name,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'points': points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'distanceMeters': distanceMeters,
        'durationSeconds': durationSeconds,
        'date': date.toIso8601String(),
      };

  factory NavigationTrack.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List)
        .map((p) => LatLng(
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ))
        .toList();

    return NavigationTrack(
      id: json['id'] as String,
      name: json['name'] as String,
      points: pts,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class NavigationHistoryService {
  NavigationHistoryService._();
  static final NavigationHistoryService instance = NavigationHistoryService._();

  static const String _storageKey = 'soobshio_nav_tracks';

  StreamSubscription<Position>? _positionSubscription;
  final List<LatLng> _currentTrackPoints = [];
  DateTime? _trackingStartTime;
  double _currentDistance = 0.0;
  bool _isTracking = false;

  final _trackStreamController = StreamController<List<LatLng>>.broadcast();

  bool get isTracking => _isIsTracking();
  List<LatLng> get currentTrackPoints => List.unmodifiable(_currentTrackPoints);
  Stream<List<LatLng>> get currentTrackStream => _trackStreamController.stream;

  bool _isIsTracking() {
    return _isTracking;
  }

  Future<List<NavigationTrack>> getTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return [];
      final list = json.decode(raw) as List;
      return list.map((item) => NavigationTrack.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('NavigationHistoryService: Error loading tracks: $e');
      return [];
    }
  }

  Future<void> saveTrack(NavigationTrack track) async {
    try {
      final tracks = await getTracks();
      tracks.insert(0, track); // Add new track at the top
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json.encode(tracks.map((t) => t.toJson()).toList()));
    } catch (e) {
      debugPrint('NavigationHistoryService: Error saving track: $e');
    }
  }

  Future<void> deleteTrack(String id) async {
    try {
      final tracks = await getTracks();
      tracks.removeWhere((t) => t.id == id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json.encode(tracks.map((t) => t.toJson()).toList()));
    } catch (e) {
      debugPrint('NavigationHistoryService: Error deleting track: $e');
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    // Check permissions
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      debugPrint('NavigationHistoryService: Location permission not granted');
      return;
    }

    _currentTrackPoints.clear();
    _currentDistance = 0.0;
    _trackingStartTime = DateTime.now();
    _isTracking = true;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Receive updates every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      final newPoint = LatLng(pos.latitude, pos.longitude);
      if (_currentTrackPoints.isNotEmpty) {
        final lastPoint = _currentTrackPoints.last;
        final dist = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
        _currentDistance += dist;
      }
      _currentTrackPoints.add(newPoint);
      _trackStreamController.add(_currentTrackPoints);
    });

    debugPrint('NavigationHistoryService: Started track recording.');
  }

  Future<NavigationTrack?> stopTracking() async {
    if (!_isTracking) return null;

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;

    if (_currentTrackPoints.length < 2) {
      _currentTrackPoints.clear();
      _currentDistance = 0.0;
      return null;
    }

    final durationSec = DateTime.now().difference(_trackingStartTime!).inSeconds;
    final now = DateTime.now();
    final dateLabel = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final name = 'Маршрут от $dateLabel';

    final track = NavigationTrack(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      points: List.from(_currentTrackPoints),
      distanceMeters: _currentDistance,
      durationSeconds: durationSec,
      date: now,
    );

    await saveTrack(track);

    _currentTrackPoints.clear();
    _currentDistance = 0.0;

    debugPrint('NavigationHistoryService: Stopped tracking. Saved route "${track.name}" (${track.points.length} points).');
    return track;
  }
}
