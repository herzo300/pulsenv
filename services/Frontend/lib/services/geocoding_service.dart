// lib/services/geocoding_service.dart
//
// Геокодирование: координаты → читаемый адрес.
//
// На базе пакета geocoding (OSM Nominatim под капотом, без API-ключа).
// Применение:
//   • Авто-подстановка адреса в форме жалобы/находки из GPS.
//   • Снижение трения: пользователю не надо печатать адрес вручную.
//
// Премиум-функционал: convenience для VIP (быстрое создание жалоб).
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

/// Результат обратного геокодирования.
class GeocodedAddress {
  const GeocodedAddress({
    this.street,
    this.number,
    this.locality,
    this.subLocality,
    this.postalCode,
    this.adminArea,
    this.country,
    this.fullAddress,
    this.lat,
    this.lng,
  });

  final String? street;
  final String? number;
  final String? locality;
  final String? subLocality;
  final String? postalCode;
  final String? adminArea;
  final String? country;
  final String? fullAddress;
  final double? lat;
  final double? lng;

  /// Короткая читаемая форма: «ул. Ленина, 15».
  String get short {
    final parts = <String>[];
    final streetWithNumber = [
      if (street != null && street!.isNotEmpty) street,
      if (number != null && number!.isNotEmpty) number,
    ].join(', ');
    if (streetWithNumber.isNotEmpty) parts.add(streetWithNumber);
    if (parts.isEmpty && (subLocality?.isNotEmpty ?? false)) {
      parts.add(subLocality!);
    }
    return parts.isEmpty ? (fullAddress ?? '') : parts.join(', ');
  }

  /// Полная форма с городом: «Нижневартовск, ул. Ленина, 15».
  String get full {
    final parts = <String>[];
    if (locality != null && locality!.isNotEmpty) parts.add(locality!);
    final rest = short;
    if (rest.isNotEmpty) parts.add(rest);
    return parts.join(', ');
  }

  bool get isValid => short.isNotEmpty;
}

/// Простой record-результат forward-geocode.
class GeocodedPoint {
  const GeocodedPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  final Geocoding _geocoding = Geocoding();

  /// Reverse-geocode: координаты → адрес.
  Future<GeocodedAddress?> reverseGeocode({
    required double lat,
    required double lng,
    String localeIdentifier = 'ru_RU',
  }) async {
    try {
      _geocoding.setLocaleIdentifier(localeIdentifier);
      final placemarks = await _geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      return GeocodedAddress(
        street: p.street,
        number: p.name,
        locality: p.locality,
        subLocality: p.subLocality,
        postalCode: p.postalCode,
        adminArea: p.administrativeArea,
        country: p.country,
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      debugPrint('[Geocoding] reverse failed ($lat,$lng): $e');
      return null;
    }
  }

  /// Forward-geocode: адрес → координаты.
  Future<GeocodedPoint?> forwardGeocode(String address) async {
    try {
      final locations = await _geocoding.locationFromAddress(address);
      if (locations.isEmpty) return null;
      final l = locations.first;
      return GeocodedPoint(lat: l.latitude, lng: l.longitude);
    } catch (e) {
      debugPrint('[Geocoding] forward failed ($address): $e');
      return null;
    }
  }

  /// Быстрый короткий адрес одной строкой.
  Future<String> shortAddress(double lat, double lng) async {
    final g = await reverseGeocode(lat: lat, lng: lng);
    return g?.short ?? '';
  }
}
