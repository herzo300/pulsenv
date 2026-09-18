import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/cached_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/app_branding.dart';
import 'core/app_router.dart';
import 'core/di/service_locator.dart';
import 'core/living/aura_theme_service.dart';
import 'services/app_links_service.dart';
import 'services/security/secure_storage_migration.dart';
import 'screens/security_lock_screen.dart';
import 'screens/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_state_service.dart';
import 'services/app_metrics_service.dart';
import 'services/app_security_service.dart';
import 'services/background_notifications_service.dart';
import 'services/draft_box_service.dart';
import 'services/notification_navigation_service.dart';
import 'services/notification_service.dart';
import 'services/performance_mode_service.dart';
import 'services/runtime_config_service.dart';
import 'theme/pulse_colors.dart';
import 'theme/pulse_typography.dart';
import 'theme/theme_provider.dart';
import 'utils/offline_tiles_service.dart';

// NOTE: глобальный HttpOverrides с badCertificateCallback=true удалён (P0-security).
// Приложение больше не принимает самоподписанные/поддельные TLS-сертификаты.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  // Настройка скоростного кэша тайлов (300 MB RAM + дисковый SSD кэш)
  CachedTileProvider.configureImageCache();
  try {
    await FMTCObjectBoxBackend().initialise();
  } catch (_) {}

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Global ErrorWidget caught error: ${details.exception}\n${details.stack}');
    final errorText = '${details.exception}\n\n${details.stack}';
    return Material(
      color: const Color(0xFF020817),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'CITY PULSE • Сбой интерфейса',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (ctx) => ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('first_launch_accepted', true);
                          await prefs.setBool('seen_onboarding', true);
                        } catch (_) {}
                        try {
                          AppRouter.router.go('/map');
                        } catch (_) {
                          try {
                            NotificationNavigationService.navigatorKey.currentState?.pushReplacement(
                              MaterialPageRoute(builder: (_) => const MapScreen()),
                            );
                          } catch (_) {}
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF020817),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: const Text('Открыть карту', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1829),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      errorText,
                      style: const TextStyle(
                        color: Color(0xFFFF8A80),
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  if (kReleaseMode) {
    debugPrint = (String? _, {int? wrapWidth}) {};
  }

  final securityState = await AppSecurityService.instance.evaluate();
  if (securityState.shouldBlockInRelease) {
    runApp(SecurityBootstrapApp(referenceCode: securityState.referenceCode));
    return;
  }

  try {
    await RuntimeConfigService.instance.bootstrap();
  } catch (e) {
    debugPrint('Error bootstrapping RuntimeConfigService: $e');
  }

  // Item 1, 2, 7: инициализация DI-контейнера (Isar + SecureStorage +
  // Biometric + обёртки существующих синглтонов) и одноразовая миграция
  // PII из SharedPreferences в flutter_secure_storage.
  try {
    await setupServiceLocator();
    await SecureStorageMigration.runIfNeeded();
  } catch (e) {
    debugPrint('Error initializing service locator / secure migration: $e');
  }

  try {
    await AppStateService.instance.initialize();
  } catch (e) {
    debugPrint('Error initializing AppStateService: $e');
  }

  try {
    await NotificationService().ensureInitialized();
  } catch (e) {
    debugPrint('Error initializing NotificationService: $e');
  }

  try {
    await NotificationNavigationService.initialize();
  } catch (e) {
    debugPrint('Error initializing NotificationNavigationService: $e');
  }

  try {
    await ThemeProvider.instance.initialize();
  } catch (e) {
    debugPrint('Error initializing ThemeProvider: $e');
  }

  try {
    await AuraThemeService.instance.initialize();
  } catch (e) {
    debugPrint('Error initializing AuraThemeService: $e');
  }

  try {
    AppRouter.initialize();
  } catch (e) {
    debugPrint('Error initializing AppRouter: $e');
  }

  try {
    await AppLinksService.instance.initialize();
  } catch (e) {
    debugPrint('Error initializing AppLinksService: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: PulseColors.background,
    ),
  );

  try {
    await SentryFlutter.init(
      (options) {
        options.dsn =
            const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
        options.tracesSampleRate = kReleaseMode ? 0.05 : 1.0;
        options.attachStacktrace = true;
        options.sendDefaultPii = false;
        options.attachScreenshot = false;
        options.enableLogs = !kReleaseMode;
      },
      appRunner: () {
        runApp(const ProviderScope(child: PulseCityApp()));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_warmUpRuntimeServices());
        });
      },
    );
  } catch (e) {
    debugPrint('Sentry initialization failed: $e');
    runApp(const ProviderScope(child: PulseCityApp()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warmUpRuntimeServices());
    });
  }
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

