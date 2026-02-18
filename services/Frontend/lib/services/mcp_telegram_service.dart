// lib/services/mcp_telegram_service.dart
/// Telegram MCP Service для работы с Telegram через MCP

import 'mcp_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Сервис для работы с Telegram через MCP
class MCPTelegramService {
  final MCPService _mcpService = MCPService();
  final String _botApiUrl = 'https://api.telegram.org/bot';

  /// Отправить сообщение в Telegram канал через MCP
  Future<bool> sendMessage({
    required String botToken,
    required String chatId,
    required String text,
    String? parseMode,
    bool? disableWebPagePreview,
  }) async {
    try {
      final url = '$_botApiUrl$botToken/sendMessage';
      
      final params = {
        'chat_id': chatId,
        'text': text,
        if (parseMode != null) 'parse_mode': parseMode,
        if (disableWebPagePreview != null)
          'disable_web_page_preview': disableWebPagePreview.toString(),
      };

      final response = await _mcpService.callHTTP(
        'telegram',
        'fetch',
        params: {
          'url': url,
          'method': 'POST',
          'body': jsonEncode(params),
          'headers': {
            'Content-Type': 'application/json',
          },
        },
      );

      return response.isSuccess;
    } catch (e) {
      print('MCP Telegram запрос не удался: $e');
      return false;
    }
  }

  /// Получить информацию о боте через MCP
  Future<Map<String, dynamic>?> getBotInfo(String botToken) async {
    try {
      final url = '$_botApiUrl$botToken/getMe';

      final response = await _mcpService.callHTTP(
        'telegram',
        'fetch',
        params: {
          'url': url,
          'method': 'GET',
        },
      );

      if (response.isSuccess && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        final body = data['body'] as String?;
        if (body != null) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          return json['result'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      print('MCP Telegram запрос не удался: $e');
    }

    // Fallback
    try {
      final response = await http
          .get(Uri.parse('$_botApiUrl$botToken/getMe'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['result'] as Map<String, dynamic>?;
      }
    } catch (e) {
      print('Прямой HTTP запрос не удался: $e');
    }

    return null;
  }

  /// Получить обновления бота через MCP
  Future<List<Map<String, dynamic>>> getUpdates({
    required String botToken,
    int? offset,
    int? limit,
    int? timeout,
  }) async {
    try {
      final url = '$_botApiUrl$botToken/getUpdates';
      final params = <String, dynamic>{};
      if (offset != null) params['offset'] = offset;
      if (limit != null) params['limit'] = limit;
      if (timeout != null) params['timeout'] = timeout;

      final response = await _mcpService.callHTTP(
        'telegram',
        'fetch',
        params: {
          'url': url,
          'method': 'POST',
          'body': jsonEncode(params),
          'headers': {
            'Content-Type': 'application/json',
          },
        },
      );

      if (response.isSuccess && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        final body = data['body'] as String?;
        if (body != null) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          final results = json['result'] as List<dynamic>?;
          return results?.cast<Map<String, dynamic>>() ?? [];
        }
      }
    } catch (e) {
      print('MCP Telegram запрос не удался: $e');
    }

    return [];
  }

  /// Отправить фото в Telegram через MCP
  Future<bool> sendPhoto({
    required String botToken,
    required String chatId,
    required String photoUrl,
    String? caption,
    String? parseMode,
  }) async {
    try {
      final url = '$_botApiUrl$botToken/sendPhoto';
      
      final params = {
        'chat_id': chatId,
        'photo': photoUrl,
        if (caption != null) 'caption': caption,
        if (parseMode != null) 'parse_mode': parseMode,
      };

      final response = await _mcpService.callHTTP(
        'telegram',
        'fetch',
        params: {
          'url': url,
          'method': 'POST',
          'body': jsonEncode(params),
          'headers': {
            'Content-Type': 'application/json',
          },
        },
      );

      return response.isSuccess;
    } catch (e) {
      print('MCP Telegram запрос не удался: $e');
      return false;
    }
  }
}
