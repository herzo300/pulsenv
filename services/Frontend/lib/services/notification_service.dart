import 'dart:convert';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис локальных и пуш уведомлений на базе Awesome Notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  NotificationService._() {
    _initNotifications();
  }
  factory NotificationService() => _instance;

  Future<void> _initNotifications() async {
    // Проверка разрешений при инициализации
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  /// Показывает пуш-уведомление
  Future<void> showPushNotification({
    required int id,
    required String title,
    required String body,
    String? category,
    String channelKey = 'basic_channel',
  }) async {
    // Проверяем настройки пользователя
    if (category != null && !await shouldNotify(category)) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Message,
        payload: {'category': category ?? 'General'},
        backgroundColor: const Color(0xFF0F0F23),
        color: const Color(0xFF00E5FF),
      ),
    );
  }

  /// Устанавливает напоминание на определенное время
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
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

  /// Проверяет, включены ли уведомления для данной категории
  Future<bool> shouldNotify(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (!enabled) return false;

    final savedCategories = prefs.getString('notification_categories');
    if (savedCategories == null) return true; // all enabled by default

    final Map<String, dynamic> categories = jsonDecode(savedCategories);
    return categories[category] ?? true;
  }

  /// Показывает in-app уведомление (SnackBar) о новой жалобе
  Future<void> showNewComplaintNotification(
    BuildContext context, {
    required String title,
    required String category,
    Color? color,
  }) async {
    if (!await shouldNotify(category)) return;

    if (!context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

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
                    'Новая жалоба: $category',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
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
            color: (color ?? const Color(0xFF00E5FF)).withOpacity(0.3),
          ),
        ),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
