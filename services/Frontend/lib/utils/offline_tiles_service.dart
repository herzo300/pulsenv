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
    final bgTileColor = isNightMode ? const Color(0xFF0C1424) : const Color(0xFFE8EEF5);
    
    if (_hasOfflineFile && !_offlineDisabled && activeCityId == 'nizhnevartovsk' && !isSatelliteUrl) {
      if (_archive != null) {
        return TileLayer(
          urlTemplate: 'pmtiles://{z}/{x}/{y}',
          tileProvider: PmTilesTileProvider.fromArchive(_archive!),
          tileDisplay: const TileDisplay.instantaneous(),
          keepBuffer: 12,
          panBuffer: 6,
          evictErrorTileStrategy: EvictErrorTileStrategy.none,
          tileBuilder: (context, tileWidget, tile) => RepaintBoundary(
            child: Container(
              color: bgTileColor,
              child: tileWidget,
            ),
          ),
          errorTileCallback: (tile, error, stackTrace) {
            // Silently swallow missing tile errors and render background color without disabling offline mode or flickering
          },
        );
      }
    }
    
    final effectiveUrl = isSatelliteUrl 
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return TileLayer(
      urlTemplate: effectiveUrl,
      userAgentPackageName: 'ru.pulsgoroda.app',
      maxZoom: 19.0,
      maxNativeZoom: 19,
      retinaMode: false,
      tileProvider: NetworkTileProvider(
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 ru.pulsgoroda.app/1.0',
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Cache-Control': 'public, max-age=31536000, immutable',
        },
      ),
      tileDisplay: const TileDisplay.instantaneous(),
      keepBuffer: 12,
      panBuffer: 6,
      evictErrorTileStrategy: EvictErrorTileStrategy.none,
      tileBuilder: (context, tileWidget, tile) => RepaintBoundary(
        child: Container(
          color: isSatelliteUrl ? const Color(0xFF0F1A28) : bgTileColor,
          child: tileWidget,
        ),
      ),
      errorTileCallback: (tile, error, stackTrace) {
        debugPrint('Online TileLayer load error: $error');
      },
    );
  }
}
