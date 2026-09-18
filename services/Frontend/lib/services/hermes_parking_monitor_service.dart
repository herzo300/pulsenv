import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:awesome_notifications/awesome_notifications.dart';
import '../map/map_config.dart';
import 'sound_service.dart';

class HermesParkingTask {
  final String cameraId;
  final String cameraName;
  final String streamUrl;
  final DateTime startedAt;
  int checkCount;
  bool isSpotFree;
  int lastVehicleCount;
  int lastEmptySpots;
  String parkingStatus; // 'available', 'moderate', 'full'
  final List<Map<String, dynamic>> history;

  HermesParkingTask({
    required this.cameraId,
    required this.cameraName,
    required this.streamUrl,
    required this.startedAt,
    this.checkCount = 0,
    this.isSpotFree = false,
    this.lastVehicleCount = 0,
    this.lastEmptySpots = 0,
    this.parkingStatus = 'unknown',
  }) : history = [];
}

class HermesParkingMonitorService {
  static final HermesParkingMonitorService instance = HermesParkingMonitorService._internal();

  HermesParkingMonitorService._internal();

  final Map<String, HermesParkingTask> _activeTasks = {};
  Timer? _periodicTimer;
  Timer? _dayMonitorTimer;

  List<HermesParkingTask> get activeTasks => _activeTasks.values.toList();
  bool isMonitoring(String cameraId) => _activeTasks.containsKey(cameraId);

  /// Start monitoring a single camera (5-minute interval)
  void startMonitoring({
    required String cameraId,
    required String cameraName,
    required String streamUrl,
    Function(String message)? onStatusUpdate,
  }) {
    HapticFeedback.mediumImpact();
    final task = HermesParkingTask(
      cameraId: cameraId,
      cameraName: cameraName,
      streamUrl: streamUrl,
      startedAt: DateTime.now(),
    );

    _activeTasks[cameraId] = task;
    onStatusUpdate?.call('🤖 Гермес AI начал мониторинг парковки на камере "$cameraName". Проверка каждые 5 мин.');

    _checkCameraParking(task);
    _ensureTimer();
  }

  /// Start day-long monitoring for multiple cameras (10-minute interval)
  void startDayMonitoring(List<Map<String, dynamic>> cameras) {
    for (final cam in cameras) {
      final id = cam['camera_id'] as String? ?? '';
      if (id.isEmpty || _activeTasks.containsKey(id)) continue;
      _activeTasks[id] = HermesParkingTask(
        cameraId: id,
        cameraName: cam['name'] as String? ?? 'Камера',
        streamUrl: cam['stream_url'] as String? ?? '',
        startedAt: DateTime.now(),
      );
    }
    _dayMonitorTimer?.cancel();
    _dayMonitorTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      for (final task in _activeTasks.values) {
        _checkCameraParking(task);
      }
    });
    // Initial check
    for (final task in _activeTasks.values) {
      _checkCameraParking(task);
    }
  }

  void stopMonitoring(String cameraId) {
    HapticFeedback.lightImpact();
    _activeTasks.remove(cameraId);
    if (_activeTasks.isEmpty) {
      _periodicTimer?.cancel();
      _periodicTimer = null;
      _dayMonitorTimer?.cancel();
      _dayMonitorTimer = null;
    }
  }

  void stopAll() {
    _activeTasks.clear();
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _dayMonitorTimer?.cancel();
    _dayMonitorTimer = null;
  }

  void _ensureTimer() {
    _periodicTimer ??= Timer.periodic(const Duration(minutes: 5), (_) {
      for (final task in _activeTasks.values) {
        _checkCameraParking(task);
      }
    });
  }

  Map<String, Map<String, dynamic>> getOccupancyStats() {
    final stats = <String, Map<String, dynamic>>{};
    for (final task in _activeTasks.values) {
      stats[task.cameraId] = {
        'name': task.cameraName,
        'vehicles': task.lastVehicleCount,
        'empty_spots': task.lastEmptySpots,
        'status': task.parkingStatus,
        'last_check': task.checkCount,
      };
    }
    return stats;
  }

  Future<void> _checkCameraParking(HermesParkingTask task) async {
    task.checkCount++;
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/api/parking/detect');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'camera_id': task.cameraId,
          'camera_name': task.cameraName,
          'camera_url': task.streamUrl,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final yolo = data['yolo'];
        int vehicleCount = 0;
        int emptySpots = 0;
        String status = 'unknown';

        if (yolo != null && yolo['counts'] != null) {
          vehicleCount = (yolo['counts']['vehicles'] as num?)?.toInt() ?? 0;
          emptySpots = (yolo['counts']['empty_spots_estimated'] as num?)?.toInt() ?? 0;
        }
        status = data['parking_status'] as String? ?? 'unknown';

        task.lastVehicleCount = vehicleCount;
        task.lastEmptySpots = emptySpots;
        task.parkingStatus = status;

        // Store history point
        task.history.add({
          'time': DateTime.now().toIso8601String(),
          'vehicles': vehicleCount,
          'empty_spots': emptySpots,
          'status': status,
        });
        // Keep last 144 entries (24h at 10-min intervals)
        if (task.history.length > 144) {
          task.history.removeAt(0);
        }

        final wasOccupied = !task.isSpotFree;
        if (emptySpots >= 3 || status == 'available') {
          task.isSpotFree = true;
          if (wasOccupied) {
            _notifySpotFree(task);
          }
        } else {
          task.isSpotFree = false;
        }
      }
    } catch (e) {
      debugPrint('Hermes parking check error: $e');
    }
  }

  /// Subscribe to Telegram push alerts for parking
  Future<bool> subscribeTelegramAlerts(String cameraId, int telegramId, {int threshold = 3}) async {
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/api/parking/subscribe');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'camera_id': cameraId,
          'telegram_id': telegramId,
          'threshold': threshold,
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  void _notifySpotFree(HermesParkingTask task) {
    HapticFeedback.heavyImpact();
    final spotsText = task.lastEmptySpots > 0 ? '~${task.lastEmptySpots} мест' : 'места';
    final message = '🅿️ Свободные $spotsText на камере "${task.cameraName}"! '
        'Авто: ${task.lastVehicleCount}. Статус: ${_statusEmoji(task.parkingStatus)}';

    // Voice announcement
    SoundService().speak('Внимание! На камере ${task.cameraName} свободно примерно ${task.lastEmptySpots} парковочных мест.');

    // Show Android push notification
    try {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: task.cameraId.hashCode.abs(),
          channelKey: 'basic_channel',
          title: '🅿️ Парковка: $spotsText свободно!',
          body: message,
          notificationLayout: NotificationLayout.Default,
          color: const Color(0xFF00E5FF),
          wakeUpScreen: true,
          category: NotificationCategory.Transport,
        ),
      );
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  String _statusEmoji(String status) {
    switch (status) {
      case 'available': return '✅ Свободно';
      case 'moderate': return '🟡 Умеренно';
      case 'full': return '🔴 Занято';
      default: return '❓ Неизвестно';
    }
  }
}
