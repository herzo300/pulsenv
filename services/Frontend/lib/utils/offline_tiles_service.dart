import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:flutter_map_pmtiles/flutter_map_pmtiles.dart';
import 'package:path_provider/path_provider.dart';

import 'cached_tile_provider.dart';

/// Сервис оффлайн-карты.
/// Пытается загрузить PMTiles/MBTiles (современные форматы).
/// Если файла нет — откатывается на CachedTileProvider (копит кэш от посещений).
class OfflineTilesService {
  static final OfflineTilesService instance = OfflineTilesService._init();
  bool _hasOfflineFile = false;
  TileLayer? _offlineLayer;

  OfflineTilesService._init();

  Future<void> initOfflineTiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nizhnevartovsk.pmtiles');
      
      // Имитируем проверку файла. В реальной жизни скачивается архив PMTiles (Mapbox / Protomaps)
      if (await file.exists()) {
        final archive = await PmTilesArchive.from(file.path);
        _offlineLayer = TileLayer(
          urlTemplate: 'pmtiles://{z}/{x}/{y}',
          tileProvider: PmTilesTileProvider.fromArchive(archive),
        );
        _hasOfflineFile = true;
        debugPrint('OfflineTilesService: Loaded PMTiles archive successfully.');
      } else {
        _hasOfflineFile = false;
        debugPrint('OfflineTilesService: No PMTiles archive found. Fallback to SQLite auto-cache (CachedTileProvider).');
      }
    } catch (e) {
      debugPrint('OfflineTilesService init error: $e');
      _hasOfflineFile = false;
    }
  }

  TileLayer getTileLayer(String urlTemplate) {
    if (_hasOfflineFile && _offlineLayer != null) {
      return _offlineLayer!;
    }
    
    // Fallback: Кэшируем тайлы (sqflite / cache) автоматом после первого показа.
    // Идеально работает в зоне отключения интернета (скважины/болота).
    return TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: 'ru.soobshio.app',
      tileProvider: CachedTileProvider(),
    );
  }
}