Future<void> _warmUpRuntimeServices() async {
  AppMetricsService.instance.start();
  unawaited(PerformanceModeService.instance.initialize());
  unawaited(OfflineTilesService.instance.initOfflineTiles());
  unawaited(BackgroundNotificationsService.instance.initialize());
  unawaited(BackgroundNotificationsService.instance.primeLastSeenReportId());
  unawaited(DraftBoxService.instance.syncOnline());
}

class PulseCityApp extends StatefulWidget {
  const PulseCityApp({super.key});

  @override
  State<PulseCityApp> createState() => _PulseCityAppState();
}

class _PulseCityAppState extends State<PulseCityApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Сохраняем состояние при свёртывании или выходе
        unawaited(AppStateService.instance.onAppPause());
      case AppLifecycleState.resumed:
        AppStateService.instance.onAppResume();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    TextTheme baseTextTheme;
    try {
      baseTextTheme = GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme);
    } catch (_) {
      baseTextTheme = ThemeData.dark().textTheme;
    }

    final themedBase = PulseTypography.textTheme;
    final darkColorScheme = ColorScheme.fromSeed(
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

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: PulseColors.primaryDeep,
      brightness: Brightness.light,
    ).copyWith(
      primary: PulseColors.primaryDeep,
      secondary: PulseColors.primary,
      tertiary: PulseColors.success,
      surface: PulseColors.lightSurfaceSoft,
      error: PulseColors.negative,
      onPrimary: PulseColors.lightBackground,
      onSecondary: PulseColors.lightBackground,
      onTertiary: PulseColors.lightBackground,
      onSurface: PulseColors.lightTextPrimary,
    );

    final lightTheme = _buildLightTheme(lightColorScheme, themedBase);
    final darkTheme = _buildDarkTheme(darkColorScheme, themedBase);

    return AnimatedBuilder(
      animation: ThemeProvider.instance,
      builder: (ctx, _) {
        final currentTheme = ThemeProvider.instance.isDarkMode ? darkTheme : lightTheme;
        return AnimatedTheme(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          data: currentTheme,
          child: MaterialApp.router(
            title: AppBranding.appName,
            debugShowCheckedModeBanner: false,
            routerConfig: AppRouter.router,
            themeMode: ThemeProvider.instance.themeMode,
            theme: lightTheme,
            darkTheme: darkTheme,
            scrollBehavior: const _BouncingScrollBehavior(),
            // A11y: уважаем системный масштаб шрифта, но ограничиваем его,
            // чтобы экстремальные значения не ломали вёрстку экранов.
            builder: (context, child) {
              final scaler = MediaQuery.textScalerOf(context);
              final clamped = scaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.3,
              );
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: clamped),
                child: child ?? const SizedBox.shrink(),
              );
            },
          ),
        );
      },
    );
  }

  ThemeData _buildDarkTheme(ColorScheme colorScheme, TextTheme baseTextTheme) {
    const darkPrimary = Color(0xFF00E5FF);
    String? font;
    try {
      font = GoogleFonts.manrope().fontFamily;
    } catch (_) {}
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: font,
      scaffoldBackgroundColor: PulseColors.darkBackground,
      canvasColor: PulseColors.darkBackground,
      splashColor: darkPrimary.withOpacity(0.12),
      highlightColor: darkPrimary.withOpacity(0.08),
      appBarTheme: const AppBarTheme(
        backgroundColor: PulseColors.darkBackground,
        foregroundColor: PulseColors.darkTextPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardColor: PulseColors.darkSurface,
      dividerColor: darkPrimary.withOpacity(0.12),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PulseColors.darkBackgroundRaised,
        contentTextStyle: const TextStyle(color: PulseColors.darkTextPrimary),
        actionTextColor: darkPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkPrimary.withOpacity(0.2)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: PulseColors.darkBackground,
      ),
      inputDecorationTheme: _inputTheme(PulseColors.darkSurfaceGlass,
          PulseColors.darkBorderStrong, darkPrimary),
      filledButtonTheme:
          _filledButtonTheme(darkPrimary, PulseColors.darkBackground),
      outlinedButtonTheme: _outlinedButtonTheme(
          PulseColors.darkTextPrimary, PulseColors.darkBorderStrong),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: _textTheme(baseTextTheme),
    );
  }

  ThemeData _buildLightTheme(ColorScheme colorScheme, TextTheme baseTextTheme) {
    String? font;
    try {
      font = GoogleFonts.manrope().fontFamily;
    } catch (_) {}
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: font,
      scaffoldBackgroundColor: PulseColors.lightBackground,
      canvasColor: PulseColors.lightBackground,
      splashColor: PulseColors.primaryDeep.withOpacity(0.08),
      highlightColor: PulseColors.primaryDeep.withOpacity(0.04),
      appBarTheme: const AppBarTheme(
        backgroundColor: PulseColors.lightSurface,
        foregroundColor: PulseColors.lightTextPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardColor: PulseColors.lightSurface,
      dividerColor: PulseColors.lightBorderStrong,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PulseColors.lightSurfaceElevated,
        contentTextStyle: const TextStyle(color: PulseColors.lightTextPrimary),
        actionTextColor: PulseColors.primaryDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: PulseColors.lightBorderStrong),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PulseColors.primaryDeep,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: _inputTheme(PulseColors.lightSurfaceGlass,
          PulseColors.lightBorderStrong, PulseColors.primaryDeep),
      filledButtonTheme:
          _filledButtonTheme(PulseColors.primaryDeep, Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(
          PulseColors.lightTextPrimary, PulseColors.lightBorderStrong),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: _textTheme(baseTextTheme, light: true),
    );
  }

  InputDecorationTheme _inputTheme(Color fill, Color border, Color focus) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      labelStyle: GoogleFonts.manrope(
        color: PulseColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: GoogleFonts.manrope(
        color: PulseColors.textTertiary,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: focus, width: 1.2),
      ),
    );
  }

  FilledButtonThemeData _filledButtonTheme(Color bg, Color fg) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }

  OutlinedButtonThemeData _outlinedButtonTheme(Color fg, Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }

  TextTheme _textTheme(TextTheme base, {bool light = false}) {
    final primaryColor =
        light ? PulseColors.lightTextPrimary : PulseColors.textPrimary;
    final secondaryColor =
        light ? PulseColors.lightTextSecondary : PulseColors.textSecondary;
    return base
        .copyWith(
          displayLarge: GoogleFonts.exo2(
            color: primaryColor,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
          displayMedium: GoogleFonts.exo2(
            color: primaryColor,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
          ),
          headlineMedium: GoogleFonts.exo2(
            color: primaryColor,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: GoogleFonts.exo2(
            color: primaryColor,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
          ),
          bodyLarge: GoogleFonts.manrope(
            color: primaryColor,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.manrope(
            color: primaryColor,
            fontWeight: FontWeight.w500,
            height: 1.48,
          ),
          bodySmall: GoogleFonts.manrope(
            color: secondaryColor,
            fontWeight: FontWeight.w500,
            height: 1.42,
          ),
          labelLarge: GoogleFonts.ibmPlexSans(
            color: primaryColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        )
        .apply(
          bodyColor: primaryColor,
          displayColor: primaryColor,
        );
  }
}

class _BouncingScrollBehavior extends ScrollBehavior {
  const _BouncingScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
