import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../map/map_config.dart';

/// -------------------------------------------------------------
/// OFFLINE MESH SERVICE (По мотивам Crisis Mesh Messenger)
/// 
/// Логика "Store and Forward" (Сохранить и Передать дальше):
/// 1. При отсутствии интернета жалоба (проблема) сохраняется в локальную БД.
/// 2. Служба (Nearby / BLE) постоянно ищет соседние смартфоны с приложением.
/// 3. Смартфоны обмениваются кэшированными жалобами по Bluetooth/Wi-Fi Direct.
/// 4. Если ХОТЯ БЫ ОДИН смартфон или узел поймал интернет (вышел из зоны ЧС),
///    он автоматически выгружает ВСЕ накопленные жалобы всей подсети на бэкенд.
/// -------------------------------------------------------------
class OfflineMeshService extends ChangeNotifier {
  static final OfflineMeshService _instance = OfflineMeshService._internal();

  factory OfflineMeshService() {
    return _instance;
  }

  static const String _storageKey = 'mesh_offline_queue';
  static String get _backendUrl => '${MapConfig.backendBaseUrl}/complaints';

  List<Map<String, dynamic>> _offlineQueue = [];
  bool _isScanning = false;
  int _connectedPeers = 0;
  Timer? _syncTimer;

  List<Map<String, dynamic>> get offlineQueue => _offlineQueue;
  bool get isScanning => _isScanning;
  int get connectedPeers => _connectedPeers;

  OfflineMeshService._internal() {
    _loadLocalQueue();
    // Пытаемся синхронизировать данные с сервером каждую минуту
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _attemptBackendSync();
    });
  }

  /// 1. ЗАГРУЗКА ЛОКАЛЬНОГО КЭША
  Future<void> _loadLocalQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      final List<dynamic> decoded = json.decode(jsonString);
      _offlineQueue = decoded.cast<Map<String, dynamic>>();
      notifyListeners();
    }
  }

  /// 2. ИЩЕМ ИНТЕРНЕТ И ВЫГРУЖАЕМ (Выход в онлайн)
  Future<void> _attemptBackendSync() async {
    if (_offlineQueue.isEmpty) return;

    // Быстрая проверка связи (PING)
    bool hasInternet = false;
    try {
      final response = await http
          .get(Uri.parse('${MapConfig.backendBaseUrl}/health'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) hasInternet = true;
    } catch (_) {
      hasInternet = false;
    }

    if (!hasInternet) return;

    // Если связь есть — выгружаем пачкой (Store-And-Forward завершен)
    List<Map<String, dynamic>> failedUploads = [];

    for (final complaint in _offlineQueue) {
      try {
        final payload = <String, dynamic>{
          'title': (complaint['title'] ?? complaint['category'] ?? 'Сообщение')
              .toString(),
          'description': (complaint['description'] ?? '').toString(),
          'latitude': complaint['latitude'] ?? complaint['lat'],
          'longitude': complaint['longitude'] ?? complaint['lng'],
          'address': complaint['address'],
          'category': (complaint['category'] ?? 'other').toString(),
          'status': (complaint['status'] ?? 'open').toString(),
          'user_id': complaint['user_id'],
          'telegram_channel': complaint['telegram_channel'],
        };
        final res = await http.post(
          Uri.parse(_backendUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        );
        if (res.statusCode != 200 && res.statusCode != 201) {
          failedUploads.add(complaint); // Ошибка на бэкенде? Сохраняем обратно
        }
      } catch (e) {
        failedUploads.add(complaint);
      }
    }

    _offlineQueue = failedUploads;
    await _saveQueue();
    notifyListeners();
  }

  /// 3. СОЗДАНИЕ ЖАЛОБЫ (Применяется на экране карты)
  Future<void> enqueueMeshComplaint(Map<String, dynamic> complaintData) async {
    // Добавляем уникальный Mesh ID, чтобы соседи не дублировали
    if (!complaintData.containsKey('mesh_id')) {
      complaintData['mesh_id'] = DateTime.now().millisecondsSinceEpoch.toString();
    }
    
    _offlineQueue.add(complaintData);
    await _saveQueue();
    notifyListeners();

    // Сразу пытаемся отправить
    _attemptBackendSync();
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_storageKey, json.encode(_offlineQueue));
  }

  /// ------------------------------------------------------------------
  /// АППАРАТНАЯ P2P ЧАСТЬ (Bluetooth LE / Wi-Fi Direct MOCK)
  /// В реальном продакшене тут будет использоваться пакет flutter_nearby_connections
  /// или react_ble_mesh.
  /// ------------------------------------------------------------------
  void startMeshDiscovery() {
    _isScanning = true;
    notifyListeners();
    
    // Имитация сканирования соседних телефонов волонтеров
    Future.delayed(const Duration(seconds: 4), () {
      _connectedPeers = 2; // Нашли 2 устройства рядом!
      _mergeWithPeers();
      notifyListeners();
    });
  }

  void stopMeshDiscovery() {
    _isScanning = false;
    _connectedPeers = 0;
    notifyListeners();
  }

  /// Эмуляция смешивания списков проблем двух телефонов (Epidemic Routing)
  void _mergeWithPeers() async {
    // В реальности: BluetoothChannel.receive()
    List<Map<String, dynamic>> peerData = [
      {
        "mesh_id": "emergency_911_mock",
        "title": "[OFFLINE] Упало дерево на дорогу",
        "description": "Передано по цепочке",
        "category": "road_hazard",
        "lat": 55.75,
        "lng": 37.61,
        "source": "mesh_peer"
      }
    ];

    bool addedNew = false;
    for (var peerItem in peerData) {
      // Проверяем, есть ли уже этот mesh_id у нас
      if (!_offlineQueue.any((item) => item['mesh_id'] == peerItem['mesh_id'])) {
        _offlineQueue.add(peerItem);
        addedNew = true;
      }
    }

    if (addedNew) {
      debugPrint("Mesh: Получены новые проблемы от соседей!");
      await _saveQueue();
      notifyListeners();
      // Получив новые данные, мы снова дергаем выгрузку (вдруг у нас ТОЧНО есть сеть?)
      _attemptBackendSync();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
