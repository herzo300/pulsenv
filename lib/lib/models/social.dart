// lib/models/social.dart
/// Модели для социальных функций

/// Лайк
class Like {
  final int id;
  final int complaintId;
  final int userId;
  final DateTime createdAt;
  
  Like({
    required this.id,
    required this.complaintId,
    required this.userId,
    required this.createdAt,
  });
  
  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(
      id: json['id'] ?? 0,
      complaintId: json['complaint_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

/// Комментарий
class Comment {
  final int id;
  final int complaintId;
  final int userId;
  final String userName;
  final String text;
  final DateTime createdAt;
  final int? parentId; // Для ответов
  
  Comment({
    required this.id,
    required this.complaintId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.parentId,
  });
  
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      complaintId: json['complaint_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? 'Аноним',
      text: json['text'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      parentId: json['parent_id'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'complaint_id': complaintId,
      'text': text,
      'parent_id': parentId,
    };
  }
}

/// Репутация пользователя
class UserReputation {
  final int userId;
  final String userName;
  final int points;
  final int complaintsCount;
  final int resolvedCount;
  final int likesReceived;
  final String rank;
  final DateTime joinedAt;
  
  UserReputation({
    required this.userId,
    required this.userName,
    required this.points,
    required this.complaintsCount,
    required this.resolvedCount,
    required this.likesReceived,
    required this.rank,
    required this.joinedAt,
  });
  
  factory UserReputation.fromJson(Map<String, dynamic> json) {
    return UserReputation(
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? 'Аноним',
      points: json['points'] ?? 0,
      complaintsCount: json['complaints_count'] ?? 0,
      resolvedCount: json['resolved_count'] ?? 0,
      likesReceived: json['likes_received'] ?? 0,
      rank: json['rank'] ?? 'Новичок',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
    );
  }
  
  double get resolutionRate => 
      complaintsCount > 0 ? resolvedCount / complaintsCount : 0.0;
}

/// Ранги пользователей
class UserRanks {
  static const Map<int, String> ranks = {
    0: 'Новичок',
    100: 'Активист',
    500: 'Защитник города',
    1000: 'Городской герой',
    5000: 'Легенда',
  };
  
  static String getRank(int points) {
    String rank = 'Новичок';
    for (final entry in ranks.entries) {
      if (points >= entry.key) {
        rank = entry.value;
      }
    }
    return rank;
  }
}
