import 'dart:convert';

import 'backend_api_service.dart';

class RuntimeAccessService {
  RuntimeAccessService._();

  static final RuntimeAccessService instance = RuntimeAccessService._();

  final BackendApiService _backendApi = BackendApiService.instance;

  Future<Map<String, dynamic>> fetchPolicy() async {
    final response = await _backendApi.get(
      '/api/runtime/access-policy',
      timeout: const Duration(seconds: 8),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Access policy request failed: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected access policy payload');
    }
    return payload;
  }
}
