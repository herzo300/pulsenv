import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/splash_router_screen.dart';
import '../screens/map_screen.dart';
import '../screens/infographic_screen.dart';
import '../screens/complaint_form_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/mesh_screen.dart';
import '../screens/about_screen.dart';
import '../screens/security_lock_screen.dart';
import '../screens/gamification_screen.dart';
import '../screens/ai_digest_screen.dart';
import '../screens/uk_companies_screen.dart';
import '../screens/meme_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/weather_screen.dart';
import '../screens/cameras_screen.dart';
import '../services/admin_dashboard_service.dart';
import '../services/notification_navigation_service.dart';
import '../services/notification_tap_payload_store.dart';
import 'page_transitions.dart';

import '../services/app_state_service.dart';
import 'dart:async';

/// Centralized GoRouter configuration with named routes and page transitions.
final class AppRouter {
  AppRouter._();

  // ── Route name constants ──────────────────────────────────────────
  static const String splash = '/';
  static const String map = '/map';
  static const String infographic = '/infographic';
  static const String complaintForm = '/complaint-form';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String adminDashboard = '/admin-dashboard';
  static const String ukCompanies = '/uk-companies';
  static const String aiAssistant = '/ai-assistant';
  static const String meshNetwork = '/mesh-network';
  static const String about = '/about';
  static const String securityLock = '/security-lock';
  static const String gamification = '/gamification';
  static const String aiDigest = '/ai-digest';
  static const String memes = '/memes';
  static const String qrScanner = '/qr-scanner';
  static const String weather = '/weather';
  static const String cameras = '/cameras';

  // ── Query param keys ──────────────────────────────────────────────
  static const String paramDraftId = 'draft';
  static const String paramPayload = 'payload';
  static const String paramLat = 'lat';
  static const String paramLng = 'lng';

  static late final GoRouter router;

