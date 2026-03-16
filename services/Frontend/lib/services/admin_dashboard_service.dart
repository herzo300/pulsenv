import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_api_service.dart';

class AdminDashboardService {
  AdminDashboardService._();

  static final AdminDashboardService instance = AdminDashboardService._();

  final BackendApiService _backendApi = BackendApiService.instance;
  String? _adminToken;
  String? _lastTwoFactorCode;

  bool get hasSession => (_adminToken ?? '').isNotEmpty;

  Future<void> ensureSession({String? twoFactorCode}) async {
    if (hasSession) {
      return;
    }

    final code = (twoFactorCode ?? _lastTwoFactorCode ?? '').trim();
    if (code.isEmpty) {
      throw Exception('2FA code is required');
    }

    final response = await _backendApi.postJson(
      '/api/admin/session/claim',
      <String, dynamic>{
        'two_factor_code': code,
      },
      timeout: const Duration(seconds: 8),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected admin session payload');
    }

    final token = payload['token']?.toString().trim() ?? '';
    if (token.isEmpty) {
      throw Exception('Admin token is missing');
    }

    _adminToken = token;
    _lastTwoFactorCode = code;
  }

  Future<Map<String, dynamic>> fetchMetrics({String? twoFactorCode}) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.get(
      '/api/admin/metrics',
      headers: _authHeaders,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _adminToken = null;
      }
      throw Exception(_parseError(response));
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected admin metrics payload');
    }
    return payload;
  }

  Future<Map<String, dynamic>> updateDevicePolicy({
    required String deviceId,
    bool? mapAccess,
    bool? cameraAccess,
    bool? freeAccess,
    String? note,
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.postJson(
      '/api/admin/device-policy',
      {
        'device_id': deviceId,
        'map_access': mapAccess,
        'camera_access': cameraAccess,
        'free_access': freeAccess,
        'note': note,
      },
      headers: _authHeaders,
      timeout: const Duration(seconds: 8),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected policy payload');
    }
    return payload;
  }

  Future<List<Map<String, dynamic>>> fetchCameras({String? twoFactorCode}) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.get(
      '/api/admin/cameras',
      headers: _authHeaders,
      timeout: const Duration(seconds: 12),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected admin cameras payload');
    }
    final rows = payload['cameras'];
    if (rows is! List) {
      return const <Map<String, dynamic>>[];
    }

    return rows
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  Future<Map<String, dynamic>> recheckCameras({String? twoFactorCode}) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.postJson(
      '/api/admin/cameras/recheck',
      const <String, dynamic>{},
      headers: _authHeaders,
      timeout: const Duration(seconds: 120),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected camera recheck payload');
    }
    return payload;
  }

  Future<Map<String, dynamic>> setCameraVisibility({
    required String cameraId,
    required bool hiddenByAdmin,
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.postJson(
      '/api/admin/camera-visibility',
      {
        'camera_id': cameraId,
        'hidden_by_admin': hiddenByAdmin,
      },
      headers: _authHeaders,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected camera visibility payload');
    }
    return payload;
  }

  Future<Map<String, dynamic>> unbindDevice({
    required String deviceId,
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.postJson(
      '/api/admin/device-unbind',
      {'device_id': deviceId},
      headers: _authHeaders,
      timeout: const Duration(seconds: 8),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected device unbind payload');
    }
    return payload;
  }

  Future<Map<String, dynamic>> fetchRuntimePolicy() async {
    final response = await _backendApi.get(
      '/api/runtime/access-policy',
      timeout: const Duration(seconds: 8),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected access policy payload');
    }
    return payload;
  }

  Future<void> releaseSession() async {
    if (!hasSession) {
      return;
    }
    final response = await _backendApi.postJson(
      '/api/admin/session/release',
      const <String, dynamic>{},
      headers: _authHeaders,
      timeout: const Duration(seconds: 6),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _adminToken = null;
      return;
    }
    _adminToken = null;
  }

  Map<String, String> get _authHeaders => <String, String>{
        'Authorization': 'Bearer ${_adminToken ?? ''}',
      };

  String _parseError(http.Response response) {
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail']?.toString().trim();
        if (detail != null && detail.isNotEmpty) {
          return detail;
        }
        final error = payload['error']?.toString().trim();
        if (error != null && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      // Ignore JSON parsing errors and use the fallback below.
    }
    return 'HTTP ${response.statusCode}';
  }
}
