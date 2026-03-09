import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'services/app_metrics_service.dart';
import 'theme/pulse_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppMetricsService.instance.start();

  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'Уведомления о новых событиях в городе',
        defaultColor: PulseColors.primary,
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        onlyAlertOnce: true,
        playSound: true,
        criticalAlerts: true,
      ),
    ],
    debug: true,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: PulseColors.background,
    ),
  );

  runApp(const SoobshioApp());
}

class SoobshioApp extends StatelessWidget {
  const SoobshioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PulseColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: PulseColors.primary,
      secondary: PulseColors.primarySoft,
      tertiary: PulseColors.success,
      surface: PulseColors.backgroundRaised,
      error: PulseColors.negative,
      onPrimary: PulseColors.background,
      onSecondary: PulseColors.background,
      onTertiary: PulseColors.background,
      onSurface: PulseColors.textPrimary,
    );

    return MaterialApp(
      title: 'Пульс города',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: PulseColors.background,
        canvasColor: PulseColors.background,
        splashColor: PulseColors.primary.withOpacity(0.12),
        highlightColor: PulseColors.primary.withOpacity(0.08),
        appBarTheme: const AppBarTheme(
          backgroundColor: PulseColors.background,
          foregroundColor: PulseColors.textPrimary,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        cardColor: PulseColors.surface,
        dividerColor: PulseColors.primary.withOpacity(0.12),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: PulseColors.backgroundRaised,
          contentTextStyle: const TextStyle(color: PulseColors.textPrimary),
          actionTextColor: PulseColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: PulseColors.primary.withOpacity(0.2)),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: PulseColors.primary,
          foregroundColor: PulseColors.background,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: PulseColors.textPrimary,
              displayColor: PulseColors.textPrimary,
            ),
      ),
      home: const SplashScreen(),
    );
  }
}
