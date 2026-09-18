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
    notifyListeners();
  }

  TileLayer getTileLayer(String urlTemplate, {bool isNightMode = false}) {
    final activeCityId = CityProvider().activeCity.id;
    final isSatelliteUrl = urlTemplate.contains('arcgisonline') || urlTemplate.contains('satellite');
    
    if (_hasOfflineFile && !_offlineDisabled && activeCityId == 'nizhnevartovsk' && !isSatelliteUrl) {
      if (_archive != null) {
        return TileLayer(
          urlTemplate: 'pmtiles://{z}/{x}/{y}',
          tileProvider: PmTilesTileProvider.fromArchive(_archive!),
          keepBuffer: 4,
          panBuffer: 2,
          errorTileCallback: (tile, error, stackTrace) {
            debugPrint('OfflineTilesService: PMTiles error: $error. Falling back to online tile provider.');
            disableOffline();
          },
        );
      }
    }
    
    final effectiveUrl = isSatelliteUrl 
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
        : (isNightMode
            ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
            : 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png');

    return TileLayer(
      urlTemplate: effectiveUrl,
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'ru.pulsgoroda.app',
      tileProvider: NetworkTileProvider(
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 ru.pulsgoroda.app/1.0',
        },
      ),
      keepBuffer: 6,
      panBuffer: 3,
      errorTileCallback: (tile, error, stackTrace) {
        debugPrint('Online TileLayer load error: $error');
      },
    );
  }
}
