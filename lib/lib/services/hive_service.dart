// lib/services/hive_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/complaint.dart';

/// Offline-first сервис на базе Hive
class HiveService {
  static Box? _complaintsBox;
  static Box? _draftsBox;
  static Box? _userBox;
  
  /// Инициализация Hive
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Регистрация адаптеров
    Hive.registerAdapter(ComplaintAdapter());
    
    // Открытие боксов
    _complaintsBox = await Hive.openBox('complaints');
    _draftsBox = await Hive.openBox('drafts');
    _userBox = await Hive.openBox('user');
  }
  
  /// Проверка подключения к интернету
  static Future<bool> get isConnected async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }
  
  // ========== Жалобы ==========
  
  /// Сохранить жалобу локально (кэш)
  static Future<void> cacheComplaint(Complaint complaint) async {
    await _complaintsBox?.put(complaint.id, complaint.toJson());
  }
  
  /// Получить кэшированные жалобы
  static List<Complaint> getCachedComplaints() {
    final complaints = _complaintsBox?.values ?? [];
    return complaints
        .map((json) => Complaint.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
  
  /// Очистить кэш
  static Future<void> clearCache() async {
    await _complaintsBox?.clear();
  }
  
  // ========== Черновики ==========
  
  /// Сохранить черновик
  static Future<void> saveDraft({
    required String key,
    required Map<String, dynamic> data,
  }) async {
    await _draftsBox?.put(key, {
      ...data,
      'saved_at': DateTime.now().toIso8601String(),
    });
  }
  
  /// Получить черновик
  static Map<String, dynamic>? getDraft(String key) {
    final draft = _draftsBox?.get(key);
    return draft != null ? Map<String, dynamic>.from(draft) : null;
  }
  
  /// Удалить черновик
  static Future<void> deleteDraft(String key) async {
    await _draftsBox?.delete(key);
  }
  
  /// Получить все черновики
  static List<Map<String, dynamic>> getAllDrafts() {
    final drafts = _draftsBox?.values ?? [];
    return drafts.map((d) => Map<String, dynamic>.from(d)).toList();
  }
  
  // ========== Офлайн очередь ==========
  
  /// Добавить в очередь на отправку
  static Future<void> queueForSync(Map<String, dynamic> complaint) async {
    final queue = _userBox?.get('sync_queue', defaultValue: []) ?? [];
    queue.add({
      ...complaint,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _userBox?.put('sync_queue', queue);
  }
  
  /// Получить очередь на синхронизацию
  static List<Map<String, dynamic>> getSyncQueue() {
    final queue = _userBox?.get('sync_queue', defaultValue: []) ?? [];
    return List<Map<String, dynamic>>.from(queue);
  }
  
  /// Очистить очередь
  static Future<void> clearSyncQueue() async {
    await _userBox?.put('sync_queue', []);
  }
  
  /// Удалить из очереди по индексу
  static Future<void> removeFromQueue(int index) async {
    final queue = getSyncQueue();
    if (index < queue.length) {
      queue.removeAt(index);
      await _userBox?.put('sync_queue', queue);
    }
  }
  
  // ========== Пользователь ==========
  
  /// Сохранить данные пользователя
  static Future<void> saveUserData(Map<String, dynamic> data) async {
    await _userBox?.put('profile', data);
  }
  
  /// Получить данные пользователя
  static Map<String, dynamic>? getUserData() {
    final data = _userBox?.get('profile');
    return data != null ? Map<String, dynamic>.from(data) : null;
  }
  
  /// Сохранить настройки
  static Future<void> saveSetting(String key, dynamic value) async {
    await _userBox?.put('setting_$key', value);
  }
  
  /// Получить настройку
  static T? getSetting<T>(String key, {T? defaultValue}) {
    return _userBox?.get('setting_$key', defaultValue: defaultValue) as T?;
  }
}

// Адаптер для Hive
class ComplaintAdapter extends TypeAdapter<Complaint> {
  @override
  final typeId = 0;
  
  @override
  Complaint read(BinaryReader reader) {
    return Complaint.fromJson(reader.readMap() as Map<String, dynamic>);
  }
  
  @override
  void write(BinaryWriter writer, Complaint obj) {
    writer.writeMap(obj.toJson());
  }
}
