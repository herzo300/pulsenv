import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_catalog.dart';
import 'notification_message_formatter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  NotificationService._();
  factory NotificationService() => _instance;

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await AwesomeNotifications().initialize(
      null,
      [
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
      ],
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

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: compactBody,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Message,
        payload: notificationPayload,
        backgroundColor: const Color(0xFF0F0F23),
        color: descriptor.color,
      ),
    );
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
}
