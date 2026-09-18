// lib/core/state/app_providers.dart
//
// Riverpod-провайдеры для City Pulse.
//
// Конвенция:
//   • Инфраструктурные сервисы регистрируются в get_it (service_locator.dart),
//     а здесь оборачиваются в Provider для доступа из виджетов.
//   • AsyncNotifier — для данных, которые грузятся из сети/БД
//     (жалобы, камеры, профиль).
//   • Notifier — для синхронного UI-состояния (фильтры карты, активный слой).
//
// Эти провайдеры добавляются как NEW слой. Существующие ChangeNotifier-
// сервисы остаются рабочими — миграция экранов на Riverpod поэтапная.
//
// Item 1 (CityPulse_Improvements.md): Архитектура и Управление состоянием.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_database_service.dart';
import '../../data/local/isar_collections.dart';
import '../../models/complaint.dart';
import '../../services/security/biometric_auth_service.dart';
import '../../services/security/secure_storage_service.dart';
import '../di/service_locator.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ИНФРАСТРУКТУРНЫЕ ПРОВАЙДЕРЫ — обёртки над get_it
// ═══════════════════════════════════════════════════════════════════════════

/// Доступ к локальной БД (sembast-кэш).
final isarDatabaseProvider = Provider<LocalDatabaseService>((ref) {
  return getIt<LocalDatabaseService>();
});

/// Доступ к зашифрованному хранилищу.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return getIt<SecureStorageService>();
});

/// Доступ к биометрической аутентификации.
final biometricAuthProvider = Provider<BiometricAuthService>((ref) {
  return getIt<BiometricAuthService>();
});

// ═══════════════════════════════════════════════════════════════════════════
// AUTH STATE
// ═══════════════════════════════════════════════════════════════════════════

/// Состояние аутентификации.
class AuthState {
  const AuthState({
    this.telegramId,
    this.authToken,
    this.isAuthenticated = false,
    this.isLoading = true,
  });

  final String? telegramId;
  final String? authToken;
  final bool isAuthenticated;
  final bool isLoading;

  AuthState copyWith({
    String? telegramId,
    String? authToken,
    bool? isAuthenticated,
    bool? isLoading,
  }) {
    return AuthState(
      telegramId: telegramId ?? this.telegramId,
      authToken: authToken ?? this.authToken,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final secure = getIt<SecureStorageService>();
    final token = await secure.authToken;
    final tgId = await secure.telegramId;
    return AuthState(
      authToken: token,
      telegramId: tgId,
      isAuthenticated: token != null && token.isNotEmpty,
      isLoading: false,
    );
  }

  Future<void> signIn({required String telegramId, String? authToken}) async {
    final secure = getIt<SecureStorageService>();
    await secure.saveAuth(
      telegramId: telegramId,
      authToken: authToken,
    );
    state = AsyncData(AuthState(
      telegramId: telegramId,
      authToken: authToken,
      isAuthenticated: true,
      isLoading: false,
    ));
  }

  Future<void> signOut() async {
    final secure = getIt<SecureStorageService>();
    await secure.clearAccount();
    state = const AsyncData(AuthState(
      isAuthenticated: false,
      isLoading: false,
    ));
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// ═══════════════════════════════════════════════════════════════════════════
// COMPLAINTS CACHE (offline-first)
// ═══════════════════════════════════════════════════════════════════════════

/// Жалобы из локального кэша Isar (оффлайн-first).
/// UI перестраивается автоматически при изменении кэша (watch).
final complaintsCacheProvider =
    StreamProvider<List<ComplaintCache>>((ref) async* {
  final db = getIt<LocalDatabaseService>();
  // Сразу отдаём текущие данные...
  yield await db.getAllComplaints();
  // ...и обновляем при каждом изменении кэша.
  await for (final _ in db.watchComplaints()) {
    yield await db.getAllComplaints();
  }
});

/// Конвертированные жалобы (онлайн-модель) для UI, который работает с Complaint.
final complaintsProvider = FutureProvider<List<Complaint>>((ref) async {
  final caches = await ref.watch(complaintsCacheProvider.future);
  // Импорт через динамический импорт, чтобы не тащить зависимость циклично.
  return caches
      .map((c) => Complaint(
            id: c.serverId,
            title: c.title.isEmpty ? null : c.title,
            description: c.description,
            address: c.address,
            latitude: c.lat,
            longitude: c.lng,
            category: c.category,
            status: c.status,
            userId: c.userId,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
            verificationScore: c.verificationScore,
          ))
      .toList();
});

/// Количество жалоб, ожидающих синхронизации (для бэйджа в дев-меню).
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final db = getIt<LocalDatabaseService>();
  final pending = await db.getPendingComplaints();
  return pending.length;
});

// ═══════════════════════════════════════════════════════════════════════════
// FAVORITE CAMERAS
// ═══════════════════════════════════════════════════════════════════════════

final favoriteCamerasProvider =
    StreamProvider<List<FavoriteCamera>>((ref) async* {
  final db = getIt<LocalDatabaseService>();
  yield await db.getFavoriteCameras();
  await for (final _ in db.watchFavoriteCameras()) {
    yield await db.getFavoriteCameras();
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// MAP STATE — фильтры и активные слои
// ═══════════════════════════════════════════════════════════════════════════

/// Видимые слои карты.
class MapLayersState {
  const MapLayersState({
    this.problems = true,
    this.events = true,
    this.cameras = true,
    this.transport = false,
    this.lostFound = true,
  });

  final bool problems;
  final bool events;
  final bool cameras;
  final bool transport;
  final bool lostFound;

  MapLayersState copyWith({
    bool? problems,
    bool? events,
    bool? cameras,
    bool? transport,
    bool? lostFound,
  }) {
    return MapLayersState(
      problems: problems ?? this.problems,
      events: events ?? this.events,
      cameras: cameras ?? this.cameras,
      transport: transport ?? this.transport,
      lostFound: lostFound ?? this.lostFound,
    );
  }
}

class MapLayersNotifier extends Notifier<MapLayersState> {
  @override
  MapLayersState build() => const MapLayersState();

  void toggleProblems() =>
      state = state.copyWith(problems: !state.problems);
  void toggleEvents() => state = state.copyWith(events: !state.events);
  void toggleCameras() => state = state.copyWith(cameras: !state.cameras);
  void toggleTransport() =>
      state = state.copyWith(transport: !state.transport);
  void toggleLostFound() =>
      state = state.copyWith(lostFound: !state.lostFound);
}

final mapLayersProvider =
    NotifierProvider<MapLayersNotifier, MapLayersState>(MapLayersNotifier.new);

/// Выбранная категория жалоб на карте (null = все).
final mapCategoryFilterProvider = StateProvider<String?>((ref) => null);

// ═══════════════════════════════════════════════════════════════════════════
// BIOMETRIC AVAILABILITY
// ═══════════════════════════════════════════════════════════════════════════

/// Доступна ли биометрия на устройстве (для условного рендера UI).
final biometricsAvailableProvider = FutureProvider<bool>((ref) async {
  final bio = getIt<BiometricAuthService>();
  return bio.canCheckBiometrics;
});

/// Сетевое подключение (для показа оффлайн-баннера).
/// Реальная реализация в connectivity_plus; здесь — простой флаг.
final isOnlineProvider = StateProvider<bool>((ref) => true);
