import 'dart:convert';

import 'package:http/http.dart' as http;

class BackendApiService {
  BackendApiService._();

  static final BackendApiService instance = BackendApiService._();

  static const List<String> _baseCandidates = [
    'http://127.0.0.1:8001',
    'http://10.0.2.2:8001',
    'http://localhost:8001',
    'http://192.168.0.190:8001',
  ];

  String? _preferredBaseUrl;

  Iterable<String> get _candidateUrls sync* {
    if (_preferredBaseUrl != null) {
      yield _preferredBaseUrl!;
    }
    for (final baseUrl in _baseCandidates) {
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
    Object? lastError;

    for (final baseUrl in _candidateUrls) {
      try {
        final request = http.Request(method, Uri.parse('$baseUrl$path'));
        if (headers != null) {
          request.headers.addAll(headers);
        }
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
