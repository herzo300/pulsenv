import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pmtiles/pmtiles.dart';

/// Высокопроизводительный PMTiles провайдер с правильным ImageCache кэшированием
/// и in-memory LRU буфером, исключающий фризы и микролаги при скролле и зуме.
class FastPmTilesTileProvider extends TileProvider {
  FastPmTilesTileProvider({
    required this.archive,
    Map<String, String>? headers,
  }) : super(headers: headers);

  final PmTilesArchive archive;

  /// In-memory LRU кэш сырых байтов тайлов для мгновенного доступа без чтения с диска (4000 тайлов)
  static final _LruByteCache _byteCache = _LruByteCache(maxEntries: 4000);

  /// Предзагрузка ключевых тайлов Нижневартовска в оперативный кэш
  static Future<void> preloadNizhnevartovskTiles(PmTilesArchive archive) async {
    try {
      // Bounding box Nizhnevartovsk (z12..z16)
      for (int z = 12; z <= 16; z++) {
        final tilesCount = 1 << z;
        final minX = ((76.48 + 180.0) / 360.0 * tilesCount).floor();
        final maxX = ((76.68 + 180.0) / 360.0 * tilesCount).ceil();
        final minY = ((1.0 - math.log(math.tan(60.96 * math.pi / 180.0) + 1.0 / math.cos(60.96 * math.pi / 180.0)) / math.pi) / 2.0 * tilesCount).floor();
        final maxY = ((1.0 - math.log(math.tan(60.90 * math.pi / 180.0) + 1.0 / math.cos(60.90 * math.pi / 180.0)) / math.pi) / 2.0 * tilesCount).ceil();

        for (int x = minX; x <= maxX; x++) {
          for (int y = minY; y <= maxY; y++) {
            final tileId = ZXY(z, x, y).toTileId();
            if (_byteCache.get(tileId) == null) {
              try {
                final data = await archive.tile(tileId);
                final raw = data.bytes();
                final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
                _byteCache.put(tileId, bytes);
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  bool get supportsCancelLoading => false;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final tileId = ZXY(coordinates.z, coordinates.x, coordinates.y).toTileId();
    return FastPmTilesImageProvider(
      tileId: tileId,
      archive: archive,
      byteCache: _byteCache,
    );
  }

  /// Очистка in-memory кэша при необходимости
  static void clearMemoryCache() {
    _byteCache.clear();
  }
}

/// ImageProvider для PMTiles с поддержкой сравнения ключей в Flutter ImageCache
class FastPmTilesImageProvider extends ImageProvider<FastPmTilesImageProvider> {
  FastPmTilesImageProvider({
    required this.tileId,
    required this.archive,
    required this.byteCache,
  });

  final int tileId;
  final PmTilesArchive archive;
  final _LruByteCache byteCache;

  @override
  Future<FastPmTilesImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FastPmTilesImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    FastPmTilesImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      debugLabel: 'FastPmTilesTile-$tileId',
      informationCollector: () => [
        DiagnosticsProperty('Tile ID', tileId),
        DiagnosticsProperty('Archive', archive),
      ],
    );
  }

  Future<Codec> _loadAsync(
    FastPmTilesImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    try {
      Uint8List? bytes = byteCache.get(tileId);
      if (bytes == null) {
        final data = await archive.tile(tileId);
        final raw = data.bytes();
        bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
        byteCache.put(tileId, bytes);
      }
      final buffer = await ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      // Тайл отсутствует в архиве (вне зоны покрытия) — отдаём прозрачный
      // пиксель вместо плашки с текстом ошибки на карте.
      try {
        final buffer = await ImmutableBuffer.fromUint8List(_kTransparentPng);
        return decode(buffer);
      } catch (_) {
        chunkEvents.addError(e);
        rethrow;
      }
    } finally {
      await chunkEvents.close();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FastPmTilesImageProvider &&
        other.tileId == tileId &&
        identical(other.archive, archive);
  }

  @override
  int get hashCode => Object.hash(tileId, identityHashCode(archive));
}

/// 1x1 прозрачный PNG — заглушка для тайлов вне покрытия оффлайн-архива.
final Uint8List _kTransparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Потокобезопасный LRU кэш тайлов в оперативной памяти
class _LruByteCache {
  _LruByteCache({this.maxEntries = 600});
  final int maxEntries;
  final LinkedHashMap<int, Uint8List> _map = LinkedHashMap<int, Uint8List>();

  Uint8List? get(int key) {
    final val = _map.remove(key);
    if (val != null) {
      _map[key] = val;
    }
    return val;
  }

  void put(int key, Uint8List value) {
    _map.remove(key);
    if (_map.length >= maxEntries) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  void clear() {
    _map.clear();
  }
}
