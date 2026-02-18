// lib/services/mcp_firebase_service.dart
/// Firebase MCP Service для работы с Firebase Realtime Database через MCP

import 'mcp_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Сервис для работы с Firebase через MCP
class MCPFirebaseService {
  final MCPService _mcpService = MCPService();
  final String _firebaseBaseUrl =
      'https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase';

  /// Получить все жалобы из Firebase
  Future<List<Map<String, dynamic>>> getComplaints({
    String? category,
    String? status,
    int? limit,
  }) async {
    try {
      // Пробуем через MCP Firebase
      final response = await _mcpService.callHTTP(
        'firebase',
        'fetch',
        params: {
          'url': '$_firebaseBaseUrl/complaints.json',
          'method': 'GET',
          'headers': {
            'Content-Type': 'application/json',
          },
        },
      );

      if (response.isSuccess && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        final body = data['body'] as String?;
        if (body != null) {
          final json = jsonDecode(body);
          
          // Firebase возвращает объект с ключами, преобразуем в список
          List<Map<String, dynamic>> complaints = [];
          if (json is Map) {
            json.forEach((key, value) {
              if (value is Map) {
                complaints.add({
                  ...value as Map<String, dynamic>,
                  'id': key,
                });
              }
            });
          } else if (json is List) {
            complaints = json.cast<Map<String, dynamic>>();
          }

          // Фильтрация
          if (category != null) {
            complaints = complaints
                .where((c) => c['category'] == category)
                .toList();
          }

          if (status != null) {
            complaints = complaints
                .where((c) => c['status'] == status)
                .toList();
          }

          if (limit != null && limit > 0) {
            complaints = complaints.take(limit).toList();
          }

          return complaints;
        }
      }
    } catch (e) {
      print('MCP Firebase запрос не удался: $e');
    }

    // Fallback на прямой HTTP запрос
    return _fetchDirectly(category: category, status: status, limit: limit);
  }

  /// Прямой HTTP запрос к Firebase (fallback)
  Future<List<Map<String, dynamic>>> _fetchDirectly({
    String? category,
    String? status,
    int? limit,
  }) async {
    try {
      final uri = Uri.parse('$_firebaseBaseUrl/complaints.json');
      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        // Преобразуем объект Firebase в список
        List<Map<String, dynamic>> complaints = [];
        if (json is Map) {
          json.forEach((key, value) {
            if (value is Map) {
              complaints.add({
                ...value as Map<String, dynamic>,
                'id': key,
              });
            }
          });
        } else if (json is List) {
          complaints = json.cast<Map<String, dynamic>>();
        }

        // Фильтрация
        if (category != null) {
          complaints = complaints
              .where((c) => c['category'] == category)
              .toList();
        }

        if (status != null) {
          complaints = complaints
              .where((c) => c['status'] == status)
              .toList();
        }

        if (limit != null && limit > 0) {
          complaints = complaints.take(limit).toList();
        }

        return complaints;
      }
    } catch (e) {
      print('Прямой HTTP запрос к Firebase не удался: $e');
    }

    return [];
  }

  /// Получить жалобу по ID
  Future<Map<String, dynamic>?> getComplaintById(String id) async {
    try {
      final response = await _mcpService.callHTTP(
        'firebase',
        'fetch',
        params: {
          'url': '$_firebaseBaseUrl/complaints/$id.json',
          'method': 'GET',
        },
      );

      if (response.isSuccess && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        final body = data['body'] as String?;
        if (body != null) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          return {...json, 'id': id};
        }
      }
    } catch (e) {
      print('MCP Firebase запрос не удался: $e');
    }

    // Fallback
    try {
      final response = await http
          .get(Uri.parse('$_firebaseBaseUrl/complaints/$id.json'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return {...json, 'id': id};
      }
    } catch (e) {
      print('Прямой HTTP запрос не удался: $e');
    }

    return null;
  }

  /// Добавить жалобу в Firebase
  Future<String?> addComplaint(Map<String, dynamic> complaint) async {
    try {
      final response = await _mcpService.callHTTP(
        'firebase',
        'fetch',
        params: {
          'url': '$_firebaseBaseUrl/complaints.json',
          'method': 'POST',
          'body': jsonEncode(complaint),
          'headers': {
            'Content-Type': 'application/json',
          },
        },
      );

      if (response.isSuccess && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        final body = data['body'] as String?;
        if (body != null) {
          final json = jsonDecode(body);
          // Firebase возвращает {"name": "id"}
          if (json is Map && json.containsKey('name')) {
            return json['name'] as String?;
          }
        }
      }
    } catch (e) {
      print('MCP Firebase запрос не удался: $e');
    }

    // Fallback
    try {
      final response = await http
          .post(
            Uri.parse('$_firebaseBaseUrl/complaints.json'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(complaint),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json is Map && json.containsKey('name')) {
          return json['name'] as String?;
        }
      }
    } catch (e) {
      print('Прямой HTTP запрос не удался: $e');
    }

    return null;
  }

  /// Обновить жалобу в Firebase
  Future<bool> updateComplaint(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _mcpService.callHTTP(
        'firebase',
        'fetch',
        params: {
          'url': '$_firebaseBaseUrl/complaints/$id.json',
          'method': 'PATCH',
          'body': jsonEncode(updates),
          'headers': {
            'Content-Type': 'application/json',
          },
        },
      );

      return response.isSuccess;
    } catch (e) {
      print('MCP Firebase запрос не удался: $e');
    }

    // Fallback
    try {
      final response = await http
          .patch(
            Uri.parse('$_firebaseBaseUrl/complaints/$id.json'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Прямой HTTP запрос не удался: $e');
      return false;
    }
  }

  /// Получить статистику из Firebase
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final complaints = await getComplaints();

      final stats = <String, dynamic>{
        'total': complaints.length,
        'open': complaints.where((c) => c['status'] == 'open').length,
        'pending': complaints.where((c) => c['status'] == 'pending').length,
        'resolved': complaints.where((c) => c['status'] == 'resolved').length,
        'by_category': <String, int>{},
      };

      // Подсчет по категориям
      for (var complaint in complaints) {
        final category = complaint['category'] as String? ?? 'Прочее';
        stats['by_category'][category] =
            (stats['by_category'][category] as int? ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Ошибка получения статистики: $e');
      return {
        'total': 0,
        'open': 0,
        'pending': 0,
        'resolved': 0,
        'by_category': <String, int>{},
      };
    }
  }
}
