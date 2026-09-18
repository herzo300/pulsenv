import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/app_branding.dart';
import 'core/app_router.dart';
import 'screens/blender_splash_screen.dart';
import 'screens/security_lock_screen.dart';
import 'services/app_state_service.dart';
import 'services/app_metrics_service.dart';
import 'services/app_security_service.dart';
import 'services/background_notifications_service.dart';
import 'services/draft_box_service.dart';
import 'services/notification_navigation_service.dart';
import 'services/notification_service.dart';
import 'services/runtime_config_service.dart';
import 'theme/pulse_colors.dart';
import 'theme/theme_provider.dart';
import 'utils/offline_tiles_service.dart';
import 'widgets/app_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
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
        runApp(const PulseCityApp());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_warmUpRuntimeServices());
        });
      },
    );
  } catch (e) {
    debugPrint('Sentry initialization failed: $e');
    runApp(const PulseCityApp());
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
  bool _routerReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initThemeAndRouter();
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

  Future<void> _initThemeAndRouter() async {
    await ThemeProvider.instance.initialize();
    AppRouter.initialize();
    if (mounted) setState(() => _routerReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_routerReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: PulseColors.background,
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF020817),
          body: BlenderSplashScreen(
            onComplete: () {
              if (mounted) setState(() {});
            },
          ),
        ),
      );
    }

    final baseTextTheme =
        GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme);
    final displayFont = GoogleFonts.exo2();
    final themedBase = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontFamily: displayFont.fontFamily,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: displayFont.fontFamily,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: displayFont.fontFamily,
        fontWeight: FontWeight.w600,
      ),
    );
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

    return AnimatedBuilder(
      animation: ThemeProvider.instance,
      builder: (ctx, _) => MaterialApp.router(
        title: AppBranding.appName,
        debugShowCheckedModeBanner: false,
        routerConfig: AppRouter.router,
        themeMode: ThemeProvider.instance.themeMode,
        theme: _buildLightTheme(lightColorScheme, themedBase),
        darkTheme: _buildDarkTheme(darkColorScheme, themedBase),
        scrollBehavior: const _BouncingScrollBehavior(),
      ),
    );
  }

  ThemeData _buildDarkTheme(ColorScheme colorScheme, TextTheme baseTextTheme) {
    const darkPrimary = Color(0xFF00E5FF);
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.manrope().fontFamily,
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
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.manrope().fontFamily,
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
        borderRadius: BorderRadius.circular(AppRadii.mdR),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.mdR),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.mdR),
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
          borderRadius: BorderRadius.circular(AppRadii.mdR),
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
          borderRadius: BorderRadius.circular(AppRadii.mdR),
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
