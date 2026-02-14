// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// API сервис для связи с backend
class ApiService {
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000'; // Android emulator
  static String? _customBaseUrl;
  
  static String get baseUrl {
    return _customBaseUrl ??
           (kIsWeb ? 'http://127.0.0.1:8000' :
           Platform.isAndroid ? 'http://10.0.2.2:8000' :
           'http://127.0.0.1:8000');
  }
  
  static set baseUrl(String url) => _customBaseUrl = url;

  // ==================== Жалобы ====================
  
  /// Получить список всех жалоб
  static Future<List<Map<String, dynamic>>> getComplaints({String? category, int limit = 100}) async {
    try {
      final uri = Uri.parse('$baseUrl/complaints').replace(
        queryParameters: {
          if (category != null) 'category': category,
          'limit': limit.toString(),
        },
      );
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error getComplaints: $e');
      throw Exception('Не удалось загрузить жалобы: $e');
    }
  }

  /// Создать новую жалобу
  static Future<Map<String, dynamic>> createComplaint({
    required String title,
    required String description,
    required String category,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/complaints'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'description': description,
          'category': category,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'source': 'mobile_app',
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Ошибка создания: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error createComplaint: $e');
      throw Exception('Не удалось создать жалобу: $e');
    }
  }

  /// Получить кластеры жалоб для карты
  static Future<List<Map<String, dynamic>>> getClusters() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/clusters'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Ошибка загрузки кластеров: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error getClusters: $e');
      throw Exception('Не удалось загрузить кластеры: $e');
    }
  }

  // ==================== Статистика ====================
  
  /// Получить статистику
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Ошибка загрузки статистики: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error getStats: $e');
      throw Exception('Не удалось загрузить статистику: $e');
    }
  }

  /// Получить список категорий
  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>?;
        if (data != null && data['categories'] != null) {
          return (data['categories'] as List).cast<Map<String, dynamic>>();
        }
        return _defaultCategories();
      } else {
        // Возвращаем дефолтные категории если API недоступен
        return _defaultCategories();
      }
    } catch (e) {
      debugPrint('API Error getCategories: $e');
      return _defaultCategories();
    }
  }

  /// Проверить работоспособность API
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static List<Map<String, dynamic>> _defaultCategories() {
    return [
      {'id': 'jkh', 'name': 'ЖКХ', 'icon': '🏘️', 'color': '#FF6B6B'},
      {'id': 'roads', 'name': 'Дороги', 'icon': '🛣️', 'color': '#4ECDC4'},
      {'id': 'improvement', 'name': 'Благоустройство', 'icon': '🌳', 'color': '#45B7D1'},
      {'id': 'transport', 'name': 'Транспорт', 'icon': '🚌', 'color': '#96CEB4'},
      {'id': 'ecology', 'name': 'Экология', 'icon': '♻️', 'color': '#88D8B0'},
      {'id': 'animals', 'name': 'Животные', 'icon': '🐶', 'color': '#FECA57'},
      {'id': 'trade', 'name': 'Торговля', 'icon': '🛒', 'color': '#FF9FF3'},
      {'id': 'security', 'name': 'Безопасность', 'icon': '🚨', 'color': '#54A0FF'},
      {'id': 'snow', 'name': 'Снег/Наледь', 'icon': '❄️', 'color': '#48DBFB'},
      {'id': 'lighting', 'name': 'Освещение', 'icon': '💡', 'color': '#FFC048'},
      {'id': 'medicine', 'name': 'Медицина', 'icon': '🏥', 'color': '#FF6B9D'},
      {'id': 'education', 'name': 'Образование', 'icon': '🏫', 'color': '#C44569'},
      {'id': 'communication', 'name': 'Связь', 'icon': '📶', 'color': '#A29BFE'},
      {'id': 'construction', 'name': 'Строительство', 'icon': '🚧', 'color': '#FD79A8'},
      {'id': 'parking', 'name': 'Парковки', 'icon': '🅿️', 'color': '#FDCB6E'},
      {'id': 'social', 'name': 'Социальная сфера', 'icon': '👥', 'color': '#6C5CE7'},
      {'id': 'labor', 'name': 'Трудовое право', 'icon': '📄', 'color': '#A8E6CF'},
      {'id': 'other', 'name': 'Прочее', 'icon': '❔', 'color': '#B2BEC3'},
      {'id': 'emergency', 'name': 'ЧП', 'icon': '🆘', 'color': '#FF3838'},
    ];
  }
}
