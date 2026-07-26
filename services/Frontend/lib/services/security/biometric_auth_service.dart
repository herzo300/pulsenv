// lib/services/security/biometric_auth_service.dart
//
// Биометрическая аутентификация (FaceID / TouchID / отпечаток).
// Обёртка над пакетом local_auth с graceful-fallback: если на устройстве
// нет биометрии или она отключена, метод возвращает false, и вызывающий
// код может показать fallback (PIN-экран / пароль).
//
// Используется:
//   • Вход в личный кабинет
//   • Подтверждение отправки официальной жалобы
//   • Подтверждение покупки VIP-тарифа
//   • Разблокировка приложения (security_lock_screen)
//
// Item 7 (CityPulse_Improvements.md): Безопасность и Стабильность.
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Причина биометрической проверки — влияет на текст, показываемый пользователю.
enum BiometricReason {
  appUnlock('Разблокировать приложение'),
  signIn('Вход в личный кабинет'),
  sendComplaint('Подтвердите отправку жалобы'),
  purchase('Подтвердите покупку VIP-тарифа');

  final String label;
  const BiometricReason(this.label);
}

/// Результат проверки биометрии.
class BiometricResult {
  const BiometricResult({
    required this.success,
    required this.reason,
    this.error,
  });

  final bool success;

  /// Почему биометрия была недоступна / отменена.
  /// Возможные значения: 'unavailable', 'notEnrolled', 'canceled',
  /// 'platformNotSupported', 'unknown'.
  final String? error;

  /// Человекочитаемая причина (для снекбара / fallback UI).
  final BiometricReason reason;

  bool get biometricsAvailable => error != 'unavailable' && error != 'notEnrolled';
}

class BiometricAuthService {
  BiometricAuthService._(this._auth);

  static BiometricAuthService? _instance;

  final LocalAuthentication _auth;

  /// Lazy-init синглтон.
  static BiometricAuthService instance() {
    return _instance ??= BiometricAuthService._(LocalAuthentication());
  }

  /// Только для DI / тестов.
  @visibleForTesting
  static void setTestInstance(BiometricAuthService instance) {
    _instance = instance;
  }

  /// Доступна ли биометрия на устройстве.
  Future<bool> get isDeviceSupported async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('[BiometricAuth] isDeviceSupported failed: $e');
      return false;
    }
  }

  /// Зарегистрированы ли отпечатки/лица у пользователя.
  Future<bool> get canCheckBiometrics async {
    try {
      final can = await _auth.canCheckBiometrics;
      final supported = await isDeviceSupported;
      return can && supported;
    } catch (e) {
      debugPrint('[BiometricAuth] canCheckBiometrics failed: $e');
      return false;
    }
  }

  /// Перечень доступных биометрических типов (face, fingerprint, iris).
  Future<Set<BiometricType>> get availableBiometrics async {
    try {
      final list = await _auth.getAvailableBiometrics();
      return list.toSet();
    } catch (e) {
      debugPrint('[BiometricAuth] availableBiometrics failed: $e');
      return {};
    }
  }

  /// Запросить биометрическую аутентификацию.
  ///
  /// [reason] — для чего нужна проверка (влияет на UI-текст).
  /// Возвращает [BiometricResult]. Никогда не бросает исключения —
  /// все ошибки нормализованы в `result.error`.
  Future<BiometricResult> authenticate({
    BiometricReason reason = BiometricReason.appUnlock,
  }) async {
    try {
      final canCheck = await canCheckBiometrics;
      if (!canCheck) {
        return BiometricResult(
          success: false,
          reason: reason,
          error: (await isDeviceSupported) ? 'notEnrolled' : 'unavailable',
        );
      }

      final isSensitive = reason == BiometricReason.purchase ||
          reason == BiometricReason.sendComplaint;
      final didAuth = await _auth.authenticate(
        localizedReason: reason.label,
        options: AuthenticationOptions(
          biometricOnly: false, // разрешить fallback на device credentials (PIN)
          stickyAuth: true, // сессия остаётся активной при переключении приложений
          sensitiveTransaction: isSensitive,
        ),
      );

      return BiometricResult(
        success: didAuth,
        reason: reason,
        error: didAuth ? null : 'canceled',
      );
    } on UnsupportedError {
      return BiometricResult(
        success: false,
        reason: reason,
        error: 'platformNotSupported',
      );
    } catch (e) {
      debugPrint('[BiometricAuth] authenticate failed: $e');
      return BiometricResult(
        success: false,
        reason: reason,
        error: 'unknown',
      );
    }
  }

  /// Отменить активную биометрическую сессию (если stickyAuth держит её).
  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // no-op: сессии может уже не быть
    }
  }
}
