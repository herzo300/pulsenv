import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../map/map_config.dart';

/// Модель исходящего действия в очереди офлайн-синхронизации
class OfflineActionItem {
  final String id;
  final String actionType; // 'create_report', 'submit_meter', 'post_mutual_aid'
  final Map<String, dynamic> payload;
  final int timestamp;
  int retryCount;

  OfflineActionItem({
    required this.id,
    required this.actionType,
    required this.payload,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'actionType': actionType,
    'payload': payload,
    'timestamp': timestamp,
    'retryCount': retryCount,
  };

  factory OfflineActionItem.fromJson(Map<String, dynamic> json) => OfflineActionItem(
    id: json['id'] as String,
    actionType: json['actionType'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    timestamp: json['timestamp'] as int,
    retryCount: (json['retryCount'] as int?) ?? 0,
  );
}

/// Высокопроизводительный движок офлайн-синхронизации (Offline-First Delta Sync Engine)
class OfflineSyncEngine extends ChangeNotifier {
  static final OfflineSyncEngine _instance = OfflineSyncEngine._internal();
  factory OfflineSyncEngine() => _instance;
  OfflineSyncEngine._internal();

  static const String _queueKey = 'soobshio_offline_action_queue_v1';
  static const String _lastSyncKey = 'soobshio_last_delta_sync_timestamp';

  final List<OfflineActionItem> _pendingQueue = [];
  bool _isSyncing = false;
  int _lastSyncTimestamp = 0;
  Timer? _periodicTimer;

  List<OfflineActionItem> get pendingQueue => List.unmodifiable(_pendingQueue);
  int get pendingCount => _pendingQueue.length;
  bool get isSyncing => _isSyncing;
  int get lastSyncTimestamp => _lastSyncTimestamp;

  /// Инициализация очереди и запуск периодического синка
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSyncTimestamp = prefs.getInt(_lastSyncKey) ?? 0;

    final rawQueue = prefs.getStringList(_queueKey) ?? [];
    _pendingQueue.clear();
    for (final raw in rawQueue) {
      try {
        final decoded = json.decode(raw);
        _pendingQueue.add(OfflineActionItem.fromJson(decoded));
      } catch (_) {}
    }

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      syncPendingActions();
    });

    notifyListeners();
  }

  /// Постановка действия в локальную очередь
  Future<void> enqueueAction({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    final item = OfflineActionItem(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}_${_pendingQueue.length}',
      actionType: actionType,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _pendingQueue.add(item);
    await _persistQueue();
    notifyListeners();

    // Немедленная попытка отправить, если сеть доступна
    syncPendingActions();
  }

  /// Синхронизация накопленных действий с сервером
  Future<void> syncPendingActions() async {
    if (_isSyncing || _pendingQueue.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    final List<OfflineActionItem> toRemove = [];

    for (final item in List<OfflineActionItem>.from(_pendingQueue)) {
      try {
        bool success = false;
        if (item.actionType == 'create_report') {
          final res = await http.post(
            Uri.parse('${MapConfig.backendApiBaseUrl}/api/reports/create'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(item.payload),
          ).timeout(const Duration(seconds: 8));
          success = res.statusCode == 200 || res.statusCode == 201;
        } else {
          // Универсальная дельта-обработка
          final res = await http.post(
            Uri.parse('${MapConfig.backendApiBaseUrl}/api/sync/action'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(item.toJson()),
          ).timeout(const Duration(seconds: 8));
          success = res.statusCode == 200;
        }

        if (success) {
          toRemove.add(item);
        } else {
          item.retryCount++;
        }
      } catch (e) {
        item.retryCount++;
      }
    }

    for (final rem in toRemove) {
      _pendingQueue.removeWhere((i) => i.id == rem.id);
    }

    await _persistQueue();
    _isSyncing = false;
    notifyListeners();
  }

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = _pendingQueue.map((i) => json.encode(i.toJson())).toList();
    await prefs.setStringList(_queueKey, stringList);
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
