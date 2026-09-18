// services/Frontend/lib/services/pmtiles_offline_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../map/map_config.dart';

/// Offline PMTiles Vector Map Tile Provider for City Pulse
class PmTilesOfflineProvider {
  static final PmTilesOfflineProvider _instance = PmTilesOfflineProvider._internal();
  factory PmTilesOfflineProvider() => _instance;
  PmTilesOfflineProvider._internal();

  Map<String, dynamic>? _metadata;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize PMTiles metadata archive reader
  Future<bool> initializeArchive() async {
    try {
      final url = Uri.parse('${MapConfig.backendApiBaseUrl}/pmtiles/metadata');
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _metadata = json.decode(utf8.decode(res.bodyBytes));
        _isInitialized = true;
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Get Tile URL for Vector Tile Reader (z/x/y)
  String getVectorTileUrl(int z, int x, int y) {
    return '${MapConfig.backendApiBaseUrl}/pmtiles/$z/$x/$y.pbf';
  }

  /// Get Vector Layers List
  List<Map<String, String>> getAvailableVectorLayers() {
    if (_metadata == null || _metadata!['vector_layers'] == null) {
      return const [
        {'id': 'buildings_3d', 'description': '3D Здания'},
        {'id': 'roads', 'description': 'Дорожная сеть'},
        {'id': 'utilities', 'description': 'Коммунальные сети'},
      ];
    }

    final List<dynamic> layers = _metadata!['vector_layers'];
    return layers.map((l) => {
      'id': (l['id'] ?? '').toString(),
      'description': (l['description'] ?? '').toString(),
    }).toList();
  }
}
