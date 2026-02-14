// lib/services/ai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

/// AI Service для анализа текста с помощью Zai GLM-4.7
class AIService {
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000';
  static String? _customBaseUrl;

  static String get baseUrl {
    return _customBaseUrl ??
           (Platform.isAndroid ? 'http://10.0.2.2:8000' :
           'http://127.0.0.1:8000');
  }

  static set baseUrl(String url) => _customBaseUrl = url;

  /// Анализ текста через Zai (backend AI endpoint)
  static Future<AnalysisResult> analyze(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AnalysisResult(
          category: data['category'],
          summary: data['summary'],
          confidence: 0.95,
        );
      }
    } catch (e) {
      print('AI analyze error: $e');
    }

    return AnalysisResult(
      category: 'Неизвестно',
      summary: text,
      confidence: 0.0,
    );
  }

  /// Извлечь категорию из текста
  static Future<String?> extractCategory(String text) async {
    final result = await analyze(text);
    return result.category;
  }
}

/// Результат анализа AI
class AnalysisResult {
  final String? category;
  final String? summary;
  final double confidence;

  AnalysisResult({
    this.category,
    this.summary,
    required this.confidence,
  });
}
