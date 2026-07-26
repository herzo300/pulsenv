// lib/services/security/secure_storage_migration.dart
//
// Одноразовая миграция чувствительных данных из SharedPreferences
// в flutter_secure_storage (Keychain / Android Keystore).
//
// Безопасность:
//   • Запускается один раз (флаг secure_storage_migrated_v1 в SecureStorage).
//   • После успешной миграции старые значения удаляются из SharedPreferences,
//     чтобы не оставались в открытом виде.
//   • Если миграция падает на середине — флаг НЕ ставится, при следующем
//     запуске повторится (идемпотентно по write).
//
// Item 7 (CityPulse_Improvements.md): Безопасность и Стабильность.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_storage_service.dart';

class SecureStorageMigration {
  SecureStorageMigration._();

  /// Точки входа: map SharedPreferences key -> SecureStorage key.
  /// Только чувствительные данные. Не-PII настройки (тема, вкладка, фильтры)
  /// остаются в SharedPreferences / AppStateService — они не критичны.
  static const Map<String, String> _sensitiveKeyMap = {
    // device identity
    'runtime_device_id_v1': SecureKeys.deviceId,
  };

  /// Запустить миграцию, если она ещё не выполнялась.
  ///
  /// Возвращает true, если миграция была выполнена (или уже была сделана).
  static Future<bool> runIfNeeded() async {
    final secure = await SecureStorageService.instance();

    final alreadyMigrated = await secure.read(SecureKeys.migratedFlag);
    if (alreadyMigrated == '1') {
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var migratedCount = 0;

      for (final entry in _sensitiveKeyMap.entries) {
        final prefKey = entry.key;
        final secureKey = entry.value;

        final value = prefs.getString(prefKey);
        if (value != null && value.isNotEmpty) {
          await secure.write(secureKey, value);
          await prefs.remove(prefKey);
          migratedCount++;
          debugPrint('[SecureMigration] moved $prefKey -> secure storage');
        }
      }

      // Помечаем миграцию выполненной, даже если ничего не нашли —
      // это значит, что в старом хранилище чувствительных данных не было.
      await secure.write(SecureKeys.migratedFlag, '1');
      debugPrint('[SecureMigration] complete, moved $migratedCount value(s)');
      return true;
    } catch (e) {
      debugPrint('[SecureMigration] FAILED, will retry next launch: $e');
      return false;
    }
  }
}
