library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/mcp_config.dart';
import 'mcp_service.dart';

class MCPComplaintsService {
  final MCPService _mcpService = MCPService();

  String get _baseUrl => MCPConfig.reportsApiUrl.replaceFirst('/api/reports', '');

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

  Future<List<Map<String, dynamic>>> getAllComplaints({
    String? category,
    String? status,
    int? limit,
  }) async {
    if (MCPConfig.reportsApiUrl.isEmpty) {
      return [];
    }

    try {
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
    } catch (error) {
      debugPrint('MCP request failed: $error');
    }

    return _fetchDirectly(category: category, status: status, limit: limit);
  }

  Future<List<Map<String, dynamic>>> _fetchDirectly({
    String? category,
    String? status,
    int? limit,
  }) async {
    if (MCPConfig.reportsApiUrl.isEmpty) {
      return [];
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/reports');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return _applyFilters(
          json.cast<Map<String, dynamic>>(),
          category: category,
          status: status,
          limit: limit,
        );
      }
    } catch (error) {
      debugPrint('Direct HTTP request failed: $error');
    }

    return [];
  }

  Future<Map<String, dynamic>?> getComplaintById(int id) async {
    if (MCPConfig.reportsApiUrl.isEmpty) {
      return null;
    }

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
    } catch (error) {
      debugPrint('MCP request failed: $error');
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/reports/$id'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (error) {
      debugPrint('Direct HTTP request failed: $error');
    }

    return null;
  }

  Future<bool> createComplaint(Map<String, dynamic> complaint) async {
    if (MCPConfig.reportsApiUrl.isEmpty) {
      return false;
    }

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
    } catch (error) {
      debugPrint('MCP request failed: $error');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/reports'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(complaint),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (error) {
      debugPrint('Direct HTTP request failed: $error');
      return false;
    }
  }

  Future<bool> updateComplaint(int id, Map<String, dynamic> updates) async {
    if (MCPConfig.reportsApiUrl.isEmpty) {
      return false;
    }

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
    } catch (error) {
      debugPrint('MCP request failed: $error');
    }

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/reports/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (error) {
      debugPrint('Direct HTTP request failed: $error');
      return false;
    }
  }

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

      for (final complaint in complaints) {
        final category = complaint['category'] as String? ?? 'Прочее';
        stats['by_category'][category] =
            (stats['by_category'][category] as int? ?? 0) + 1;
      }

      return stats;
    } catch (error) {
      debugPrint('Statistics request failed: $error');
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
