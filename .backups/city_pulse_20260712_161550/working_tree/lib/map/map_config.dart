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
const String kOsmUserAgent = 'ru.pulsgoroda.app';
const String kOsmAttributionText = 'OpenStreetMap contributors';
const String kOsmCopyrightUrl = 'https://www.openstreetmap.org/copyright';
const String kReportsMediaBucket = 'reports-media';
const String kSatelliteTileUrlDefault =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

String _backendBaseUrl =
    const String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
const String _publicApiBaseUrl = String.fromEnvironment(
  'PUBLIC_API_BASE_URL',
  defaultValue: '',
);
const String _defaultPublicBackendBaseUrl = String.fromEnvironment(
  'BACKEND_PUBLIC_FALLBACK',
  defaultValue: 'https://45-153-68-59.sslip.io',
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
  static List<Map<String, dynamic>> loadedCameras = [];

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
    final fromPublic = _normalizeBackendBaseUrl(_publicApiBaseUrl);
    if (fromPublic.isNotEmpty) {
      return fromPublic;
    }
    final configured = _backendBaseUrl.trim();
    if (configured.isNotEmpty) {
      return _normalizeBackendBaseUrl(configured);
    }
    if (kIsWeb && Uri.base.hasAuthority) {
      return Uri.base.origin;
    }
    return _normalizeBackendBaseUrl(_defaultPublicBackendBaseUrl);
  }

  static String _normalizeBackendBaseUrl(String raw) {
    var normalized = raw.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith('/api')) {
      normalized = normalized.substring(0, normalized.length - 4);
    }
    return normalized;
  }

  static String get backendApiBaseUrl => '$backendBaseUrl/api';
  static String get backendStorageBaseUrl => '$backendApiBaseUrl/storage';
  static String get reportsApiUrl => '$backendApiBaseUrl/reports';
  static String get reportsMediaBucket => kReportsMediaBucket;
  static String get opendataSummariesApiUrl =>
      '$backendApiBaseUrl/opendata_summaries';
  static Map<String, String> get cityCams => kCityCamsStreams;

  /// HLS playback URL for map cameras.
  /// Streams from pride-net.ru and dantser.org require Referer headers that
  /// the Android video_player plugin cannot inject per-segment. We route them
  /// through the backend proxy which adds the correct headers and rewrites the
  /// m3u8 playlist so all .ts segment URLs also go through the proxy.
  static String cameraPlaybackUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.contains('pride-net.ru') || lower.contains('dantser.org')) {
      return '$backendApiBaseUrl/cameras/proxy?url=${Uri.encodeComponent(trimmed)}';
    }
    return trimmed;
  }

  static String normalizeCameraStreamUrl(String rawUrl) {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) return normalized;
    final lower = normalized.toLowerCase();
    if (lower.contains('pride-net.ru') && !lower.contains('.m3u8')) {
      normalized = '${normalized.replaceAll(RegExp(r'/+$'), '')}/index.m3u8';
    }
    return normalized;
  }

  /// Raw HLS URL for server-side frame capture (unwraps /cameras/proxy?url=...).
  static String cameraAnalysisUrl(String playbackOrRawUrl) {
    final trimmed = playbackOrRawUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.path.contains('cameras/proxy')) {
      final inner = uri.queryParameters['url'];
      if (inner != null && inner.isNotEmpty) {
        return normalizeCameraStreamUrl(inner);
      }
    }
    return normalizeCameraStreamUrl(trimmed);
  }

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
