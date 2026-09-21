import 'dart:async';
import 'dart:io';
import 'dart:math';
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
          final archive = await PmTilesArchive.from(file.path);
          // Валидация архива: только растровые тайлы (mvt/vector не поддерживаются
          // flutter_map) и пробное чтение тайла центра города. Битый или
          // векторный архив больше не подменяет онлайн-карту.
          final raster = archive.tileType == TileType.png ||
              archive.tileType == TileType.jpeg ||
              archive.tileType == TileType.webp;
          var probeOk = false;
          if (raster) {
            try {
              final z = archive.centerZoom.clamp(archive.minZoom, archive.maxZoom);
              // Тайл центра Нижневартовска (60.9344, 76.5531) на зуме архива
              final n = 1 << z;
              final x = ((76.5531 + 180.0) / 360.0 * n).floor();
              final latRad = 60.9344 * 3.141592653589793 / 180.0;
              final y = ((1.0 - (log(tan(latRad) + 1.0 / cos(latRad)) / 3.141592653589793)) / 2.0 * n).floor();
              final t = await archive.tile(ZXY(z, x, y).toTileId());
              probeOk = t.bytes().isNotEmpty;
            } catch (_) {
              probeOk = false;
            }
          }
          if (raster && probeOk) {
            _archive = archive;
            _hasOfflineFile = true;
            _offlineDisabled = false;
            debugPrint('OfflineTilesService: PMTiles OK ($len bytes, z${archive.minZoom}-${archive.maxZoom}).');
            // Фоновая предзагрузка тайлов города в RAM — убирает фризы при скролле.
            unawaited(FastPmTilesTileProvider.preloadNizhnevartovskTiles(archive));
          } else {
            debugPrint('OfflineTilesService: архив не прошёл валидацию (raster=$raster, probe=$probeOk) — оффлайн отключён.');
            try {
              await archive.close();
            } catch (_) {}
            _archive = null;
            _hasOfflineFile = false;
          }
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
      'https://45-153-68-59.sslip.io/tiles/day/{z}/{x}/{y}.png';

  /// CartoDB Dark Matter для тёмной темы
  static const String kNightTileUrl =
      'https://45-153-68-59.sslip.io/tiles/night/{z}/{x}/{y}.png';

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
        // Зумы строго из заголовка архива: за пределами maxZoom flutter_map
        // масштабирует существующие тайлы вместо запроса несуществующих
        // (именно это давало «zoom level not supported» и фризы).
        final archiveMaxZoom = _archive!.maxZoom;
        return TileLayer(
          urlTemplate: 'pmtiles://{z}/{x}/{y}',
          tileProvider: FastPmTilesTileProvider(archive: _archive!),
          tileDisplay: const TileDisplay.instantaneous(),
          keepBuffer: 3,
          panBuffer: 1,
          maxZoom: 19.0,
          maxNativeZoom: archiveMaxZoom,
          minNativeZoom: _archive!.minZoom,
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
