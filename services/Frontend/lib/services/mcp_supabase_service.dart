// lib/services/mcp_supabase_service.dart
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../map/map_config.dart';

/// Supabase REST wrapper used by MCP-oriented screens.
class MCPSupabaseService {
  static const Duration _timeout = Duration(seconds: 20);

  bool get _isConfigured => MapConfig.hasSupabaseConfig;
  String get _restBase => MapConfig.supabaseRestBaseUrl;

  Map<String, String> get _headers => {
        'apikey': MapConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${MapConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  Future<List<Map<String, dynamic>>> getComplaints({
    String? category,
    String? status,
    int? limit,
  }) async {
    if (!_isConfigured) {
      debugPrint('Supabase getComplaints skipped: runtime config is unavailable');
      return [];
    }

    try {
      var url = '$_restBase/complaints?select=*&order=created_at.desc';

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
    } catch (error) {
      debugPrint('Supabase getComplaints error: $error');
    }

    return [];
  }

  Future<Map<String, dynamic>?> getComplaintById(String id) async {
    if (!_isConfigured) {
      debugPrint(
        'Supabase getComplaintById skipped: runtime config is unavailable',
      );
      return null;
    }

    try {
      final url = '$_restBase/complaints?id=eq.$id&select=*';
      final response =
          await http.get(Uri.parse(url), headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.first as Map<String, dynamic>;
        }
      }
    } catch (error) {
      debugPrint('Supabase getComplaintById error: $error');
    }

    return null;
  }

  Future<String?> addComplaint(Map<String, dynamic> complaint) async {
    if (!_isConfigured) {
      debugPrint('Supabase addComplaint skipped: runtime config is unavailable');
      return null;
    }

    try {
      final url = '$_restBase/complaints';
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
    } catch (error) {
      debugPrint('Supabase addComplaint error: $error');
    }

    return null;
  }

  Future<bool> updateComplaint(String id, Map<String, dynamic> updates) async {
    if (!_isConfigured) {
      debugPrint(
        'Supabase updateComplaint skipped: runtime config is unavailable',
      );
      return false;
    }

    try {
      final url = '$_restBase/complaints?id=eq.$id';
      final response = await http
          .patch(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode(updates),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (error) {
      debugPrint('Supabase updateComplaint error: $error');
      return false;
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final complaints = await getComplaints();

      final stats = <String, dynamic>{
        'total': complaints.length,
        'open': complaints.where((item) => item['status'] == 'open').length,
        'pending': complaints.where((item) => item['status'] == 'pending').length,
        'resolved':
            complaints.where((item) => item['status'] == 'resolved').length,
        'by_category': <String, int>{},
      };

      for (final complaint in complaints) {
        final category = complaint['category'] as String? ?? 'Прочее';
        stats['by_category'][category] =
            (stats['by_category'][category] as int? ?? 0) + 1;
      }

      return stats;
    } catch (error) {
      debugPrint('Supabase statistics error: $error');
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
