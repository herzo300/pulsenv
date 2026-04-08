/// Configuration for the main map surface.
///
/// Uses classic OpenStreetMap tiles with street labels and the Timeweb-hosted backend.
library;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

const LatLng kMapCenterDefault = LatLng(60.9344, 76.5531);

const double kMapInitialZoom = 13.0;
const double kMapMinZoom = 10.0;
const double kMapMaxZoom = 18.0;

const String kOsmTileUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kOsmUserAgent = 'com.soobshio.app';
const String kOsmAttributionText = 'OpenStreetMap contributors';
const String kOsmCopyrightUrl = 'https://www.openstreetmap.org/copyright';
const String kReportsMediaBucket = 'reports-media';
const String kSatelliteTileUrlDefault =
    'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';

String _backendBaseUrl =
    const String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
const String _defaultPublicBackendBaseUrl = String.fromEnvironment(
  'BACKEND_PUBLIC_FALLBACK',
  defaultValue: 'http://45.153.68.59',
);
String _satelliteTileUrl = const String.fromEnvironment(
  'SATELLITE_TILE_URL',
  defaultValue: kSatelliteTileUrlDefault,
);

const Map<String, String> kCityCamsStreams = {
  '60 лет Октября, 3':
      'https://stream3.dantser.org/NV_60Let_3/tracks-v1/mono.ts.m3u8',
  '60 лет Октября, 10':
      'https://stream3.dantser.org/NV_60Let_10/tracks-v1/mono.ts.m3u8',
  'Героев Самотлора, 18': 'https://nginx02.pride-net.ru/geroi18/index.m3u8',
};

class MapConfig {
  static String get tileUrl => kOsmTileUrl;
  static String get defaultPublicBackendBaseUrl =>
      _defaultPublicBackendBaseUrl.trim();
  static String get satelliteTileUrl => _satelliteTileUrl.trim().isNotEmpty
      ? _satelliteTileUrl.trim()
      : kOsmTileUrl;
  static String get userAgent => kOsmUserAgent;

  static double get initialZoom => kMapInitialZoom;
  static double get minZoom => kMapMinZoom;
  static double get maxZoom => kMapMaxZoom;
  static String get satelliteUrl => satelliteTileUrl;

  static String get backendBaseUrl {
    final configured = _backendBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    if (kIsWeb && Uri.base.hasAuthority) {
      return Uri.base.origin;
    }
    return _defaultPublicBackendBaseUrl;
  }

  static String get backendApiBaseUrl => '$backendBaseUrl/api';
  static String get backendStorageBaseUrl => '$backendApiBaseUrl/storage';
  static String get reportsApiUrl => '$backendApiBaseUrl/reports';
  static String get reportsMediaBucket => kReportsMediaBucket;
  static String get opendataSummariesApiUrl =>
      '$backendApiBaseUrl/opendata_summaries';
  static Map<String, String> get cityCams => kCityCamsStreams;

  static bool get hasBackendConfig {
    if (_backendBaseUrl.trim().isNotEmpty) {
      return true;
    }
    if (kIsWeb && Uri.base.hasAuthority) {
      return true;
    }
    return _defaultPublicBackendBaseUrl.trim().isNotEmpty;
  }

  static void applyBackendConfig({
    required String url,
  }) {
    final normalized = url.trim();
    if (normalized.isNotEmpty) {
      _backendBaseUrl = normalized;
    }
  }

  static String storageUploadUrl(String bucket, String objectPath) {
    final encodedPath =
        objectPath.split('/').map(Uri.encodeComponent).join('/');
    return '$backendStorageBaseUrl/object/$bucket/$encodedPath';
  }

  static String storagePublicUrl(String bucket, String objectPath) {
    return storageUploadUrl(bucket, objectPath);
  }
}
