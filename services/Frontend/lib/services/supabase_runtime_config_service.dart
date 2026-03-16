import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map/map_config.dart';
import 'backend_api_service.dart';

class SupabaseRuntimeConfig {
  const SupabaseRuntimeConfig({
    required this.url,
    required this.anonKey,
  });

  final String url;
  final String anonKey;

  bool get isReady => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
  String get reportsRestUrl => '${url.trim()}/rest/v1/reports';
}

class SupabaseRuntimeConfigService {
  SupabaseRuntimeConfigService._();

  static final SupabaseRuntimeConfigService instance =
      SupabaseRuntimeConfigService._();

  static const String _urlPrefKey = 'runtime_supabase_url';
  static const String _anonKeyPrefKey = 'runtime_supabase_anon_key';
  final BackendApiService _backendApi = BackendApiService.instance;

  bool _isAllowedPublicUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (!kReleaseMode) {
      return true;
    }
    return normalized.startsWith('https://');
  }

  Future<void> bootstrap() async {
    final persisted = await loadPersistedConfig();
    if (persisted.isReady && _isAllowedPublicUrl(persisted.url)) {
      MapConfig.applySupabaseConfig(
        url: persisted.url,
        anonKey: persisted.anonKey,
      );
    }

    if (MapConfig.hasSupabaseConfig) {
      await _persist(
        url: MapConfig.supabaseUrl,
        anonKey: MapConfig.supabaseAnonKey,
      );
      return;
    }

    try {
      final response = await _backendApi.get(
        '/config',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return;
      }

      final url = payload['supabaseUrl']?.toString().trim() ?? '';
      final anonKey = payload['supabaseAnonKey']?.toString().trim() ?? '';
      if (!_isAllowedPublicUrl(url) || anonKey.isEmpty) {
        return;
      }

      MapConfig.applySupabaseConfig(url: url, anonKey: anonKey);
      await _persist(url: url, anonKey: anonKey);
    } catch (_) {
      // Keep local/compile-time fallback only.
    }
  }

  Future<SupabaseRuntimeConfig> loadPersistedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return SupabaseRuntimeConfig(
      url: prefs.getString(_urlPrefKey)?.trim() ?? '',
      anonKey: prefs.getString(_anonKeyPrefKey)?.trim() ?? '',
    );
  }

  Future<void> _persist({
    required String url,
    required String anonKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlPrefKey, url);
    await prefs.setString(_anonKeyPrefKey, anonKey);
  }
}
