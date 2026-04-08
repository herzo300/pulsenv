import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'backend_api_service.dart';

/// Локальная SQLite очередь черновиков для офлайн-режима.
class DraftBoxService {
  static final DraftBoxService instance = DraftBoxService._init();
  static Database? _db;

  DraftBoxService._init();

  final BackendApiService _backendApi = BackendApiService.instance;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB('draftbox.db');
    return _db!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE drafts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  lat REAL,
  lng REAL,
  address TEXT,
  category TEXT,
  image_path TEXT,
  timestamp INTEGER NOT NULL
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
    return database.insert('drafts', data);
  }

  Future<List<Map<String, dynamic>>> getPendingDrafts() async {
    final database = await db;
    return database.query('drafts', orderBy: 'timestamp ASC');
  }

  Future<int> deleteDraft(int id) async {
    final database = await db;
    return database.delete('drafts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> syncOnline() async {
    final drafts = await getPendingDrafts();
    if (drafts.isEmpty) return;

    debugPrint('DraftBoxService: found ${drafts.length} pending drafts. Syncing...');
    for (final draft in drafts) {
      final success = await _tryUpload(draft);
      if (success) {
        await deleteDraft(draft['id'] as int);
      }
    }
  }

  Future<bool> _tryUpload(Map<String, dynamic> draft) async {
    final payload = {
      'title': draft['title'],
      'description': draft['description'],
      'lat': draft['lat'],
      'lng': draft['lng'],
      'address': draft['address']?.toString().isEmpty == true ? null : draft['address'],
      'category': draft['category'],
      'status': 'open',
      'source': 'offline_draftbox',
      'likes_count': 0,
      'supporters': 0,
      'images': <String>[],
    };

    try {
      final response = await _backendApi.postJson(
        '/api/reports',
        payload,
        timeout: const Duration(seconds: 12),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (error) {
      debugPrint('DraftBoxService sync error: $error');
      return false;
    }
  }
}
