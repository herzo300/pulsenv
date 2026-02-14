// lib/lib/services/secure_auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';

class SecureAuthService {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Сохранить токен авторизации
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  /// Получить токен авторизации
  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  /// Удалить токен
  static Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }

  /// Проверить доступность биометрии
  static Future<bool> canCheckBiometrics() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    return canCheck ?? false;
  }

  /// Аутентификация через биометрию
  static Future<bool> authenticate({
    String localizedReason = 'Для входа в приложение',
    bool stickyAuth = true,
    bool biometricOnly = true,
  }) async {
    try {
      final canAuthenticate = await canCheckBiometrics();
      if (!canAuthenticate) {
        return false;
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
        ),
      );

      return isAuthenticated;
    } catch (e) {
      print('Biometric authentication error: $e');
      return false;
    }
  }

  /// Проверить, включена ли биометрия
  static Future<bool> isBiometricsEnabled() async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        return false;
      }

      final isAvailable = await _localAuth.isDeviceSupported();
      return isAvailable;
    } catch (e) {
      print('Biometrics check error: $e');
      return false;
    }
  }

  /// Сохранить PIN код
  static Future<void> savePin(String pin) async {
    await _storage.write(key: 'pin_code', value: pin);
  }

  /// Получить PIN код
  static Future<String?> getPin() async {
    return await _storage.read(key: 'pin_code');
  }

  /// Удалить PIN код
  static Future<void> deletePin() async {
    await _storage.delete(key: 'pin_code');
  }

  /// Сохранить настройку биометрии
  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: 'biometrics_enabled', value: enabled.toString());
  }

  /// Получить настройку биометрии
  static Future<bool> isBiometricsSettingEnabled() async {
    final value = await _storage.read(key: 'biometrics_enabled');
    return value == 'true';
  }

  /// Очистить все данные аутентификации
  static Future<void> clearAll() async {
    await deleteToken();
    await deletePin();
    await _storage.delete(key: 'biometrics_enabled');
  }
}
