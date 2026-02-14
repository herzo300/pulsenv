// lib/services/notification_service.dart
import "dart:io";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter/foundation.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:dio/dio.dart";

/// Сервис push-уведомлений
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000',
    connectTimeout: const Duration(seconds: 10),
  ));

  static bool _isInitialized = false;
  static String? _fcmToken;

  /// Инициализация уведомлений
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Инициализация локальных уведомлений
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      ),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Инициализация Firebase Messaging
    final messaging = FirebaseMessaging.instance;
    
    // Запрос разрешений
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Разрешения уведомлений: ${settings.authorizationStatus}');

    // Получение FCM токена
    messaging.getToken(
      vapidKey: "BEl62iUYgUivxIkt69VxTVA97W6WZc8Jt7sVJ5Ht4hK2v9J6vX-7J9gK9u9q8k8Y8K8K8",
    ).then((token) {
      _fcmToken = token;
      debugPrint('FCM Token: $token');
      _saveTokenToServer(token);
    });

    // Обработка сообщений в foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Уведомление в foreground: ${message.notification?.title}');
      _showLocalNotification(
        title: message.notification?.title ?? 'Новое уведомление',
        body: message.notification?.body ?? '',
        payload: message.data.toString(),
      );
    });

    // Обработка сообщений при открытии приложения
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Уведомление открыто: ${message.notification?.title}');
      _onNotificationTapped(NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: message.data.toString(),
      ));
    });

    // Проверка фоновых сообщений
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Фоновое уведомление при запуске: ${initialMessage.notification?.title}');
    }

    _isInitialized = true;
  }

  /// Обработка нажатия на уведомление
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      debugPrint('Открыта жалоба: $payload');
      // TODO: Навигация к детали жалобы
      // navigatorKey.currentState?.pushNamed('/complaint-details', arguments: payload);
    }
  }

  /// Показ локального уведомления
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'soobshio_channel',
      channelDescription: 'Канал уведомлений СообщиО',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Сохранение токена на сервере
  static Future<void> _saveTokenToServer(String token) async {
    try {
      debugPrint('Сохранение FCM токена на сервере...');
      
      final response = await _dio.post(
        '/api/fcm-token',
        data: {
          'token': token,
          'user_id': null, // TODO: Получить user_id из AuthService
          'device_type': _getDeviceType(),
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('FCM токен успешно зарегистрирован');
        
        // Автоподписка на тему всех кластеров
        await subscribeToTopic('all');
      } else {
        debugPrint('Ошибка регистрации токена: ${response.data}');
      }
    } catch (e) {
      debugPrint('Ошибка сохранения FCM токена: $e');
    }
  }

  /// Подписка на тему
  static Future<void> subscribeToTopic(String topic) async {
    try {
      debugPrint('Подписка на тему: $topic');
      
      if (_fcmToken == null) {
        debugPrint('FCM токен не получен');
        return;
      }
      
      // Подписка через Firebase
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('Успешно подписаны на Firebase тему: $topic');
      
      // Отправка на сервер
      final response = await _dio.post(
        '/api/fcm/subscribe',
        data: {
          'token': _fcmToken,
          'topic': topic,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('Подписка на тему зарегистрирована на сервере');
      } else {
        debugPrint('Ошибка регистрации подписки: ${response.data}');
      }
    } catch (e) {
      debugPrint('Ошибка подписки на тему: $e');
    }
  }

  /// Отписка от темы
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      debugPrint('Отписка от темы: $topic');
      
      if (_fcmToken == null) {
        debugPrint('FCM токен не получен');
        return;
      }
      
      // Отписка через Firebase
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('Успешно отписаны от Firebase темы: $topic');
      
      // Отправка на сервер
      final response = await _dio.post(
        '/api/fcm/unsubscribe',
        data: {
          'token': _fcmToken,
          'topic': topic,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('Отписка от темы зарегистрирована на сервере');
      } else {
        debugPrint('Ошибка регистрации отписки: ${response.data}');
      }
    } catch (e) {
      debugPrint('Ошибка отписки от темы: $e');
    }
  }

  /// Получение типа устройства
  static String _getDeviceType() {
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else if (kIsWeb) {
      return 'web';
    } else if (Platform.isWindows) {
      return 'windows';
    } else if (Platform.isMacOS) {
      return 'macos';
    } else if (Platform.isLinux) {
      return 'linux';
    }
    return 'unknown';
  }

  /// Показать уведомление о новом кластере
  static Future<void> showClusterNotification({
    required int clusterId,
    required int complaintsCount,
    required double lat,
    required double lon,
  }) async {
    await _showLocalNotification(
      title: '🚨 Новый кластер проблем!',
      body: '$complaintsCount жалоб в одном месте (кластер #$clusterId)',
      payload: '/cluster/$clusterId',
    );
  }

  /// Получить текущий FCM токен
  static String? get fcmToken => _fcmToken;
}
