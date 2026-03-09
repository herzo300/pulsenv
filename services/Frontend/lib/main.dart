import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация уведомлений
  AwesomeNotifications().initialize(
    null, // Использование стандартной иконки (placeholder)
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
      )
    ],
    debug: true,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF0F0F23),
    ),
  );
  runApp(const SoobshioApp());
}

class SoobshioApp extends StatelessWidget {
  const SoobshioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Пульс города',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A5F)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
