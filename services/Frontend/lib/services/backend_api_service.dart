import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'device_identity_service.dart';

class BackendApiService {
  BackendApiService._();

  static final BackendApiService instance = BackendApiService._();

  static const String _releaseBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
  static const String _fallbackBaseUrls =
      String.fromEnvironment('BACKEND_FALLBACK_URLS', defaultValue: '');

  String? _preferredBaseUrl;

  Iterable<String> get _candidateUrls sync* {
    final candidates = kReleaseMode
        ? <String>[
            if (_releaseBaseUrl.trim().startsWith('https://'))
              _releaseBaseUrl.trim(),
          ]
        : _fallbackBaseUrls
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();

    if (_preferredBaseUrl != null &&
        _preferredBaseUrl!.isNotEmpty &&
        candidates.contains(_preferredBaseUrl)) {
      yield _preferredBaseUrl!;
    }
    for (final baseUrl in candidates) {
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
          request.body = '$body';
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
