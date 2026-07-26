import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../map/map_config.dart';
import 'backend_api_service.dart';

class ReportsRepository {
  ReportsRepository._();

  static final ReportsRepository instance = ReportsRepository._();

  final BackendApiService _api = BackendApiService.instance;

  Future<List<Map<String, dynamic>>> fetchReports({
    String? status,
    int limit = 100,
    String order = 'created_at.desc',
    double? latGte,
    double? latLte,
    double? lngGte,
    double? lngLte,
  }) async {
    final response = await _api.get(
      _buildPath(
        '/api/reports',
        [
          if (status != null) MapEntry('status', 'eq.$status'),
          MapEntry('limit', '$limit'),
          MapEntry('order', order),
          if (latGte != null)
            MapEntry('lat', 'gte.${latGte.toStringAsFixed(6)}'),
          if (latLte != null)
            MapEntry('lat', 'lte.${latLte.toStringAsFixed(6)}'),
          if (lngGte != null)
            MapEntry('lng', 'gte.${lngGte.toStringAsFixed(6)}'),
          if (lngLte != null)
            MapEntry('lng', 'lte.${lngLte.toStringAsFixed(6)}'),
        ],
      ),
      timeout: const Duration(seconds: 18),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('fetchReports HTTP ${response.statusCode}');
    }
    return _decodeList(response.body);
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> body) async {
    final response = await _api.postJson(
      '/api/reports',
      body,
      timeout: const Duration(seconds: 20),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('createReport HTTP ${response.statusCode}');
    }
    return _decodeMap(response.body);
  }

  Future<void> patchReport(
    int id, {
    int? likesCount,
    int? dislikesCount,
    int? supporters,
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (likesCount != null) {
      payload['likes_count'] = likesCount;
    }
    if (dislikesCount != null) {
      payload['dislikes_count'] = dislikesCount;
    }
    if (supporters != null) {
      payload['supporters'] = supporters;
    }
    if (status != null) {
      payload['status'] = status;
    }
    if (payload.isEmpty) {
      return;
    }

    final response = await _api.patchJson(
      '/api/reports?id=eq.$id',
      payload,
      timeout: const Duration(seconds: 15),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('patchReport HTTP ${response.statusCode}');
    }
  }

  Future<String?> uploadReportImage(File image) async {
    final extension = _guessImageExtension(image.path);
    final objectPath =
        'reports/${DateTime.now().toUtc().millisecondsSinceEpoch}_${math.Random().nextInt(1 << 32)}.$extension';

    final response = await _api.postBytes(
      '/api/storage/object/${MapConfig.reportsMediaBucket}/$objectPath',
      await image.readAsBytes(),
      headers: {
        'Content-Type': _guessImageMimeType(extension),
        'x-upsert': 'false',
      },
      timeout: const Duration(seconds: 25),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'uploadReportImage HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final payload = _decodeMap(response.body);
    final publicUrl = payload['url']?.toString().trim();
    if (publicUrl != null && publicUrl.isNotEmpty) {
      return publicUrl;
    }
    return MapConfig.storagePublicUrl(MapConfig.reportsMediaBucket, objectPath);
  }

  Future<Map<String, dynamic>> fetchInfographicSummary() async {
    final response = await _api.get(
      '/api/infographic',
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeMap(utf8.decode(response.bodyBytes));
    }

    final asset = await rootBundle.loadString('assets/infographic_data.json');
    return _decodeMap(asset);
  }

  Future<List<dynamic>> fetchUkList() async {
    final response = await _api.get(
      '/api/infographic_data?data_type=eq.uk_list',
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('fetchUkList HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map<String, dynamic> && first['data'] is List) {
        return first['data'] as List<dynamic>;
      }
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchUkHousesCoordinates(String ukName) async {
    final encodedName = Uri.encodeComponent(ukName);
    final response = await _api.get(
      '/api/uk/houses_coordinates?uk_name=$encodedName',
      timeout: const Duration(seconds: 25),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('fetchUkHousesCoordinates HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic> && decoded['houses'] is List) {
      return List<Map<String, dynamic>>.from(
        (decoded['houses'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return const [];
  }

  Future<Map<String, dynamic>?> fetchUkOfficeCoordinate(String ukName) async {
    final encodedName = Uri.encodeComponent(ukName);
    final response = await _api.get(
      '/api/uk/office_coordinate?uk_name=$encodedName',
      timeout: const Duration(seconds: 15),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  Future<int?> fetchLatestReportId() async {
    final reports = await fetchReports(limit: 1, order: 'id.desc');
    if (reports.isEmpty) {
      return null;
    }
    return _toInt(reports.first['id']);
  }

  Future<Map<String, dynamic>?> fetchLatestReportSummary() async {
    final reports = await fetchReports(limit: 1, order: 'id.desc');
    if (reports.isEmpty) {
      return null;
    }
    return reports.first;
  }

  Future<List<String>> fetchServerCategories() async {
    final response = await _api.get(
      '/categories',
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('fetchServerCategories HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }
    final categories = decoded['categories'];
    if (categories is! List) {
      return const [];
    }
    return categories
        .whereType<Map>()
        .map((item) => item['name']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String _buildPath(String path, List<MapEntry<String, String>> parameters) {
    final query = parameters
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    return query.isEmpty ? path : '$path?$query';
  }

  List<Map<String, dynamic>> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw Exception('Unexpected list payload');
    }
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected map payload');
    }
    return decoded;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _guessImageExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'heic';
    return 'jpg';
  }

  String _guessImageMimeType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
