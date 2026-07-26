import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map/map_config.dart';
import 'backend_api_service.dart';

class RuntimeConfig {
  const RuntimeConfig({
    required this.url,
  });

  final String url;

  bool get isReady => url.trim().isNotEmpty;
}

class RuntimeConfigService {
  RuntimeConfigService._();

  static final RuntimeConfigService instance = RuntimeConfigService._();

  static const String _urlPrefKey = 'runtime_backend_url';
  final BackendApiService _backendApi = BackendApiService.instance;

  bool _isAllowedPublicUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (!kReleaseMode) {
      return true;
    }
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || !parsed.hasAuthority) {
      return false;
    }
    final host = parsed.host.toLowerCase();
    if (host == '127.0.0.1' || host == 'localhost' || host == '10.0.2.2') {
      return false;
    }
    if (parsed.scheme == 'https') {
      return true;
    }
    final fallback = MapConfig.defaultPublicBackendBaseUrl.trim();
    return fallback.isNotEmpty && normalized.startsWith(fallback);
  }

  Future<void> bootstrap() async {
    final persisted = await loadPersistedConfig();
    if (persisted.isReady && _isAllowedPublicUrl(persisted.url)) {
      MapConfig.applyBackendConfig(url: persisted.url);
    }

    try {
      final response =
          await _backendApi.get('/config', timeout: const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return;
      }

      final url = payload['backendBaseUrl']?.toString().trim() ?? '';
      if (!_isAllowedPublicUrl(url)) {
        return;
      }

      MapConfig.applyBackendConfig(url: url);
      await _persist(url: url);
      return;
    } catch (_) {
      // Keep local/compile-time fallback only.
    }

    if (MapConfig.hasBackendConfig) {
      await _persist(url: MapConfig.backendBaseUrl);
    }
  }

  Future<RuntimeConfig> loadPersistedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return RuntimeConfig(
      url: prefs.getString(_urlPrefKey)?.trim() ?? '',
    );
  }

  Future<void> _persist({
    required String url,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlPrefKey, url);
  }
}
