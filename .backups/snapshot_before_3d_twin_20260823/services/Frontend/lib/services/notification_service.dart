import 'dart:async';
import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_catalog.dart';
import 'notification_message_formatter.dart';
import 'sound_service.dart';
import 'city_provider.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  NotificationService._();
  factory NotificationService() => _instance;

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final channels = <NotificationChannel>[
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'Уведомления о новых событиях в городе',
        defaultColor: const Color(0xFF00E5FF),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        onlyAlertOnce: true,
        playSound: true,
        criticalAlerts: true,
      ),
      NotificationChannel(
        channelKey: 'channel_jkh_community',
        channelName: 'Домовой чат и взаимопомощь соседей',
        channelDescription: 'Срочные просьбы соседей по дому и объявления УК',
        defaultColor: const Color(0xFF00E5FF),
        ledColor: const Color(0xFF00E5FF),
        importance: NotificationImportance.Max,
        channelShowBadge: true,
        onlyAlertOnce: false,
        playSound: true,
        criticalAlerts: true,
      ),
      NotificationChannel(
        channelKey: 'channel_emergency_nv',
        channelName: 'Экстренные городские оповещения',
        channelDescription: 'Аварии, паводок, штормовые предупреждения МЧС',
        defaultColor: const Color(0xFFEF4444),
        ledColor: const Color(0xFFEF4444),
        importance: NotificationImportance.Max,
        channelShowBadge: true,
        onlyAlertOnce: false,
        playSound: true,
        criticalAlerts: true,
      ),
    ];

    for (final descriptor in NotificationCatalog.defaults) {
      final name = descriptor.name;
      final sanitizedName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final channelKey = 'channel_${sanitizedName}_v3';
      final soundName = descriptor.soundAsset.replaceAll('.mp3', '');

      channels.add(
        NotificationChannel(
          channelKey: channelKey,
          channelName: '$name Notifications',
          channelDescription: 'Уведомления для категории $name',
          defaultColor: descriptor.color,
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          onlyAlertOnce: true,
          playSound: true,
          criticalAlerts: true,
          soundSource: 'resource://raw/$soundName',
        ),
      );
    }

    await AwesomeNotifications().initialize(
      null,
      channels,
      debug: false,
    );

    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    _initialized = true;
  }

  Future<void> showPushNotification({
    required int id,
    required String title,
    required String body,
    String? category,
    Map<String, String?>? payload,
    String channelKey = 'basic_channel',
    bool forceShow = false,
  }) async {
    await ensureInitialized();

    final normalizedCategory = NotificationCatalog.normalize(category);
    if (!await shouldNotify(normalizedCategory)) {
      return;
    }
    final descriptor = NotificationCatalog.describe(normalizedCategory);
    final compactBody = NotificationMessageFormatter.compact(
      body,
      fallback: title,
    );
    final notificationPayload = <String, String?>{
      'category': normalizedCategory,
    };
    if (payload != null && payload.isNotEmpty) {
      notificationPayload.addAll(payload);
    }

    // Город из payload — пуш показываем только для активного города.
    // Мониторинг в фоне идёт для всех, но системное уведомление только для выбранного.
    final pushCity = payload?['city'];
    final cityProvider = CityProvider();
    final isForActiveCity = cityProvider.isActiveCity(pushCity);

    final isResumed = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    // Strict Deduplication & Date Filter: Never push duplicate signals or signals older than 24h
    final prefs = await SharedPreferences.getInstance();
    final seenIds = prefs.getStringList('seen_pushed_notification_ids') ?? [];
    final reportId = payload?['report_id'] ?? '';
    final sig = '${id}_${reportId}_${title.trim().hashCode}_${compactBody.trim().hashCode}';
    final idStr = '$id';

    if (seenIds.contains(idStr) || seenIds.contains(sig) || (reportId.isNotEmpty && seenIds.contains('rep_$reportId'))) {
      return; // Already pushed before, strictly skip duplicate
    }

    final createdAtStr = payload?['created_at'];
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAtStr);
        if (DateTime.now().difference(dt).inHours > 24) {
          return; // Older than 24 hours, skip old historical signal
        }
      } catch (_) {}
    }

    // Mark as seen and limit set size to 1000
    seenIds.add(idStr);
    seenIds.add(sig);
    if (reportId.isNotEmpty) {
      seenIds.add('rep_$reportId');
    }
    while (seenIds.length > 1000) {
      seenIds.removeAt(0);
    }
    await prefs.setStringList('seen_pushed_notification_ids', seenIds);

    if (!isResumed || forceShow) {
      // Звук и системный пуш — только для активного города
      if (isForActiveCity) {
        unawaited(SoundService().playCategorySound(normalizedCategory));

        final voiceEnabled = prefs.getBool('voice_announcements_enabled') ?? false;
        if (voiceEnabled) {
          unawaited(SoundService().speak(title));
        }

        final sanitizedCategoryName = normalizedCategory.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
        final targetChannelKey = (category != null && category.isNotEmpty)
            ? 'channel_${sanitizedCategoryName}_v3'
            : channelKey;

        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: id,
            channelKey: targetChannelKey,
            title: title,
            body: compactBody,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Message,
            payload: notificationPayload,
            backgroundColor: const Color(0xFF0F0F23),
            color: descriptor.color,
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'SHOW_MAP',
              label: 'Показать на карте',
              actionType: ActionType.Default,
            ),
            NotificationActionButton(
              key: 'DETAILS',
              label: 'Подробнее',
              actionType: ActionType.Default,
            ),
          ],
        );
      }
    }
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await ensureInitialized();
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'basic_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(date: scheduledDate),
    );
  }

  Future<void> scheduleMorningAktirovkaPushes(dynamic weatherSnapshot) async {
    await ensureInitialized();
    final String status = weatherSnapshot?.hmaoAktirovkaStatus ?? '🟢 Занятия проводятся для всех классов (1-11)';
    final num temp = weatherSnapshot?.temperatureC ?? -12;
    final num wind = weatherSnapshot?.windSpeedMs ?? 3.5;

    try {
      // 06:15 AM Push for 1st Shift
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 8801,
          channelKey: 'basic_channel',
          title: '❄️ Актировка школ Нижневартовска (1 смена)',
          body: '$status (t: $temp°C, ветер: $wind м/с)',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
        ),
        schedule: NotificationCalendar(
          hour: 6,
          minute: 15,
          second: 0,
          repeats: true,
          allowWhileIdle: true,
        ),
      );

      // 11:30 AM Push for 2nd Shift
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 8802,
          channelKey: 'basic_channel',
          title: '❄️ Актировка школ Нижневартовска (2 смена)',
          body: '$status (t: $temp°C, ветер: $wind м/с)',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
        ),
        schedule: NotificationCalendar(
          hour: 11,
          minute: 30,
          second: 0,
          repeats: true,
          allowWhileIdle: true,
        ),
      );
    } catch (e) {
      debugPrint('Failed to schedule aktirovka push: $e');
    }
  }

  Future<void> sendHermesTaskCompletedPush({
    required String title,
    required String body,
    String? category,
  }) async {
    await ensureInitialized();
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'basic_channel',
          title: '🛡️ Гермес AI: $title',
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Message,
          backgroundColor: const Color(0xFF0F0F23),
          color: const Color(0xFF00E5FF),
        ),
      );
    } catch (e) {
      debugPrint('Failed to send Hermes task push: $e');
    }
  }

  Future<bool> shouldNotify(String category) async {
    final normalizedCategory = NotificationCatalog.normalize(category);
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (!enabled) {
      return false;
    }

    final savedCategories = prefs.getString('notification_categories');
    if (savedCategories == null) {
      return true;
    }

    final Map<String, dynamic> categories = jsonDecode(savedCategories);
    return categories[normalizedCategory] ?? categories[category] ?? true;
  }

  Future<void> showNewComplaintNotification(
    BuildContext context, {
    required String title,
    required String category,
    Color? color,
  }) async {
    final normalizedCategory = NotificationCatalog.normalize(category);
    if (!await shouldNotify(normalizedCategory)) {
      return;
    }
    final descriptor = NotificationCatalog.describe(normalizedCategory);
    final compactTitle = NotificationMessageFormatter.compact(
      title,
      maxLength: 90,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color ?? const Color(0xFF00E5FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (color ?? const Color(0xFF00E5FF)).withOpacity(0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Новый сигнал: $normalizedCategory',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    compactTitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1a1a2e),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: (color ?? descriptor.color).withOpacity(0.3),
          ),
        ),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  /// Send instant push notification for neighbor mutual aid in house community
  Future<void> showHouseAidNotification({
    required String address,
    required String title,
    required String description,
    String? author,
    String? type,
  }) async {
    await ensureInitialized();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    unawaited(SoundService().playPushNotification());

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'channel_jkh_community',
        title: '🏠 $address: $title',
        body: '$description ${author != null ? "— $author" : ""}',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Message,
        payload: {
          'screen': 'jkh_house',
          'address': address,
          'type': type ?? 'help',
        },
        backgroundColor: const Color(0xFF0F172A),
        color: const Color(0xFF00E5FF),
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'OPEN_HOUSE_CHAT',
          label: 'Открыть чат дома',
          actionType: ActionType.Default,
        ),
      ],
    );
  }

  /// Instant test push notification with sound and vibration
  Future<void> sendTestPushNotification() async {
    await ensureInitialized();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    unawaited(SoundService().playPushNotification());

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'channel_jkh_community',
        title: '🔔 Тестовое Push-уведомление City Pulse',
        body: 'Система Push-уведомлений и алертов Нижневартовска работает отлично! Звук и вибрация активны.',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Message,
        payload: {
          'screen': 'map',
          'test': 'true',
        },
        backgroundColor: const Color(0xFF0F172A),
        color: const Color(0xFF00E5FF),
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'DISMISS',
          label: 'Отлично',
          actionType: ActionType.DismissAction,
        ),
      ],
    );
  }
}
