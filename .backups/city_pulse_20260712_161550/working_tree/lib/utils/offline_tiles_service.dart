import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:flutter_map_pmtiles/flutter_map_pmtiles.dart';
import 'package:path_provider/path_provider.dart';

import 'cached_tile_provider.dart';
import '../services/city_provider.dart';

/// Сервис оффлайн-карты.
/// Пытается загрузить PMTiles/MBTiles (современные форматы).
/// Если файла нет — откатывается на CachedTileProvider (копит кэш от посещений).
class OfflineTilesService {
  static final OfflineTilesService instance = OfflineTilesService._init();
  bool _hasOfflineFile = false;
  PmTilesArchive? _archive;

  OfflineTilesService._init();

  Future<void> initOfflineTiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nizhnevartovsk.pmtiles');
      
      // Проверяем локальный архив PMTiles и используем его как оффлайн-подложку.
      if (await file.exists()) {
        _archive = await PmTilesArchive.from(file.path);
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

  TileLayer getTileLayer(String urlTemplate, {bool isNightMode = true}) {
    final activeCityId = CityProvider().activeCity.id;
    final isSatelliteUrl = urlTemplate.contains('arcgisonline') || urlTemplate.contains('satellite');
    
    if (_hasOfflineFile && _archive != null && activeCityId == 'nizhnevartovsk' && !isSatelliteUrl) {
      return TileLayer(
        urlTemplate: 'pmtiles://{z}/{x}/{y}',
        tileProvider: PmTilesTileProvider.fromArchive(_archive!),
        keepBuffer: 2,
        panBuffer: 1,
      );
    }
    
    // Fallback: Кэшируем тайлы (sqflite / cache) автоматом после первого показа.
    return TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: 'ru.pulsgoroda.app',
      tileProvider: CachedTileProvider(),
      keepBuffer: 2, // Оптимизировано для снижения фризов при зуме
      panBuffer: 1, // Оптимизировано для более быстрой загрузки
    );
  }
}
