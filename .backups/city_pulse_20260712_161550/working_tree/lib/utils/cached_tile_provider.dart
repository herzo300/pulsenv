import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

class CachedTileProvider extends TileProvider {
  CachedTileProvider() : super();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    String url = options.urlTemplate ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    url = url.replaceAll('{x}', coordinates.x.toString());
    url = url.replaceAll('{y}', coordinates.y.toString());
    url = url.replaceAll('{z}', coordinates.z.toString());
    
    return CachedNetworkImageProvider(url);
  }
}