  static void initialize({Map<String, String?>? initialPayload}) {
    router = GoRouter(
      navigatorKey: NotificationNavigationService.navigatorKey,
      initialLocation: splash,
      observers: [
        _RouterObserver(),
      ],
      redirect: (context, state) {
        final path = state.matchedLocation;
        if (path.startsWith(adminDashboard)) {
          final hasSession = AdminDashboardService.instance.hasSession;
          final tfa = state.uri.queryParameters['tfa']?.trim() ?? '';
          if (!hasSession && tfa.isEmpty) {
            return settings;
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: splash,
          name: 'splash',
          pageBuilder: (context, state) => AppPageTransitions.fade(
            key: state.pageKey,
            child: const SplashRouterScreen(),
          ),
        ),
        GoRoute(
          path: map,
          name: 'map',
          pageBuilder: (context, state) {
            final payloadParam = state.uri.queryParameters[paramPayload];
            final payload = (payloadParam != null && payloadParam.isNotEmpty)
                ? _parsePayload(payloadParam)
                : null;
            return AppPageTransitions.portalExpansion(
              key: state.pageKey,
              child: MapScreen(initialNotificationPayload: payload),
            );
          },
        ),
        GoRoute(
          path: infographic,
          name: 'infographic',
          pageBuilder: (context, state) => AppPageTransitions.slideRight(
            key: state.pageKey,
            child: const InfographicScreen(),
          ),
        ),
        GoRoute(
          path: complaintForm,
          name: 'complaint-form',
          pageBuilder: (context, state) {
            final latRaw = state.uri.queryParameters[paramLat];
            final lngRaw = state.uri.queryParameters[paramLng];
            final lat = latRaw != null ? double.tryParse(latRaw) : null;
            final lng = lngRaw != null ? double.tryParse(lngRaw) : null;
            return AppPageTransitions.slideUp(
              key: state.pageKey,
              child: ComplaintFormScreen(
                initialDraftId: state.uri.queryParameters[paramDraftId],
                initialCenter: (lat != null && lng != null)
                    ? LatLng(lat, lng)
                    : null,
              ),
            );
          },
        ),
        GoRoute(
          path: profile,
          name: 'profile',
          pageBuilder: (context, state) => AppPageTransitions.slideRight(
            key: state.pageKey,
            child: const ProfileScreen(),
          ),
        ),
        GoRoute(
          path: settings,
          name: 'settings',
          pageBuilder: (context, state) => AppPageTransitions.slideRight(
            key: state.pageKey,
            child: const SettingsScreen(),
          ),
        ),
        GoRoute(
          path: adminDashboard,
          name: 'admin-dashboard',
          pageBuilder: (context, state) => AppPageTransitions.slideUp(
            key: state.pageKey,
            child: AdminDashboardScreen(
              initialTwoFactorCode: state.uri.queryParameters['tfa'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: meshNetwork,
          name: 'mesh-network',
          pageBuilder: (context, state) => AppPageTransitions.slideRight(
            key: state.pageKey,
            child: const MeshScreen(),
          ),
        ),
        GoRoute(
          path: about,
          name: 'about',
          pageBuilder: (context, state) {
            final onboarding = state.uri.queryParameters['onboarding'] == 'true';
            final tabStr = state.uri.queryParameters['tab'];
            final tab = tabStr != null ? int.tryParse(tabStr) ?? 0 : 0;
            return AppPageTransitions.slideRight(
              key: state.pageKey,
              child: AboutScreen(isOnboarding: onboarding, initialTab: tab),
            );
          },
        ),
        GoRoute(
          path: securityLock,
          name: 'security-lock',
          pageBuilder: (context, state) {
            final refCode = state.uri.queryParameters['ref'] ?? '';
            return AppPageTransitions.fade(
              key: state.pageKey,
              child: SecurityLockScreen(referenceCode: refCode),
            );
          },
        ),
        GoRoute(
          path: gamification,
          name: 'gamification',
          pageBuilder: (context, state) => AppPageTransitions.slideUp(
            key: state.pageKey,
            child: const GamificationScreen(),
          ),
        ),
        GoRoute(
          path: ukCompanies,
          name: 'uk-companies',
          pageBuilder: (context, state) => AppPageTransitions.slideRight(
            key: state.pageKey,
            child: const UkCompaniesScreen(),
          ),
        ),
        GoRoute(
          path: aiDigest,
          name: 'ai-digest',
          pageBuilder: (context, state) => AppPageTransitions.slideUp(
            key: state.pageKey,
            child: const AiDigestScreen(),
          ),
        ),
        GoRoute(
          path: memes,
          name: 'memes',
          pageBuilder: (context, state) => AppPageTransitions.slideUp(
            key: state.pageKey,
            child: const MemeScreen(),
          ),
        ),
        GoRoute(
          path: qrScanner,
          name: 'qr-scanner',
          pageBuilder: (context, state) => AppPageTransitions.slideUp(
            key: state.pageKey,
            child: const QrScannerScreen(),
          ),
        ),
        GoRoute(
          path: weather,
          name: 'weather',
          pageBuilder: (context, state) => AppPageTransitions.fade(
            key: state.pageKey,
            child: const WeatherScreen(),
          ),
        ),
        GoRoute(
          path: cameras,
          name: 'cameras',
          pageBuilder: (context, state) => AppPageTransitions.slideRight(
            key: state.pageKey,
            child: const CamerasScreen(),
          ),
        ),
      ],
    );
  }

  static Map<String, String?> _parsePayload(String raw) {
    try {
      final pairs = raw.split('&');
      return {
        for (final p in pairs)
          if (p.contains('=')) p.split('=')[0]: p.split('=')[1],
      };
    } catch (_) {
      return {};
    }
  }

  // ── Typed navigation helpers ──────────────────────────────────────

  static void goToMap({BuildContext? context, Map<String, String?>? payload}) {
    if (context == null) return;
    if (payload != null) {
      NotificationTapPayloadStore.setPendingPayload(payload);
      final encoded =
          payload.entries.map((e) => '${e.key}=${e.value}').join('&');
      context.goNamed('map',
          queryParameters: <String, String>{paramPayload: encoded});
    } else {
      context.goNamed('map');
    }
  }

  static void goToInfographic({BuildContext? context}) {
    context?.pushNamed('infographic');
  }

  static Future<T?> pushComplaintForm<T>({
    required BuildContext context,
    String? draftId,
    LatLng? initialCenter,
  }) {
    final params = <String, String>{};
    if (draftId != null && draftId.isNotEmpty) {
      params[paramDraftId] = draftId;
    }
    if (initialCenter != null) {
      params[paramLat] = initialCenter.latitude.toString();
      params[paramLng] = initialCenter.longitude.toString();
    }
    if (params.isEmpty) {
      return context.pushNamed<T>('complaint-form');
    }
    return context.pushNamed<T>(
      'complaint-form',
      queryParameters: params,
    );
  }

  static void goToComplaintForm({BuildContext? context, String? draftId}) {
    if (context == null) return;
    if (draftId != null) {
      context.goNamed('complaint-form',
          queryParameters: <String, String>{paramDraftId: draftId});
    } else {
      context.goNamed('complaint-form');
    }
  }

  static void goToProfile({BuildContext? context}) {
    context?.pushNamed('profile');
  }

  static void goToSettings({BuildContext? context}) {
    context?.pushNamed('settings');
  }

  static void goToAdminDashboard({BuildContext? context}) {
    context?.pushNamed('admin-dashboard');
  }

  static void goToMeshNetwork({BuildContext? context}) {
    context?.pushNamed('mesh-network');
  }

  static void goToAbout({BuildContext? context}) {
    context?.pushNamed('about');
  }

  static void goToSecurityLock(
      {BuildContext? context, String referenceCode = ''}) {
    context?.pushNamed('security-lock', queryParameters: {'ref': referenceCode});
  }

  static void goToGamification({BuildContext? context}) {
    context?.pushNamed('gamification');
  }

  static void goToUkCompanies({BuildContext? context}) {
    context?.pushNamed('uk-companies');
  }

  static void goToAiDigest({BuildContext? context}) {
    context?.pushNamed('ai-digest');
  }

  static void goToMemes({BuildContext? context}) {
    context?.pushNamed('memes');
  }

  static void goToAddresslessEvents({BuildContext? context}) {
    context?.pushNamed('addressless-events');
  }

  static Future<bool> goBack({BuildContext? context}) async {
    if (context != null && context.canPop()) {
      context.pop();
      return true;
    }
    return false;
  }

  static void clearStackAndGoNamed(String name, {BuildContext? context}) {
    context?.goNamed(name);
  }

  static Future<void> navigateAfterSplash(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('first_launch_accepted') ?? false;
    if (!context.mounted) return;
    if (!accepted) {
      context.goNamed('about', queryParameters: {'onboarding': 'true'});
    } else {
      final lastRoute = AppStateService.instance.state.lastRoute;
      context.go(lastRoute);
    }
  }
}

class _RouterObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null) {
      final name = route.settings.name!;
      if (name != 'splash' && !name.contains('security') && !name.contains('lock')) {
        // Build the route path
        String path = '/$name';
        if (name == 'map') path = '/map';
        unawaited(AppStateService.instance.saveLastRoute(path));
      }
    }
  }
}
