import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_catalog.dart';
import 'notification_message_formatter.dart';
import 'reports_repository.dart';

const String _bgTaskName = 'com.soobshio.reports.background.refresh';
const String _bgTaskUniqueName = 'com.soobshio.reports.background.refresh';
const String _lastSeenReportIdKey = 'bg_last_seen_report_id';

Future<bool> _shouldNotifyCategory(String category) async {
  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool('notifications_enabled') ?? true;
  if (!enabled) return false;

  final rawMap = prefs.getString('notification_categories');
  if (rawMap == null || rawMap.isEmpty) {
    return true;
  }

  try {
    final saved = Map<String, dynamic>.from(
      jsonDecode(rawMap) as Map<String, dynamic>,
    );
    final normalized = NotificationCatalog.normalize(category);
    return saved[normalized] ?? saved[category] ?? true;
  } catch (_) {
    return true;
  }
}

@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
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
      final latestReport = await ReportsRepository.instance.fetchLatestReportSummary();
      if (latestReport == null) {
        return Future.value(true);
      }

      final latestReportId = latestReport['id'] is int
          ? latestReport['id'] as int
          : int.tryParse('${latestReport['id']}');
      if (latestReportId == null) {
        return Future.value(true);
      }

      final category = NotificationCatalog.normalize(
        latestReport['category']?.toString(),
      );
      final title = latestReport['title']?.toString().trim().isNotEmpty == true
          ? latestReport['title'].toString().trim()
          : 'Откройте карту для деталей';
      final body = NotificationMessageFormatter.compact(
        latestReport['summary']?.toString(),
        fallback: latestReport['description']?.toString() ?? title,
      );
      final descriptor = NotificationCatalog.describe(category);

      if (latestReportId > previous &&
          previous > 0 &&
          await _shouldNotifyCategory(category)) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: latestReportId,
            channelKey: 'basic_channel',
            title: 'Новый сигнал: $category',
            body: body,
            notificationLayout: NotificationLayout.Default,
            color: descriptor.color,
            payload: {
              'report_id': '$latestReportId',
              'category': category,
              if (latestReport['lat'] != null) 'lat': '${latestReport['lat']}',
              if (latestReport['lng'] != null) 'lng': '${latestReport['lng']}',
            },
          ),
        );
      }

      if (latestReportId > previous) {
        await prefs.setInt(_lastSeenReportIdKey, latestReportId);
      }
      return Future.value(true);
    } catch (error) {
      debugPrint('Workmanager background sync failed: $error');
      return Future.value(false);
    }
  });
}

class BackgroundNotificationsService {
  BackgroundNotificationsService._();

  static final BackgroundNotificationsService instance =
      BackgroundNotificationsService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (!_supportsBackgroundWorker) return;
    if (_initialized) return;
    await Workmanager().initialize(
      backgroundTaskDispatcher,
      isInDebugMode: kDebugMode,
    );

    await Workmanager().registerPeriodicTask(
      _bgTaskUniqueName,
      _bgTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
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
      final latestId = await ReportsRepository.instance.fetchLatestReportId();
      if (latestId != null) {
        await prefs.setInt(_lastSeenReportIdKey, latestId);
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
