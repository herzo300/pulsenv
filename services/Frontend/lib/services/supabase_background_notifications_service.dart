import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'supabase_runtime_config_service.dart';

const String _bgTaskName = 'com.soobshio.reports.background.refresh';
const String _bgTaskUniqueName = 'com.soobshio.reports.background.refresh';
const String _lastSeenReportIdKey = 'bg_last_seen_report_id';

@pragma('vm:entry-point')
void supabaseBackgroundTaskDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != _bgTaskName && task != Workmanager.iOSBackgroundTask) {
      return Future.value(true);
    }

    try {
      AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
            channelKey: 'basic_channel',
            channelName: 'Basic Notifications',
            channelDescription: 'Уведомления о новых событиях в городе',
            importance: NotificationImportance.High,
          ),
        ],
        debug: false,
      );

      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getInt(_lastSeenReportIdKey) ?? 0;
      final config = await SupabaseRuntimeConfigService.instance.loadPersistedConfig();
      if (!config.isReady) {
        return Future.value(true);
      }

      final uri = Uri.parse(config.reportsRestUrl).replace(
        queryParameters: {
          'select': 'id,title,category',
          'order': 'id.desc',
          'limit': '1',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': config.anonKey,
          'Authorization': 'Bearer ${config.anonKey}',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Future.value(false);
      }

      final payload = jsonDecode(response.body);
      if (payload is! List || payload.isEmpty) {
        return Future.value(true);
      }

      final latest = payload.first as Map<String, dynamic>;
      final reportId = _toInt(latest['id']) ?? previous;
      final title = (latest['title']?.toString() ?? 'Новая жалоба').trim();
      final category = (latest['category']?.toString() ?? 'Прочее').trim();

      if (reportId > previous && previous > 0) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: reportId,
            channelKey: 'basic_channel',
            title: 'Новая жалоба: ${category.isEmpty ? 'Прочее' : category}',
            body: title.isEmpty ? 'Откройте карту для деталей' : title,
            notificationLayout: NotificationLayout.Default,
            payload: {'report_id': '$reportId', 'category': category},
          ),
        );
      }

      if (reportId > previous) {
        await prefs.setInt(_lastSeenReportIdKey, reportId);
      }
      return Future.value(true);
    } catch (error) {
      debugPrint('Workmanager background sync failed: $error');
      return Future.value(false);
    }
  });
}

class SupabaseBackgroundNotificationsService {
  SupabaseBackgroundNotificationsService._();

  static final SupabaseBackgroundNotificationsService instance =
      SupabaseBackgroundNotificationsService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (!_supportsBackgroundWorker) return;
    if (_initialized) return;
    await Workmanager().initialize(
      supabaseBackgroundTaskDispatcher,
      isInDebugMode: kDebugMode,
    );

    await Workmanager().registerPeriodicTask(
      _bgTaskUniqueName,
      _bgTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 2),
    );
    _initialized = true;
  }

  Future<void> primeLastSeenReportId() async {
    if (!_supportsBackgroundWorker) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_lastSeenReportIdKey)) {
        return;
      }
      final config = await SupabaseRuntimeConfigService.instance.loadPersistedConfig();
      if (!config.isReady) {
        return;
      }

      final uri = Uri.parse(config.reportsRestUrl).replace(
        queryParameters: {
          'select': 'id',
          'order': 'id.desc',
          'limit': '1',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': config.anonKey,
          'Authorization': 'Bearer ${config.anonKey}',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final payload = jsonDecode(response.body);
      if (payload is List && payload.isNotEmpty) {
        final id = _toInt(payload.first['id']);
        if (id != null) {
          await prefs.setInt(_lastSeenReportIdKey, id);
        }
      }
    } catch (error) {
      debugPrint('primeLastSeenReportId failed: $error');
    }
  }

  bool get _supportsBackgroundWorker =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
