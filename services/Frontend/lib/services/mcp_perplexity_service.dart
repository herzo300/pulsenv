// lib/services/mcp_perplexity_service.dart
/// Perplexity MCP Service для работы с Perplexity AI через MCP

import 'mcp_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Сервис для работы с Perplexity AI через MCP
class MCPPerplexityService {
  final MCPService _mcpService = MCPService();
  final String _perplexityApiUrl = 'https://api.perplexity.ai';

  /// Выполнить поисковый запрос через Perplexity MCP
  Future<Map<String, dynamic>?> search({
    required String query,
    String? model,
    int? maxTokens,
    double? temperature,
  }) async {
    try {
      final url = '$_perplexityApiUrl/chat/completions';
      
      final body = {
        'model': model ?? 'pplx-70b-online',
        'messages': [
          {
            'role': 'user',
            'content': query,
          }
        ],
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (temperature != null) 'temperature': temperature,
      };

      final response = await _mcpService.callHTTP(
        'perplexity',
        'fetch',
        params: {
          'url': url,
          'method': 'POST',
          'body': jsonEncode(body),
          'headers': {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_getApiKey()}',
          },
        },
      );

      if (response.isSuccess && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        final body = data['body'] as String?;
        if (body != null) {
          return jsonDecode(body) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print('MCP Perplexity запрос не удался: $e');
    }

    // Fallback на прямой HTTP запрос
    return _searchDirectly(
      query: query,
      model: model,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  /// Прямой HTTP запрос к Perplexity (fallback)
  Future<Map<String, dynamic>?> _searchDirectly({
    required String query,
    String? model,
    int? maxTokens,
    double? temperature,
  }) async {
    try {
      final url = Uri.parse('$_perplexityApiUrl/chat/completions');
      
      final body = {
        'model': model ?? 'pplx-70b-online',
        'messages': [
          {
            'role': 'user',
            'content': query,
          }
        ],
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (temperature != null) 'temperature': temperature,
      };

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_getApiKey()}',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Прямой HTTP запрос к Perplexity не удался: $e');
    }

    return null;
  }

  /// Получить API ключ из конфигурации
  String _getApiKey() {
    // В реальном приложении это должно быть из secure storage или env
    // Для примера используем пустую строку - нужно настроить
    return '';
  }

  /// Поиск информации о городе Нижневартовск
  Future<String?> searchCityInfo(String query) async {
    final fullQuery = 'Нижневартовск: $query';
    final response = await search(query: fullQuery);

    if (response != null) {
      final choices = response['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        return message?['content'] as String?;
      }
    }

    return null;
  }

  /// Поиск информации о проблемах города
  Future<String?> searchCityProblems(String category) async {
    final query =
        'Проблемы $category в Нижневартовске: текущая ситуация, статистика, решения';
    return await searchCityInfo(query);
  }

  /// Поиск контактов организаций
  Future<String?> searchOrganizationContacts(String organizationName) async {
    final query = 'Контакты $organizationName в Нижневартовске: телефон, адрес, email';
    return await searchCityInfo(query);
  }
}
