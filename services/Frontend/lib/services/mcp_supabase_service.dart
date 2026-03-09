// lib/services/mcp_supabase_service.dart
/// Supabase Service для работы с Supabase REST API.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Конфигурация Supabase
class _SupabaseConfig {
  static const String url = 'https://xpainxohbdoruakcijyq.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';
  static const String restBase = '$url/rest/v1';
}

/// Сервис для работы с Supabase: запросы к REST API.
class MCPSupabaseService {
  static const Duration _timeout = Duration(seconds: 20);

  Map<String, String> get _headers => {
        'apikey': _SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${_SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  /// Получить все жалобы из Supabase
  Future<List<Map<String, dynamic>>> getComplaints({
    String? category,
    String? status,
    int? limit,
  }) async {
    try {
      var url =
          '${_SupabaseConfig.restBase}/complaints?select=*&order=created_at.desc';

      if (category != null) {
        url += '&category=eq.$category';
      }
      if (status != null) {
        url += '&status=eq.$status';
      }
      if (limit != null && limit > 0) {
        url += '&limit=$limit';
      } else {
        url += '&limit=500';
      }

      final response =
          await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Supabase getComplaints error: $e');
    }

    return [];
  }

  /// Получить жалобу по ID
  Future<Map<String, dynamic>?> getComplaintById(String id) async {
    try {
      final url = '${_SupabaseConfig.restBase}/complaints?id=eq.$id&select=*';
      final response =
          await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Supabase getComplaintById error: $e');
    }

    return null;
  }

  /// Добавить жалобу в Supabase
  Future<String?> addComplaint(Map<String, dynamic> complaint) async {
    try {
      final url = '${_SupabaseConfig.restBase}/complaints';
      final response = await http
          .post(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode(complaint),
          )
          .timeout(_timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.first['id']?.toString();
        }
      }
    } catch (e) {
      debugPrint('Supabase addComplaint error: $e');
    }

    return null;
  }

  /// Обновить жалобу в Supabase
  Future<bool> updateComplaint(String id, Map<String, dynamic> updates) async {
    try {
      final url = '${_SupabaseConfig.restBase}/complaints?id=eq.$id';
      final response = await http
          .patch(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode(updates),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Supabase updateComplaint error: $e');
      return false;
    }
  }

  /// Получить статистику из Supabase
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

      for (var complaint in complaints) {
        final category = complaint['category'] as String? ?? 'Прочее';
        stats['by_category'][category] =
            (stats['by_category'][category] as int? ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('Supabase statistics error: $e');
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
