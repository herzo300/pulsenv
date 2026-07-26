import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'device_identity_service.dart';
import '../map/map_config.dart';

class BackendApiService {
  BackendApiService._();

  static final BackendApiService instance = BackendApiService._();

  static const String _releaseBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
  static const String _fallbackBaseUrls =
      String.fromEnvironment('BACKEND_FALLBACK_URLS', defaultValue: '');

  String? _preferredBaseUrl;

  bool _isAllowedReleaseUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || !parsed.hasAuthority) {
      return false;
    }
    if (parsed.scheme == 'https') {
      return true;
    }
    final fallback = MapConfig.defaultPublicBackendBaseUrl.trim();
    return fallback.isNotEmpty && normalized.startsWith(fallback);
  }

  Iterable<String> get _candidateUrls sync* {
    final candidates = kReleaseMode
        ? <String>[
            if (_isAllowedReleaseUrl(_releaseBaseUrl))
              _releaseBaseUrl.trim(),
            if (_isAllowedReleaseUrl(MapConfig.backendBaseUrl))
              MapConfig.backendBaseUrl.trim(),
            if (_isAllowedReleaseUrl(MapConfig.defaultPublicBackendBaseUrl))
              MapConfig.defaultPublicBackendBaseUrl,
          ]
        : _fallbackBaseUrls
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .followedBy(<String>[
            if (MapConfig.backendBaseUrl.trim().isNotEmpty)
              MapConfig.backendBaseUrl.trim(),
          ]).toList();

    final seen = <String>{};
    final uniqueCandidates = <String>[];
    for (final candidate in candidates) {
      if (seen.add(candidate)) {
        uniqueCandidates.add(candidate);
      }
    }

    if (_preferredBaseUrl != null &&
        _preferredBaseUrl!.isNotEmpty &&
        uniqueCandidates.contains(_preferredBaseUrl)) {
      yield _preferredBaseUrl!;
    }
    for (final baseUrl in uniqueCandidates) {
      if (baseUrl != _preferredBaseUrl) {
        yield baseUrl;
      }
    }
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _request(
      'GET',
      path,
      headers: headers,
      timeout: timeout,
    );
  }

  Future<http.Response> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 25),
  }) {
    return _request(
      'POST',
      path,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
      timeout: timeout,
    );
  }

  Future<http.Response> patchJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 20),
  }) {
    return _request(
      'PATCH',
      path,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
      timeout: timeout,
    );
  }

  Future<http.Response> postBytes(
    String path,
    Uint8List body, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 25),
  }) {
    return _request(
      'POST',
      path,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
    required Duration timeout,
  }) async {
    if (kReleaseMode && _candidateUrls.isEmpty) {
      throw Exception('Secure backend URL is not configured for release build');
    }

    Object? lastError;
    final deviceId = await DeviceIdentityService.instance.getOrCreateDeviceId();
    final mergedHeaders = <String, String>{
      'X-Client-Device-Id': deviceId,
      ...?headers,
    };

    for (final baseUrl in _candidateUrls) {
      try {
        final request = http.Request(method, Uri.parse('$baseUrl$path'));
        request.headers.addAll(mergedHeaders);
        if (body != null) {
          if (body is Uint8List) {
            request.bodyBytes = body;
          } else {
            request.body = '$body';
          }
        }

        final response = await http.Response.fromStream(
          await request.send().timeout(timeout),
        );

        if (response.statusCode < 500) {
          _preferredBaseUrl = baseUrl;
          return response;
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception('Backend unavailable: $lastError');
  }
}
