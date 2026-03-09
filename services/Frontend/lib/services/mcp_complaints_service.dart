// lib/services/mcp_complaints_service.dart
/// Сервис для работы с жалобами через MCP
library;


import 'package:flutter/foundation.dart';
import 'mcp_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Сервис для работы с жалобами через MCP
class MCPComplaintsService {
  final MCPService _mcpService = MCPService();
  final String _baseUrl = 'http://127.0.0.1:8001';

  /// Apply category/status/limit filters to a complaint list
  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> complaints, {
    String? category,
    String? status,
    int? limit,
  }) {
    var result = complaints;
    if (category != null) {
      result = result.where((c) => c['category'] == category).toList();
    }
    if (status != null) {
      result = result.where((c) => c['status'] == status).toList();
    }
    if (limit != null && limit > 0) {
      result = result.take(limit).toList();
    }
    return result;
  }

  /// Получить все жалобы
  Future<List<Map<String, dynamic>>> getAllComplaints({
    String? category,
    String? status,
    int? limit,
  }) async {
    try {
      // Пробуем через MCP Fetch
      final response = await _mcpService.callHTTP(
        'mcp_fetch',
        'fetch',
        params: {
          'url': '$_baseUrl/api/reports',
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
          final json = jsonDecode(body) as List<dynamic>;
          return _applyFilters(
            json.cast<Map<String, dynamic>>(),
            category: category,
            status: status,
            limit: limit,
          );
        }
      }
    } catch (e) {
      debugPrint('MCP запрос не удался: $e');
    }

    // Fallback на прямой HTTP
    return _fetchDirectly(category: category, status: status, limit: limit);
  }

  /// Прямой HTTP запрос (fallback)
  Future<List<Map<String, dynamic>>> _fetchDirectly({
    String? category,
    String? status,
    int? limit,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/reports');
      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return _applyFilters(
          json.cast<Map<String, dynamic>>(),
          category: category,
          status: status,
          limit: limit,
        );
      }
    } catch (e) {
      debugPrint('Прямой HTTP запрос не удался: $e');
    }

    return [];
  }

  /// Получить жалобу по ID
  Future<Map<String, dynamic>?> getComplaintById(int id) async {
    try {
      final response = await _mcpService.callHTTP(
        'mcp_fetch',
        'fetch',
        params: {
          'url': '$_baseUrl/api/reports/$id',
          'method': 'GET',
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
      debugPrint('MCP запрос не удался: $e');
    }

    // Fallback
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/reports/$id'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Прямой HTTP запрос не удался: $e');
    }

    return null;
  }

  /// Создать новую жалобу
  Future<bool> createComplaint(Map<String, dynamic> complaint) async {
    try {
      final response = await _mcpService.callHTTP(
        'mcp_fetch',
        'fetch',
        params: {
          'url': '$_baseUrl/api/reports',
          'method': 'POST',
          'body': jsonEncode(complaint),
          'headers': {
            'Content-Type': 'application/json',
          },
        },
      );

      return response.isSuccess;
    } catch (e) {
      debugPrint('MCP запрос не удался: $e');
    }

    // Fallback
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/reports'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(complaint),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Прямой HTTP запрос не удался: $e');
      return false;
    }
  }

  /// Обновить жалобу
  Future<bool> updateComplaint(int id, Map<String, dynamic> updates) async {
    try {
      final response = await _mcpService.callHTTP(
        'mcp_fetch',
        'fetch',
        params: {
          'url': '$_baseUrl/api/reports/$id',
          'method': 'PUT',
          'body': jsonEncode(updates),
          'headers': {
            'Content-Type': 'application/json',
          },
        },
      );

      return response.isSuccess;
    } catch (e) {
      debugPrint('MCP запрос не удался: $e');
    }

    // Fallback
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/reports/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Прямой HTTP запрос не удался: $e');
      return false;
    }
  }

  /// Получить статистику
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final complaints = await getAllComplaints();

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
      debugPrint('Ошибка получения статистики: $e');
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
