// lib/core/di/service_locator.dart
//
// Сервис-локатор (DI) на базе get_it.
//
// Цель: постепенно заменить ручные синглтоны вида
//   NavigationHistoryService.instance
//   HermesDispatcherService.instance
// на централизованную регистрацию, тестируемую через подмену.
//
// Регистрируются:
//   • LocalDatabaseService    — локальная БД (Item 2)
//   • SecureStorageService    — зашифрованное хранилище (Item 7)
//   • BiometricAuthService    — биометрия (Item 7)
//   • NavigationHistoryService — обёрнут из существующего синглтона
//   • HermesDispatcherService  — обёрнут из существующего синглтона
//
// Паттерн:
//   - Существующие синглтоны НЕ удаляются сразу (обратная совместимость).
//   - Новые сервисы регистрируются в get_it, а экраны, переписанные
//     на Riverpod, берут их отсюда через ProviderContainer.
//
// Item 1 (CityPulse_Improvements.md): Архитектура и Управление состоянием.
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../data/local/local_database_service.dart';
import '../../services/hermes_dispatcher_service.dart';
import '../../services/navigation_history_service.dart';
import '../../services/security/biometric_auth_service.dart';
import '../../services/security/secure_storage_service.dart';

final GetIt getIt = GetIt.instance;

/// Глобальный флаг: прошёл ли bootstrap. Защита от двойной инициализации.
bool _initialized = false;

/// Инициализация всех сервисных зависимостей.
///
/// Вызывается из main.dart ДО runApp(). Повторные вызовы — no-op.
Future<void> setupServiceLocator() async {
  if (_initialized) return;

  // ─── Инфраструктурные сервисы (новые) ───────────────────────────────────
  final localDb = await LocalDatabaseService.instance();
  final secureStorage = await SecureStorageService.instance();
  // Одноразовая миграция PII из SharedPreferences в SecureStorage (Item 7).
  // Игнорируем результат — миграция повторится при ошибке.

  // ─── Регистрация в get_it ───────────────────────────────────────────────
  // Синглтоны: один экземпляр на всё приложение.
  getIt.registerSingleton<LocalDatabaseService>(localDb);
  getIt.registerSingleton<SecureStorageService>(secureStorage);
  getIt.registerSingleton<BiometricAuthService>(BiometricAuthService.instance());

  // Ленивые синглтоны существующих сервисов (обёртка над .instance):
  // это позволяет со временем убрать ручные синглтоны, не ломая вызовы.
  getIt.registerLazySingleton<NavigationHistoryService>(
    () => NavigationHistoryService.instance,
  );
  getIt.registerLazySingleton<HermesDispatcherService>(
    () => HermesDispatcherService.instance,
  );

  _initialized = true;
  debugPrint('[DI] service locator initialized');
}

/// Сброс локатора — только для тестов.
@visibleForTesting
Future<void> resetServiceLocator({bool dispose = false}) async {
  await getIt.reset();
  _initialized = false;
}
