import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppSecurityState {
  const AppSecurityState({
    required this.platform,
    required this.buildDebug,
    required this.debuggerAttached,
    required this.appDebuggable,
    required this.adbEnabled,
    required this.emulator,
    required this.rooted,
    required this.suspiciousPackages,
    required this.hooked,
    required this.secureFlagApplied,
  });

  final String platform;
  final bool buildDebug;
  final bool debuggerAttached;
  final bool appDebuggable;
  final bool adbEnabled;
  final bool emulator;
  final bool rooted;
  final bool suspiciousPackages;
  final bool hooked;
  final bool secureFlagApplied;

  static const bool _enforceReleaseBlock = bool.fromEnvironment(
    'ENFORCE_RUNTIME_SECURITY_BLOCK',
    defaultValue: false,
  );

  bool get shouldBlockInRelease =>
      _enforceReleaseBlock &&
      kReleaseMode &&
      (debuggerAttached ||
          appDebuggable ||
          adbEnabled ||
          emulator ||
          rooted ||
          suspiciousPackages ||
          hooked);

  String get referenceCode {
    final flags = <String>[
      if (debuggerAttached) 'dbg',
      if (appDebuggable) 'debuggable',
      if (adbEnabled) 'adb',
      if (emulator) 'emu',
      if (rooted) 'root',
      if (suspiciousPackages) 'pkg',
      if (hooked) 'hook',
    ];
    return flags.isEmpty ? 'ok' : flags.join('-');
  }

  factory AppSecurityState.fromMap(Map<Object?, Object?> map) {
    bool readBool(String key) => map[key] == true;

    return AppSecurityState(
      platform: map['platform']?.toString() ?? 'unknown',
      buildDebug: readBool('buildDebug'),
      debuggerAttached: readBool('debuggerAttached'),
      appDebuggable: readBool('appDebuggable'),
      adbEnabled: readBool('adbEnabled'),
      emulator: readBool('emulator'),
      rooted: readBool('rooted'),
      suspiciousPackages: readBool('suspiciousPackages'),
      hooked: readBool('hooked'),
      secureFlagApplied: readBool('secureFlagApplied'),
    );
  }

  static const AppSecurityState safe = AppSecurityState(
    platform: 'unknown',
    buildDebug: false,
    debuggerAttached: false,
    appDebuggable: false,
    adbEnabled: false,
    emulator: false,
    rooted: false,
    suspiciousPackages: false,
    hooked: false,
    secureFlagApplied: false,
  );
}

class AppSecurityService {
  AppSecurityService._();

  static final AppSecurityService instance = AppSecurityService._();
  static const MethodChannel _channel =
      MethodChannel('com.soobshio.security/runtime');

  Future<AppSecurityState> evaluate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return AppSecurityState.safe;
    }

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'getSecurityState',
      );
      if (result == null) {
        return AppSecurityState.safe;
      }
      return AppSecurityState.fromMap(result);
    } catch (_) {
      return AppSecurityState.safe;
    }
  }
}
