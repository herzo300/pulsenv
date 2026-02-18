// lib/services/mcp_unified_service.dart
/// Унифицированный сервис для работы со всеми MCP сервисами

import 'mcp_firebase_service.dart';
import 'mcp_telegram_service.dart';
import 'mcp_perplexity_service.dart';

/// Унифицированный сервис для работы со всеми MCP сервисами
class MCPUnifiedService {
  final MCPFirebaseService firebase = MCPFirebaseService();
  final MCPTelegramService telegram = MCPTelegramService();
  final MCPPerplexityService perplexity = MCPPerplexityService();

  /// Получить все жалобы (использует Firebase)
  Future<List<Map<String, dynamic>>> getComplaints({
    String? category,
    String? status,
    int? limit,
  }) async {
    return await firebase.getComplaints(
      category: category,
      status: status,
      limit: limit,
    );
  }

  /// Отправить жалобу в Telegram канал
  Future<bool> sendComplaintToTelegram({
    required String botToken,
    required String chatId,
    required Map<String, dynamic> complaint,
  }) async {
    final text = _formatComplaintMessage(complaint);
    return await telegram.sendMessage(
      botToken: botToken,
      chatId: chatId,
      text: text,
      parseMode: 'Markdown',
    );
  }

  /// Поиск информации о проблеме через Perplexity
  Future<String?> searchProblemInfo(String category, String description) async {
    final query = 'Проблема $category в Нижневартовске: $description. Как решить?';
    return await perplexity.searchCityProblems(category);
  }

  /// Форматирование сообщения о жалобе
  String _formatComplaintMessage(Map<String, dynamic> complaint) {
    final buffer = StringBuffer();
    buffer.writeln('*📋 Новая жалоба*');
    buffer.writeln('');
    buffer.writeln('*Категория:* ${complaint['category'] ?? 'Не указана'}');
    
    if (complaint['address'] != null) {
      buffer.writeln('*Адрес:* ${complaint['address']}');
    }
    
    if (complaint['text'] != null) {
      buffer.writeln('');
      buffer.writeln('*Описание:*');
      buffer.writeln(complaint['text']);
    }
    
    if (complaint['lat'] != null && complaint['lng'] != null) {
      buffer.writeln('');
      buffer.writeln(
          '📍 [Открыть на карте](https://www.google.com/maps?q=${complaint['lat']},${complaint['lng']})');
    }
    
    return buffer.toString();
  }
}
