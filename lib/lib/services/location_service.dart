// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

/// Сервис геолокации
class LocationService {
  /// Запрос разрешений
  static Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }
  
  /// Получение текущей позиции
  static Future<LatLng?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
  
  /// Получение позиции с таймаутом
  static Future<LatLng?> getLocationWithTimeout({int seconds = 10}) async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(Duration(seconds: seconds));
      
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
  
  /// Поток позиций
  static Stream<Position>? getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // метров
      ),
    );
  }
  
  /// Расстояние между точками
  static double distanceBetween(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
  
  /// Проверка, находится ли точка в радиусе
  static bool isWithinRadius(LatLng center, LatLng point, double radiusMeters) {
    final distance = distanceBetween(center, point);
    return distance <= radiusMeters;
  }
  
  /// Фильтрация точек по радиусу
  static List<T> filterByRadius<T>({
    required LatLng center,
    required List<T> items,
    required LatLng Function(T) getLocation,
    required double radiusMeters,
  }) {
    return items.where((item) {
      final location = getLocation(item);
      return isWithinRadius(center, location, radiusMeters);
    }).toList();
  }
  
  /// Адрес из координат (обратное геокодирование)
  static Future<String?> reverseGeocode(LatLng location) async {
    // TODO: Интеграция с Nominatim
    // Сейчас возвращаем null
    return null;
  }
}
