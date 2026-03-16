import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'map/map_config.dart';
import 'screens/security_lock_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_security_service.dart';
import 'services/app_metrics_service.dart';
import 'services/supabase_background_notifications_service.dart';
import 'services/supabase_runtime_config_service.dart';
import 'services/draft_box_service.dart';
import 'utils/offline_tiles_service.dart';
import 'theme/pulse_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode) {
    debugPrint = (String? _, {int? wrapWidth}) {};
  }

  final securityState = await AppSecurityService.instance.evaluate();
  if (securityState.shouldBlockInRelease) {
    runApp(SecurityBootstrapApp(referenceCode: securityState.referenceCode));
    return;
  }

  await SupabaseRuntimeConfigService.instance.bootstrap();
  AppMetricsService.instance.start();
  await OfflineTilesService.instance.initOfflineTiles();
  await _initializeRealtimeStack();

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
    debug: !kReleaseMode,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: PulseColors.background,
    ),
  );

  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      options.tracesSampleRate = kReleaseMode ? 0.05 : 1.0;
      options.attachStacktrace = true;
      options.sendDefaultPii = false;
      options.attachScreenshot = false;
      options.enableLogs = !kReleaseMode;
    },
    appRunner: () {
      runApp(const SoobshioApp());
      unawaited(SupabaseBackgroundNotificationsService.instance.initialize());
      unawaited(SupabaseBackgroundNotificationsService.instance.primeLastSeenReportId());
      unawaited(DraftBoxService.instance.syncOnline());
    },
  );
}

class SecurityBootstrapApp extends StatelessWidget {
  const SecurityBootstrapApp({
    super.key,
    required this.referenceCode,
  });

  final String referenceCode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SecurityLockScreen(referenceCode: referenceCode),
    );
  }
}

Future<void> _initializeRealtimeStack() async {
  if (!MapConfig.hasSupabaseConfig) {
    debugPrint('Supabase init skipped: runtime config is missing.');
    return;
  }
  try {
    await Supabase.initialize(
      url: MapConfig.supabaseUrl,
      anonKey: MapConfig.supabaseAnonKey,
    );
  } catch (error) {
    debugPrint('Supabase init failed: $error');
  }
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
