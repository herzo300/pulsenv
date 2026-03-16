/// Configuration for the main map surface.
///
/// Uses the official OpenStreetMap tile layer.
library;

import 'package:latlong2/latlong.dart';

const LatLng kMapCenterDefault = LatLng(60.9344, 76.5531);

const double kMapInitialZoom = 13.0;
const double kMapMinZoom = 10.0;
const double kMapMaxZoom = 18.0;

const String kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kOsmUserAgent = 'com.soobshio.app';
const String kOsmAttributionText = 'OpenStreetMap contributors';
const String kOsmCopyrightUrl = 'https://www.openstreetmap.org/copyright';
const String kSupabaseReportsMediaBucket = 'reports-media';
const String kSatelliteTileUrlDefault = '';

String _supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
String _supabaseAnonKey =
    const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
String _satelliteTileUrl =
    const String.fromEnvironment('SATELLITE_TILE_URL', defaultValue: kSatelliteTileUrlDefault);

const Map<String, String> kCityCamsStreams = {
  '60 лет Октября, 3': 'https://stream3.dantser.org/NV_60Let_3/tracks-v1/mono.ts.m3u8',
  '60 лет Октября, 10': 'https://stream3.dantser.org/NV_60Let_10/tracks-v1/mono.ts.m3u8',
  'Героев Самотлора, 18': 'https://nginx02.pride-net.ru/geroi18/index.m3u8',
};

class MapConfig {
  const MapConfig._();

  static LatLng get center => kMapCenterDefault;
  static double get initialZoom => kMapInitialZoom;
  static double get minZoom => kMapMinZoom;
  static double get maxZoom => kMapMaxZoom;
  static String get tileUrl => kOsmTileUrl;
  static String get satelliteUrl =>
      _satelliteTileUrl.trim().isNotEmpty ? _satelliteTileUrl.trim() : kOsmTileUrl;
  static String get userAgent => kOsmUserAgent;

  static bool get hasSupabaseConfig =>
      _supabaseUrl.trim().isNotEmpty && _supabaseAnonKey.trim().isNotEmpty;

  static String get supabaseUrl => _supabaseUrl.trim();
  static String get supabaseRestBaseUrl => '$supabaseUrl/rest/v1';
  static String get supabaseStorageBaseUrl => '$supabaseUrl/storage/v1';
  static String get reportsRestUrl => '$supabaseRestBaseUrl/reports';
  static String get reportsMediaBucket => kSupabaseReportsMediaBucket;
  static Map<String, String> get cityCams => kCityCamsStreams;
  static String get supabaseAnonKey => _supabaseAnonKey.trim();

  static void applySupabaseConfig({
    required String url,
    required String anonKey,
  }) {
    final normalizedUrl = url.trim().replaceFirst(RegExp(r'/$'), '');
    final normalizedKey = anonKey.trim();
    if (normalizedUrl.isNotEmpty) {
      _supabaseUrl = normalizedUrl;
    }
    if (normalizedKey.isNotEmpty) {
      _supabaseAnonKey = normalizedKey;
    }
  }

  static String storageUploadUrl(String bucket, String objectPath) {
    final encodedPath = objectPath.split('/').map(Uri.encodeComponent).join('/');
    return '$supabaseStorageBaseUrl/object/$bucket/$encodedPath';
  }

  static String storagePublicUrl(String bucket, String objectPath) {
    final encodedPath = objectPath.split('/').map(Uri.encodeComponent).join('/');
    return '$supabaseStorageBaseUrl/object/public/$bucket/$encodedPath';
  }
}
