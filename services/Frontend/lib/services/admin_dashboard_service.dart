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
      throw Exception('Требуется код администратора (2FA)');
    }

    final response = await _backendApi.postJson(
      '/api/admin/session/claim',
      <String, dynamic>{
        'two_factor_code': code,
      },
      timeout: const Duration(seconds: 3),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      final token = payload is Map ? payload['token']?.toString().trim() : null;
      if (token != null && token.isNotEmpty) {
        _adminToken = token;
        _lastTwoFactorCode = code;
        return;
      }
    }
    // Без валидного 2FA сессия не выдаётся — фейковых фолбэков нет.
    throw Exception('Неверный код администратора или сессия недоступна');
  }

  void clearSession() {
    _adminToken = null;
  }

  Future<Map<String, dynamic>> fetchMetrics({String? twoFactorCode}) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.get(
      '/api/admin/metrics',
      headers: _authHeaders,
      timeout: const Duration(seconds: 4),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        return payload;
      }
    }
    throw Exception('Не удалось загрузить метрики сервера (${response.statusCode})');
  }

  Future<Map<String, dynamic>> fetchNotificationDiagnostics({
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.get(
      '/api/admin/notification-diagnostics',
      headers: _authHeaders,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        clearSession();
      }
      throw Exception(_parseError(response));
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected notification diagnostics payload');
    }
    return payload;
  }

  Future<Map<String, dynamic>> fetchProductFunnel({
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.get(
      '/api/admin/product-funnel',
      headers: _authHeaders,
      timeout: const Duration(seconds: 4),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) return payload;
    }
    throw Exception('Не удалось загрузить продуктовую воронку (${response.statusCode})');
  }

  Future<Map<String, dynamic>> fetchIngestionQuality({
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.get(
      '/api/admin/ingestion-quality',
      headers: _authHeaders,
      timeout: const Duration(seconds: 4),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) return payload;
    }
    throw Exception('Не удалось загрузить качество инжеста (${response.statusCode})');
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

  Future<List<Map<String, dynamic>>> fetchCameras(
      {String? twoFactorCode}) async {
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

  Future<List<Map<String, dynamic>>> fetchSecretCameras({
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.get(
      '/api/admin/cameras/secret',
      headers: _authHeaders,
      timeout: const Duration(seconds: 12),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected secret cameras payload');
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

  Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.get(
      '/api/admin/users?search=${Uri.encodeComponent(query)}',
      headers: _authHeaders,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected search users payload');
    }
    final rows = payload['users'];
    if (rows is! List) {
      return const <Map<String, dynamic>>[];
    }

    return rows
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  Future<Map<String, dynamic>> grantPremium({
    int? telegramId,
    String? username,
    String? phone,
    String? address,
    String? vkId,
    int days = 30,
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.postJson(
      '/api/admin/grant-premium',
      {
        if (telegramId != null) 'telegram_id': telegramId,
        if (username != null) 'username': username,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        if (vkId != null) 'vk_id': vkId,
        'days': days,
      },
      headers: _authHeaders,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected grant premium response');
    }
    return payload;
  }

  Future<Map<String, dynamic>> fetchHermesReport({String? twoFactorCode}) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.get(
      '/api/admin/hermes-report',
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
      throw Exception('Unexpected hermes report payload');
    }
    return payload;
  }

  Future<void> dismissHermesReport({String? twoFactorCode}) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.postJson(
      '/api/admin/hermes-report/dismiss',
      <String, dynamic>{},
      headers: _authHeaders,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _adminToken = null;
      }
      throw Exception(_parseError(response));
    }
  }

  Future<void> banUser({
    required String userId,
    String? twoFactorCode,
  }) async {
    await ensureSession(twoFactorCode: twoFactorCode);
    final response = await _backendApi.postJson(
      '/api/admin/ban-user',
      <String, dynamic>{
        'user_id': userId,
      },
      headers: _authHeaders,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _adminToken = null;
      }
      throw Exception(_parseError(response));
    }
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
