// lib/services/app_links_service.dart
//
// Обработка deep links (citypulse://) через app_links.
//
// Не путать с существующим DeepLinkService (реферальные коды) — это
// отдельный сервис для OS-level App Links / Universal Links.
//
// Поддерживаемые схемы:
//   • citypulse://map — открыть карту
//   • citypulse://complaint-form?lat=X&lng=Y — форма жалобы с гео
//   • citypulse://profile — профиль
//   • citypulse://report/{id} — детали сигнала
//   • citypulse://weather — погода
//
// Премиум-функционал: бесшовный переход из QR-сканера, push, веба.
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../core/app_router.dart';

class AppLinksService {
  AppLinksService._();
  static final AppLinksService instance = AppLinksService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  static const String scheme = 'citypulse';

  /// Инициализация: получить начальную ссылку + слушать новые.
  /// Вызывать после AppRouter.initialize().
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
      _sub = _appLinks.uriLinkStream.listen(
        _handleUri,
        onError: (e) => debugPrint('[AppLinks] stream error: $e'),
      );
      debugPrint('[AppLinks] initialized');
    } catch (e) {
      debugPrint('[AppLinks] init failed: $e');
    }
  }

  void _handleUri(Uri uri) {
    debugPrint('[AppLinks] handling: $uri');
    final route = resolveRoute(uri);
    if (route != null) {
      AppRouter.router.go(route);
    }
  }

  /// Преобразовать URI в go_router-путь. null = не распознано.
  static String? resolveRoute(Uri uri) {
    if (uri.scheme == scheme) return _resolveInternal(uri);
    if (uri.scheme == 'https') {
      return _resolveInternal(uri.replace(scheme: scheme));
    }
    return null;
  }

  static String? _resolveInternal(Uri uri) {
    final path = uri.host.isEmpty ? uri.path : '/${uri.host}${uri.path}';
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) return AppRouter.map;

    switch (segments.first) {
      case 'map':
        return AppRouter.map;
      case 'complaint-form':
      case 'complaint':
        final params = uri.queryParameters;
        if (params.containsKey('lat') && params.containsKey('lng')) {
          return '${AppRouter.complaintForm}?lat=${params['lat']}&lng=${params['lng']}';
        }
        return AppRouter.complaintForm;
      case 'profile':
        return AppRouter.profile;
      case 'weather':
        return AppRouter.weather;
      case 'settings':
        return AppRouter.settings;
      case 'report':
        if (segments.length >= 2) {
          return '${AppRouter.map}?report_id=${segments[1]}';
        }
        return AppRouter.map;
      case 'qr-scanner':
        return AppRouter.qrScanner;
      default:
        return AppRouter.map;
    }
  }

  /// Сгенерировать deep-link для шеринга.
  static String toReportLink(int reportId) => '$scheme://report/$reportId';

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
