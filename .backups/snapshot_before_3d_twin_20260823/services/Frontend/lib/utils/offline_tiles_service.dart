import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:path_provider/path_provider.dart';

import 'cached_tile_provider.dart';
import 'fast_pmtiles_tile_provider.dart';
import '../services/city_provider.dart';

/// Сервис оффлайн-карты и тайлов.
///
/// 1. При наличии локального .pmtiles файла использует высокопроизводительный FastPmTilesTileProvider.
/// 2. Иначе использует надёжные онлайн-сервера с автоматическим дисковым кэшированием (CachedTileProvider):
///    - День: OpenStreetMap (https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png)
///    - Ночь: CartoDB Dark Matter (https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png)
///    - Спутник: Esri World Imagery
class OfflineTilesService extends ChangeNotifier {
  static final OfflineTilesService instance = OfflineTilesService._init();
  bool _hasOfflineFile = false;
  bool _offlineDisabled = false;
  PmTilesArchive? _archive;

  OfflineTilesService._init();

  bool get hasOfflineFile => _hasOfflineFile && !_offlineDisabled;

  void disableOffline() {
    if (!_offlineDisabled) {
      _offlineDisabled = true;
      notifyListeners();
    }
  }

  void enableOffline() {
    if (_offlineDisabled) {
      _offlineDisabled = false;
      notifyListeners();
    }
  }

  Future<void> initOfflineTiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nizhnevartovsk.pmtiles');
      
      if (await file.exists()) {
        final len = await file.length();
        if (len >= 5 * 1024 * 1024) {
          _archive = await PmTilesArchive.from(file.path);
          _hasOfflineFile = true;
          _offlineDisabled = false;
          debugPrint('OfflineTilesService: Loaded PMTiles archive successfully ($len bytes).');
        } else {
          debugPrint('OfflineTilesService: File size too small ($len bytes), removing stub.');
          try {
            await file.delete();
          } catch (_) {}
          _hasOfflineFile = false;
          _archive = null;
        }
      } else {
        _hasOfflineFile = false;
        _archive = null;
      }
    } catch (e) {
      debugPrint('OfflineTilesService init error: $e');
      _hasOfflineFile = false;
      _archive = null;
    }
    try {
      CachedTileProvider.configureImageCache();
    } catch (_) {}
    notifyListeners();
  }

  /// OpenStreetMap с распределёнными субдоменами (100% доступность в РФ)
  static const String kDayTileUrl =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// CartoDB Dark Matter для тёмной темы
  static const String kNightTileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png';

  /// Esri World Imagery для спутникового режима
  static const String kSatelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  static const List<String> kOsmSubdomains = ['a', 'b', 'c'];
  static const List<String> kCartoSubdomains = ['a', 'b', 'c', 'd'];

  TileLayer getTileLayer(String urlTemplate, {bool isNightMode = false}) {
    final activeCityId = CityProvider().activeCity.id;
    final isSatelliteUrl = urlTemplate.contains('arcgisonline') || urlTemplate.contains('satellite');
    
    // Приоритет 1: PMTiles-архив (если загружен пользователем)
    if (_hasOfflineFile && !_offlineDisabled && activeCityId == 'nizhnevartovsk' && !isSatelliteUrl) {
      if (_archive != null) {
        return TileLayer(
          urlTemplate: 'pmtiles://{z}/{x}/{y}',
          tileProvider: FastPmTilesTileProvider(archive: _archive!),
          tileDisplay: const TileDisplay.instantaneous(),
          keepBuffer: 3,
          panBuffer: 1,
          maxZoom: 19.0,
          maxNativeZoom: 19,
          retinaMode: false,
          evictErrorTileStrategy: EvictErrorTileStrategy.none,
          errorTileCallback: (tile, error, stackTrace) {},
        );
      }
    }
    
    // Приоритет 2: Онлайн-тайлы с мгновенным рендером без мерцаний
    String effectiveUrl;
    List<String> subdomains;

    if (isSatelliteUrl) {
      effectiveUrl = kSatelliteTileUrl;
      subdomains = const [];
    } else if (urlTemplate.contains('openstreetmap') || !isNightMode) {
      effectiveUrl = kDayTileUrl;
      subdomains = List<String>.from(kOsmSubdomains);
    } else {
      effectiveUrl = kNightTileUrl;
      subdomains = List<String>.from(kCartoSubdomains);
    }

    return TileLayer(
      urlTemplate: effectiveUrl,
      subdomains: subdomains,
      userAgentPackageName: 'ru.pulsgoroda.app',
      maxZoom: 19.0,
      maxNativeZoom: 19,
      retinaMode: false,
      tileProvider: CachedTileProvider(),
      tileDisplay: const TileDisplay.instantaneous(),
      keepBuffer: 3,
      panBuffer: 1,
      evictErrorTileStrategy: EvictErrorTileStrategy.none,
      errorTileCallback: (tile, error, stackTrace) {},
    );
  }
}
