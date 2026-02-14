// lib/services/ai_autofill_service.dart
import 'dart:convert';
import 'api_service.dart';

/// Сервис AI автозаполнения
/// Использует AI endpoint из backend для анализа текста
class AIAutofillService {
  /// Автозаполнение из текста
  static Future<AutofillResult> autofillFromText(String text) async {
    try {
      final response = await ApiService.post('/complaints', {
        'title': text.substring(0, text.length > 50 ? 50 : text.length),
        'description': text,
        'category': '',
        'status': 'open',
      });

      return AutofillResult(
        title: response['title'] ?? text.substring(0, text.length > 50 ? 50 : text.length),
        description: response['description'] ?? text,
        category: response['category'],
        address: null,
        confidence: 1.0,
      );
    } catch (e) {
      return AutofillResult(
        title: text.substring(0, text.length > 50 ? 50 : text.length),
        description: text,
        category: null,
        address: null,
        confidence: 0.0,
      );
    }
  }

  /// Извлечение адреса из текста
  static Future<String?> extractAddress(String text) async {
    try {
      final result = await autofillFromText(text);
      return result.category; // Используем категорию как пример адреса
    } catch (e) {
      return null;
    }
  }

  /// Определение категории
  static Future<String?> categorize(String text) async {
    try {
      final result = await autofillFromText(text);
      return result.category;
    } catch (e) {
      return null;
    }
  }

  /// Улучшение описания
  static Future<String> improveDescription(String text) async {
    return text; // Пока не реализовано
  }
}

class AutofillResult {
  final String title;
  final String description;
  final String? category;
  final String? address;
  final double confidence;

  AutofillResult({
    required this.title,
    required this.description,
    this.category,
    this.address,
    required this.confidence,
  });

  factory AutofillResult.fromJson(Map<String, dynamic> json) {
    return AutofillResult(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'],
      address: json['address'],
      confidence: json['confidence']?.toDouble() ?? 0.0,
    );
  }
}
