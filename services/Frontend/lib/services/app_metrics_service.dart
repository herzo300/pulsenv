import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'backend_api_service.dart';

class AppMetricsService with WidgetsBindingObserver {
  AppMetricsService._();

  static final AppMetricsService instance = AppMetricsService._();
  static const String _appVersion = '1.0.0+1';
  final BackendApiService _backendApi = BackendApiService.instance;

  Timer? _heartbeatTimer;
  bool _started = false;
  bool _heartbeatInFlight = false;

  String get _platformName {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(sendHeartbeat(screen: 'app_boot'));
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(sendHeartbeat(screen: 'app_runtime')),
    );
  }

  Future<void> sendHeartbeat({String screen = 'app_runtime'}) async {
    if (_heartbeatInFlight) {
      return;
    }
    _heartbeatInFlight = true;
    try {
      await _backendApi.postJson(
        '/api/runtime/heartbeat',
        {
          'platform': _platformName,
          'app_version': _appVersion,
          'screen': screen,
        },
        timeout: const Duration(seconds: 5),
      );
    } catch (_) {
      // Metrics must not block the app runtime.
    } finally {
      _heartbeatInFlight = false;
    }
  }

  Future<Map<String, dynamic>> fetchMetrics() async {
    final response = await _backendApi.get(
      '/api/admin/metrics',
      timeout: const Duration(seconds: 8),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Admin metrics request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected admin metrics payload');
    }
    return decoded;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(sendHeartbeat(screen: 'app_resumed'));
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}
