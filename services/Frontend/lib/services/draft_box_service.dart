import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import '../map/map_config.dart';

/// Локальная SQLite очередь (Черновики/Оффлайн)
/// Если нет сети или Supabase в спячке — сохраняем сюда.
class DraftBoxService {
  static final DraftBoxService instance = DraftBoxService._init();
  static Database? _db;

  DraftBoxService._init();

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB('draftbox.db');
    return _db!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE drafts (
  id $idType,
  title $textType,
  description $textType,
  lat REAL,
  lng REAL,
  address TEXT,
  category TEXT,
  image_path TEXT,
  timestamp $intType
)
''');
  }

  Future<int> saveDraft({
    required String title,
    required String description,
    required double lat,
    required double lng,
    String? address,
    required String category,
    String? imagePath,
  }) async {
    final database = await db;
    final data = {
      'title': title,
      'description': description,
      'lat': lat,
      'lng': lng,
      'address': address ?? '',
      'category': category,
      'image_path': imagePath ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return await database.insert('drafts', data);
  }

  Future<List<Map<String, dynamic>>> getPendingDrafts() async {
    final database = await db;
    return await database.query('drafts', orderBy: 'timestamp ASC');
  }

  Future<int> deleteDraft(int id) async {
    final database = await db;
    return await database.delete(
      'drafts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Синхронизация: пробрасывает все черновики в онлайн
  /// Если Supabase упал, переключаемся на Запасной сервер (Россия)
  Future<void> syncOnline() async {
    final drafts = await getPendingDrafts();
    if (drafts.isEmpty) return;

    debugPrint('DraftBoxService: Found ${drafts.length} pending drafts. Syncing...');

    for (var draft in drafts) {
      bool success = await _tryUpload(draft);
      if (success) {
        await deleteDraft(draft['id']);
      }
    }
  }

  Future<bool> _tryUpload(Map<String, dynamic> draft) async {
    final primaryUrl = MapConfig.reportsRestUrl;
    final fallbackUrl = 'https://api.ru-soobshio.ru/sync_report'; // Запасной дубликат базы в РФ

    final payload = {
      'title': draft['title'],
      'description': draft['description'],
      'lat': draft['lat'],
      'lng': draft['lng'],
      'address': draft['address']?.isEmpty == true ? null : draft['address'],
      'category': draft['category'],
      'status': 'open',
      'source': 'offline_draftbox',
      'likes_count': 0,
      'supporters': 0,
      // В реальном проекте imagePath загружается заново перед отправкой, отправляем пустым или Base64
      'images': [] 
    };

    final body = jsonEncode(payload);

    try {
      // 1. Попытка Primary (Supabase)
      final resPrimary = await http.post(
        Uri.parse(primaryUrl),
        headers: {
          'Content-Type': 'application/json',
          'apikey': MapConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${MapConfig.supabaseAnonKey}',
          'Prefer': 'return=minimal'
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (resPrimary.statusCode >= 200 && resPrimary.statusCode < 300) {
        return true;
      }
    } catch (_) {
      debugPrint('Primary Supabase fallback timeout or node down!');
    }

    try {
      // 2. Попытка Fallback (Россия)
      final resFallback = await http.post(
        Uri.parse(fallbackUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (resFallback.statusCode >= 200 && resFallback.statusCode < 300) {
        debugPrint('Success uploaded to fallback Russian server!');
        return true;
      }
    } catch (_) {
      // Оба сервера лежат 
    }

    return false;
  }
}
