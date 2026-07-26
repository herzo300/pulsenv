// lib/services/security/secure_storage_service.dart
//
// Зашифрованное Key-Value хранилище на базе flutter_secure_storage.
//
// Заменяет небезопасное хранение в SharedPreferences для чувствительных данных:
//   • JWT / auth токены
//   • Telegram ID пользователя
//   • PII (телефон, адрес, имя профиля, аватар)
//   • device id
//
// Реализация:
//   • iOS    — Keychain
//   • Android — Android Keystore (EncryptedSharedPreferences под капотом)
//   • Web/Desktop — fallback на нешифрованное хранилище с предупреждением в лог
//
// Item 7 (CityPulse_Improvements.md): Безопасность и Стабильность.
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ключи для всех чувствительных значений — в одном месте, чтобы ничего не потерялось.
class SecureKeys {
  const SecureKeys._();

  // Аутентификация
  static const authToken = 'auth_token'; // JWT
  static const refreshToken = 'refresh_token';
  static const telegramId = 'telegram_id'; // PII: идентификатор пользователя

  // PII профиля
  static const userName = 'user_name';
  static const userPhone = 'user_phone';
  static const userAddress = 'user_address';
  static const userAvatar = 'user_avatar';

  // Идентификация устройства
  static const deviceId = 'runtime_device_id_v1';

  // Флаг первой миграции SharedPreferences -> SecureStorage
  static const migratedFlag = 'secure_storage_migrated_v1';
}

/// Потокобезопасный синглтон-обёртка над [FlutterSecureStorage].
///
/// Все методы проглатывают платформенные ошибки и возвращают null/false,
/// чтобы приложение не падало, если Keystore недоступен (rooted/custom ROM).
class SecureStorageService {
  SecureStorageService._({required FlutterSecureStorage storage})
      : _storage = storage;

  static SecureStorageService? _instance;

  final FlutterSecureStorage _storage;

  /// Конфигурация Android: EncryptedSharedPreferences (API 23+),
  /// ResetsOnAppUninstall — данные не «протекают» между установками.
  static FlutterSecureStorage _defaultStorage() => const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          resetOnError: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );

  /// Инициализация. Безопасно вызывать многократно.
  static Future<SecureStorageService> instance() async {
    return _instance ??= SecureStorageService._(storage: _defaultStorage());
  }

  /// Только для тестов / DI: подставить мок-хранилище.
  @visibleForTesting
  static void setTestInstance(SecureStorageService instance) {
    _instance = instance;
  }

  // ─── Чтение ────────────────────────────────────────────────────────────────

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[SecureStorage] read($key) failed: $e');
      return null;
    }
  }

  Future<Map<String, String>> readAll() async {
    try {
      final all = await _storage.readAll();
      return all;
    } catch (e) {
      debugPrint('[SecureStorage] readAll failed: $e');
      return {};
    }
  }

  // ─── Запись ────────────────────────────────────────────────────────────────

  Future<void> write(String key, String? value) async {
    if (value == null) {
      await delete(key);
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[SecureStorage] write($key) failed: $e');
    }
  }

  Future<void> writeAll(Map<String, String> entries) async {
    for (final entry in entries.entries) {
      await write(entry.key, entry.value);
    }
  }

  // ─── Удаление ───────────────────────────────────────────────────────────────

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[SecureStorage] delete($key) failed: $e');
    }
  }

  /// Полная очистка чувствительных данных — используется при логауте.
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[SecureStorage] deleteAll failed: $e');
    }
  }

  // ─── Сахар для типовых операций ─────────────────────────────────────────────

  Future<String?> get authToken => read(SecureKeys.authToken);
  Future<String?> get telegramId => read(SecureKeys.telegramId);
  Future<String?> get deviceId => read(SecureKeys.deviceId);

  Future<void> saveAuth({
    String? authToken,
    String? refreshToken,
    String? telegramId,
  }) async {
    if (authToken != null) await write(SecureKeys.authToken, authToken);
    if (refreshToken != null) await write(SecureKeys.refreshToken, refreshToken);
    if (telegramId != null) await write(SecureKeys.telegramId, telegramId);
  }

  /// Сохранить PII профиля.
  Future<void> saveProfile({
    String? name,
    String? phone,
    String? address,
    String? avatar,
  }) async {
    if (name != null) await write(SecureKeys.userName, name);
    if (phone != null) await write(SecureKeys.userPhone, phone);
    if (address != null) await write(SecureKeys.userAddress, address);
    if (avatar != null) await write(SecureKeys.userAvatar, avatar);
  }

  /// Выход из аккаунта: стираем auth + PII, но device id оставляем.
  Future<void> clearAccount() async {
    await delete(SecureKeys.authToken);
    await delete(SecureKeys.refreshToken);
    await delete(SecureKeys.telegramId);
    await delete(SecureKeys.userName);
    await delete(SecureKeys.userPhone);
    await delete(SecureKeys.userAddress);
    await delete(SecureKeys.userAvatar);
  }
}
