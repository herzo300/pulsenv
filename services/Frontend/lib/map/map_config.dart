/// Конфигурация основной карты приложения.
///
/// Используется бесплатная подложка OpenStreetMap (без API-ключей).
/// Соответствие Tile Usage Policy: https://operations.osmfoundation.org/policies/tiles/
library;

import 'package:latlong2/latlong.dart';

/// Центр карты по умолчанию — Нижневартовск
const LatLng kMapCenterDefault = LatLng(60.9344, 76.5531);

/// Начальный и допустимые уровни зума
const double kMapInitialZoom = 13.0;
const double kMapMinZoom = 10.0;
const double kMapMaxZoom = 18.0;

/// Бесплатный тайловый слой OpenStreetMap (официальный).
/// Обязательно указывать [kOsmUserAgent] в TileLayer.
const String kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

const String kGoogleSatelliteUrl = 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';

/// User-Agent для запросов к OSM (требование Tile Usage Policy).
const String kOsmUserAgent = 'com.soobshio.app';

/// Текст атрибуции для OSM (обязателен к отображению).
const String kOsmAttributionText = 'OpenStreetMap contributors';

/// URL страницы копирайта OSM (для onTap атрибуции).
const String kOsmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

const Map<String, String> kCityCamsStreams = {
  '60 лет Октября, 3': 'https://stream3.dantser.org/NV_60Let_3/tracks-v1/mono.ts.m3u8',
  '60 лет Октября, 10': 'https://stream3.dantser.org/NV_60Let_10/tracks-v1/mono.ts.m3u8',
  'Героев Самотлора, 18': 'https://nginx02.pride-net.ru/geroi18/index.m3u8',
};

/// Supabase URL (для REST API и Storage).
const String kSupabaseUrl = 'https://xpainxohbdoruakcijyq.supabase.co';

/// Supabase anon key для публичных запросов.
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';

/// Конфиг карты для единого места настроек
class MapConfig {
  const MapConfig._();

  static LatLng get center => kMapCenterDefault;
  static double get initialZoom => kMapInitialZoom;
  static double get minZoom => kMapMinZoom;
  static double get maxZoom => kMapMaxZoom;
  static String get tileUrl => kOsmTileUrl;
  static String get satelliteUrl => kGoogleSatelliteUrl;
  static String get userAgent => kOsmUserAgent;
  static String get supabaseUrl => kSupabaseUrl;
  static Map<String, String> get cityCams => kCityCamsStreams;
  static String get supabaseAnonKey => kSupabaseAnonKey;
}
