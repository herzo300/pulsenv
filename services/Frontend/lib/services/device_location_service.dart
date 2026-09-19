import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a device location lookup.
class DeviceLocationResult {
  const DeviceLocationResult({this.position, this.failure});

  final Position? position;
  final DeviceLocationFailure? failure;

  bool get isSuccess => position != null;
}

class DeviceLocationFailure {
  const DeviceLocationFailure({
    required this.code,
    required this.userMessage,
    this.openAppSettings = false,
    this.openLocationSettings = false,
  });

  final String code;
  final String userMessage;
  final bool openAppSettings;
  final bool openLocationSettings;
}

/// Resolves GPS coordinates with permission handling and Android fallbacks.
class DeviceLocationService {
  DeviceLocationService._();

  static final DeviceLocationService instance = DeviceLocationService._();

  Future<DeviceLocationResult> resolve({
    Duration timeout = const Duration(seconds: 15),
    bool forceCurrentGPS = false,
  }) async {
    if (kIsWeb) {
      return const DeviceLocationResult(
        failure: DeviceLocationFailure(
          code: 'unsupported',
          userMessage:
              'Геолокация в браузере недоступна. Укажите место на карте.',
        ),
      );
    }

    // 1. Проверяем разрешения в первую очередь
    final permissionFailure = await _ensurePermission();
    if (permissionFailure != null) {
      return DeviceLocationResult(failure: permissionFailure);
    }

    // 1b. GPS-модуль телефона выключен — сразу ведём в настройки,
    // иначе getCurrentPosition молча висит до таймаута и кажется, что
    // «GPS не включается»
    final svcEnabled = await Geolocator.isLocationServiceEnabled();
    if (!svcEnabled) {
      return const DeviceLocationResult(
        failure: DeviceLocationFailure(
          code: 'service_disabled',
          userMessage:
              'GPS выключен. Сейчас откроем настройки — включите «Местоположение».',
          openLocationSettings: true,
        ),
      );
    }

    // 2. Быстрый опрос кэша (если координаты свежие - до 10 минут)
    if (!forceCurrentGPS) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && _isValidPosition(lastKnown)) {
          final age = DateTime.now().difference(lastKnown.timestamp);
          if (age < const Duration(minutes: 10)) {
            debugPrint('DeviceLocationService: Found fresh last known position (< 10 min)');
            return DeviceLocationResult(position: lastKnown);
          }
        }
      } catch (e) {
        debugPrint('DeviceLocationService: Error getting last known position at start: $e');
      }
    }

    // 3. Попытка точного спутникового GPS (Fused Location Provider) с таймаутом (12 сек)
    try {
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 12),
            )
          : LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 12),
            );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 12));
      if (_isValidPosition(position)) {
        debugPrint('DeviceLocationService: Obtained high accuracy position');
        return DeviceLocationResult(position: position);
      }
    } catch (e) {
      debugPrint('DeviceLocationService: High accuracy attempt failed: $e');
    }

    // 4. Аварийная попытка через прямой LocationManager (для устройств без Google Services или при сбое FusedProvider)
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        debugPrint('DeviceLocationService: Attempting forceLocationManager...');
        final settings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
          forceLocationManager: true,
        );
        final position = await Geolocator.getCurrentPosition(
          locationSettings: settings,
        ).timeout(const Duration(seconds: 10));
        if (_isValidPosition(position)) {
          debugPrint('DeviceLocationService: Obtained position via LocationManager');
          return DeviceLocationResult(position: position);
        }
      } catch (e) {
        debugPrint('DeviceLocationService: LocationManager attempt failed: $e');
      }
    }

    // 5. Быстрое A-GPS / Сетевое позиционирование (координаты по сотам и Wi-Fi) с таймаутом (7 сек)
    try {
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 7),
            )
          : LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 7),
            );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 7));
      if (_isValidPosition(position)) {
        debugPrint('DeviceLocationService: Obtained medium accuracy position');
        return DeviceLocationResult(position: position);
      }
    } catch (e) {
      debugPrint('DeviceLocationService: Medium accuracy attempt failed: $e');
    }

    // 6. Быстрый опрос кэша (до 12 часов назад)
    if (!forceCurrentGPS) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && _isValidPosition(lastKnown)) {
          final age = DateTime.now().difference(lastKnown.timestamp);
          if (age < const Duration(hours: 12)) {
            debugPrint('DeviceLocationService: Using fresh last known position');
            return DeviceLocationResult(position: lastKnown);
          }
        }
      } catch (e) {
        debugPrint('DeviceLocationService: Error getting last known position: $e');
      }

      // 7. Аварийный откат к любым старым координатам
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && _isValidPosition(lastKnown)) {
          debugPrint('DeviceLocationService: Using stale last known position fallback');
          return DeviceLocationResult(position: lastKnown);
        }
      } catch (_) {}
    }

    // 8. Если ничего не помогло, проверяем включена ли служба геолокации на устройстве вообще
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const DeviceLocationResult(
        failure: DeviceLocationFailure(
          code: 'service_disabled',
          userMessage:
              'Геолокация выключена. Включите «Местоположение» в настройках телефона.',
          openLocationSettings: true,
        ),
      );
    }

    return const DeviceLocationResult(
      failure: DeviceLocationFailure(
        code: 'unavailable',
        userMessage:
            'Не удалось определить GPS координаты. Попробуйте выйти на открытое пространство или укажите место на карте.',
        openLocationSettings: true,
      ),
    );
  }

  Future<DeviceLocationFailure?> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Android показывает системный диалог только один раз; при повторном
      // отказе requestPermission сразу вернёт denied — тогда ведём в настройки
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      // Второй шанс: иногда checkPermission отдаёт denied, хотя диалог ещё
      // ни разу не показывался в этом lifecycle — пробуем ещё раз явно
      try {
        permission = await Geolocator.requestPermission();
      } catch (_) {}
      if (permission == LocationPermission.denied) {
        return const DeviceLocationFailure(
          code: 'permission_denied',
          userMessage:
              'Нужен доступ к геолокации. Нажмите GPS ещё раз и разрешите доступ, '
              'либо включите его в настройках приложения.',
          openAppSettings: true,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const DeviceLocationFailure(
        code: 'permission_denied_forever',
        userMessage:
            'Доступ к GPS запрещён. Сейчас откроем настройки — разрешите '
            '«Местоположение» для Пульс города.',
        openAppSettings: true,
      );
    }

    return null;
  }

  bool _isValidPosition(Position position) {
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return false;
    }
    if (position.latitude == 0 && position.longitude == 0) {
      return false;
    }
    return true;
  }

  Future<void> openFailureSettings(DeviceLocationFailure failure) async {
    if (failure.openLocationSettings) {
      await Geolocator.openLocationSettings();
      return;
    }
    if (failure.openAppSettings) {
      await Geolocator.openAppSettings();
    }
  }
}
