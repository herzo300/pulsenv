import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:soobshio/utils/cached_tile_provider.dart';
import 'package:soobshio/utils/offline_tiles_service.dart';
import 'package:soobshio/utils/fast_pmtiles_tile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TileLayer constructor with FmtcCachedTileProvider and OfflineTilesService', () {
    // 1. Test FmtcCachedTileProvider directly
    final provider = FmtcCachedTileProvider.get();
    expect(provider.headers.containsKey('User-Agent'), isTrue);

    // 2. Test TileLayer instantiation for day mode with optimized buffer
    final dayLayer = OfflineTilesService.instance.getTileLayer(
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
      isNightMode: false,
    );
    expect(dayLayer, isNotNull);
    expect(dayLayer.tileProvider.headers['User-Agent'], isNotNull);
    expect(dayLayer.panBuffer, equals(1));
    expect(dayLayer.keepBuffer, equals(3));

    // 3. Test TileLayer instantiation for night mode with optimized buffer
    final nightLayer = OfflineTilesService.instance.getTileLayer(
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
      isNightMode: true,
    );
    expect(nightLayer, isNotNull);
    expect(nightLayer.tileProvider.headers['User-Agent'], isNotNull);
    expect(nightLayer.panBuffer, equals(1));
    expect(nightLayer.keepBuffer, equals(3));

    // 4. Test TileLayer instantiation for satellite mode with optimized buffer
    final satLayer = OfflineTilesService.instance.getTileLayer(
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      isNightMode: false,
    );
    expect(satLayer, isNotNull);
    expect(satLayer.tileProvider.headers['User-Agent'], isNotNull);
    expect(satLayer.panBuffer, equals(1));
    expect(satLayer.keepBuffer, equals(3));
  });
}
