import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
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
import '../screens/meme_screen.dart';
import '../services/notification_navigation_service.dart';
import 'page_transitions.dart';

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
  static const String meshNetwork = '/mesh-network';
  static const String about = '/about';
  static const String securityLock = '/security-lock';
  static const String gamification = '/gamification';
  static const String memes = '/memes';

  // ── Query param keys ──────────────────────────────────────────────
  static const String paramDraftId = 'draft';
  static const String paramPayload = 'payload';

  static late final GoRouter router;

  static void initialize({Map<String, String?>? initialPayload}) {
    router = GoRouter(
      navigatorKey: NotificationNavigationService.navigatorKey,
      initialLocation: splash,
      redirect: (context, state) {
        // Future: add auth guards here
        return null;
      },
      routes: [
        GoRoute(
          path: splash,
          name: 'splash',
          pageBuilder: (context, state) => AppPageTransitions.fade(
            key: state.pageKey,
            child: const SplashScreen(),
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
            return AppPageTransitions.slideBottom(
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
            return AppPageTransitions.slideUp(
              key: state.pageKey,
              child: const ComplaintFormScreen(),
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
            child: const AdminDashboardScreen(initialTwoFactorCode: ''),
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
          pageBuilder: (context, state) => AppPageTransitions.slideRight(
            key: state.pageKey,
            child: const AboutScreen(),
          ),
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
          path: memes,
          name: 'memes',
          pageBuilder: (context, state) => AppPageTransitions.slideUp(
            key: state.pageKey,
            child: const MemeScreen(),
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
      final encoded =
          payload.entries.map((e) => '${e.key}=${e.value}').join('&');
      context.goNamed('map',
          queryParameters: <String, String>{paramPayload: encoded});
    } else {
      context.goNamed('map');
    }
  }

  static void goToInfographic({BuildContext? context}) {
    context?.goNamed('infographic');
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
    context?.goNamed('profile');
  }

  static void goToSettings({BuildContext? context}) {
    context?.goNamed('settings');
  }

  static void goToAdminDashboard({BuildContext? context}) {
    context?.goNamed('admin-dashboard');
  }

  static void goToMeshNetwork({BuildContext? context}) {
    context?.goNamed('mesh-network');
  }

  static void goToAbout({BuildContext? context}) {
    context?.goNamed('about');
  }

  static void goToSecurityLock(
      {BuildContext? context, String referenceCode = ''}) {
    context?.goNamed('security-lock', queryParameters: {'ref': referenceCode});
  }

  static void goToGamification({BuildContext? context}) {
    context?.goNamed('gamification');
  }

  static void goToMemes({BuildContext? context}) {
    context?.goNamed('memes');
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
}
