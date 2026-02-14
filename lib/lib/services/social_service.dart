// lib/services/social_service.dart
import 'api_service.dart';
import '../models/social.dart';

/// Сервис социальных функций
class SocialService {
  // ========== Лайки ==========
  
  /// Лайкнуть жалобу
  static Future<bool> likeComplaint(int complaintId) async {
    try {
      final response = await ApiService.post('/complaints/$complaintId/like', {});
      return response['success'] ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Убрать лайк
  static Future<bool> unlikeComplaint(int complaintId) async {
    try {
      final response = await ApiService.delete('/complaints/$complaintId/like');
      return response['success'] ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Получить количество лайков
  static Future<int> getLikesCount(int complaintId) async {
    try {
      final response = await ApiService.get('/complaints/$complaintId/likes');
      return response['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Проверить, лайкнул ли пользователь
  static Future<bool> hasLiked(int complaintId) async {
    try {
      final response = await ApiService.get('/complaints/$complaintId/liked');
      return response['liked'] ?? false;
    } catch (e) {
      return false;
    }
  }
  
  // ========== Комментарии ==========
  
  /// Получить комментарии к жалобе
  static Future<List<Comment>> getComments(int complaintId) async {
    try {
      final response = await ApiService.get('/complaints/$complaintId/comments');
      return (response as List).map((c) => Comment.fromJson(c)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Добавить комментарий
  static Future<Comment?> addComment({
    required int complaintId,
    required String text,
    int? parentId,
  }) async {
    try {
      final response = await ApiService.post('/complaints/$complaintId/comments', {
        'text': text,
        'parent_id': parentId,
      });
      return Comment.fromJson(response);
    } catch (e) {
      return null;
    }
  }
  
  /// Удалить комментарий
  static Future<bool> deleteComment(int commentId) async {
    try {
      final response = await ApiService.delete('/comments/$commentId');
      return response['success'] ?? false;
    } catch (e) {
      return false;
    }
  }
  
  // ========== Репутация ==========
  
  /// Получить репутацию пользователя
  static Future<UserReputation?> getUserReputation(int userId) async {
    try {
      final response = await ApiService.get('/users/$userId/reputation');
      return UserReputation.fromJson(response);
    } catch (e) {
      return null;
    }
  }
  
  /// Получить топ пользователей
  static Future<List<UserReputation>> getTopUsers({int limit = 10}) async {
    try {
      final response = await ApiService.get('/users/top?limit=$limit');
      return (response as List).map((u) => UserReputation.fromJson(u)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Получить рейтинг пользователя
  static Future<int> getUserRank(int userId) async {
    try {
      final response = await ApiService.get('/users/$userId/rank');
      return response['rank'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
