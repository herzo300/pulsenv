// lib/services/app_state_service.dart
// Централизованный сервис персистентного состояния приложения.
// Хранит состояние для каждого пользователя отдельно (по userId).
// Включает: активная вкладка, настройки карты, настройки UI, фильтры.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Все ключи состояния в одном месте — ни один не потеряется
class _K {
  _K._();

  // ─── Идентификация пользователя
  static const userId = 'telegram_id';

  // ─── Навигация / вкладки
  static String activeTab(int uid)       => 'u${uid}_active_tab';
  static String lastRoute(int uid)       => 'u${uid}_last_route';

  // ─── Карта
  static String mapLat(int uid)          => 'u${uid}_map_lat';
  static String mapLng(int uid)          => 'u${uid}_map_lng';
  static String mapZoom(int uid)         => 'u${uid}_map_zoom';
  static String mapSatellite(int uid)    => 'u${uid}_map_satellite';
  static String mapNightMode(int uid)    => 'u${uid}_map_night';
  static String mapCategories(int uid)   => 'u${uid}_map_categories';
  static String mapDistricts(int uid)    => 'u${uid}_map_districts';
  static String mapLayerProblems(int uid)   => 'u${uid}_layer_problems';
  static String mapLayerEvents(int uid)     => 'u${uid}_layer_events';
  static String mapLayerCameras(int uid)    => 'u${uid}_layer_cameras';
  static String mapLayerTransport(int uid)  => 'u${uid}_layer_transport';
  static String mapLayerLostFound(int uid)  => 'u${uid}_layer_lostfound';

  // ─── Город
  static String activeCity(int uid)     => 'u${uid}_active_city';

  // ─── Настройки UI
  static String themeMode(int uid)      => 'u${uid}_theme_mode';    // 'light'|'dark'|'system'
  static String splashTheme(int uid)    => 'u${uid}_splash_theme';
  static String isMenuOnRight(int uid)  => 'u${uid}_is_menu_right';
  static String autoReturnCamera(int uid) => 'u${uid}_auto_return_camera';

  // ─── Настройки уведомлений
  static String notifEnabled(int uid)   => 'u${uid}_notif_enabled';
  static String soundEnabled(int uid)   => 'u${uid}_sound_enabled';
  static String soundVolume(int uid)    => 'u${uid}_sound_volume';
  static String voiceEnabled(int uid)   => 'u${uid}_voice_enabled';
  static String weatherAlerts(int uid)  => 'u${uid}_weather_alerts';
  static String notifCategories(int uid)=> 'u${uid}_notif_categories';

  // ─── Профиль / персонализация
  static String userName(int uid)       => 'u${uid}_user_name';
  static String userAvatar(int uid)     => 'u${uid}_user_avatar';
  static String userDistrict(int uid)   => 'u${uid}_user_district';

  // ─── Статистика сессий
  static String launchCount(int uid)    => 'u${uid}_launch_count';
  static String lastLaunchTs(int uid)   => 'u${uid}_last_launch_ts';
  static String totalTimeMs(int uid)    => 'u${uid}_total_time_ms';

  // ─── Черновики / избранное (JSON-список)
  static String favorites(int uid)      => 'u${uid}_favorites';
  static String favCameras(int uid)     => 'u${uid}_fav_cameras';
}

/// Snapshot состояния одного пользователя (in-memory кэш)
class UserAppState {
  final int userId;

  // Навигация
  String activeTab;
  String lastRoute;

  // Карта
  double? mapLat;
  double? mapLng;
  double? mapZoom;
  bool mapSatellite;
  bool mapNightMode;
  List<String> mapCategories;
  List<String> mapDistricts;
  bool layerProblems;
  bool layerEvents;
  bool layerCameras;
  bool layerTransport;
  bool layerLostFound;

  // Город
  String activeCity;

  // UI
  String themeMode;
  String splashTheme;
  bool isMenuOnRight;
  bool autoReturnCamera;

  // Уведомления
  bool notifEnabled;
  bool soundEnabled;
  double soundVolume;
  bool voiceEnabled;
  bool weatherAlerts;
  Map<String, bool> notifCategories;

  // Профиль
  String userName;
  String? userAvatar;
  String? userDistrict;

  // Сессия
  int launchCount;
  DateTime? lastLaunch;
  int totalTimeMs;

  // Избранное
  List<String> favorites;
  List<String> favCameras;

  UserAppState({
    required this.userId,
    this.activeTab = '/map',
    this.lastRoute = '/map',
    this.mapLat,
    this.mapLng,
    this.mapZoom,
    this.mapSatellite = false,
    this.mapNightMode = false,
    this.mapCategories = const [],
    this.mapDistricts = const [],
    this.layerProblems = true,
    this.layerEvents = true,
    this.layerCameras = true,
    this.layerTransport = false,
    this.layerLostFound = true,
    this.activeCity = 'nizhnevartovsk',
    this.themeMode = 'system',
    this.splashTheme = 'gravity',
    this.isMenuOnRight = false,
    this.autoReturnCamera = true,
    this.notifEnabled = true,
    this.soundEnabled = true,
    this.soundVolume = 0.8,
    this.voiceEnabled = false,
    this.weatherAlerts = true,
    this.notifCategories = const {},
    this.userName = '',
    this.userAvatar,
    this.userDistrict,
    this.launchCount = 0,
    this.lastLaunch,
    this.totalTimeMs = 0,
    this.favorites = const [],
    this.favCameras = const [],
  });

  UserAppState copyWith({
    String? activeTab,
    String? lastRoute,
    double? mapLat,
    double? mapLng,
    double? mapZoom,
    bool? mapSatellite,
    bool? mapNightMode,
    List<String>? mapCategories,
    List<String>? mapDistricts,
    bool? layerProblems,
    bool? layerEvents,
    bool? layerCameras,
    bool? layerTransport,
    bool? layerLostFound,
    String? activeCity,
    String? themeMode,
    String? splashTheme,
    bool? isMenuOnRight,
    bool? autoReturnCamera,
    bool? notifEnabled,
    bool? soundEnabled,
    double? soundVolume,
    bool? voiceEnabled,
    bool? weatherAlerts,
    Map<String, bool>? notifCategories,
    String? userName,
    String? userAvatar,
    String? userDistrict,
    int? launchCount,
    DateTime? lastLaunch,
    int? totalTimeMs,
    List<String>? favorites,
    List<String>? favCameras,
  }) {
    return UserAppState(
      userId: userId,
      activeTab: activeTab ?? this.activeTab,
      lastRoute: lastRoute ?? this.lastRoute,
      mapLat: mapLat ?? this.mapLat,
      mapLng: mapLng ?? this.mapLng,
      mapZoom: mapZoom ?? this.mapZoom,
      mapSatellite: mapSatellite ?? this.mapSatellite,
      mapNightMode: mapNightMode ?? this.mapNightMode,
      mapCategories: mapCategories ?? this.mapCategories,
      mapDistricts: mapDistricts ?? this.mapDistricts,
      layerProblems: layerProblems ?? this.layerProblems,
      layerEvents: layerEvents ?? this.layerEvents,
      layerCameras: layerCameras ?? this.layerCameras,
      layerTransport: layerTransport ?? this.layerTransport,
      layerLostFound: layerLostFound ?? this.layerLostFound,
      activeCity: activeCity ?? this.activeCity,
      themeMode: themeMode ?? this.themeMode,
      splashTheme: splashTheme ?? this.splashTheme,
      isMenuOnRight: isMenuOnRight ?? this.isMenuOnRight,
      autoReturnCamera: autoReturnCamera ?? this.autoReturnCamera,
      notifEnabled: notifEnabled ?? this.notifEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      weatherAlerts: weatherAlerts ?? this.weatherAlerts,
      notifCategories: notifCategories ?? this.notifCategories,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userDistrict: userDistrict ?? this.userDistrict,
      launchCount: launchCount ?? this.launchCount,
      lastLaunch: lastLaunch ?? this.lastLaunch,
      totalTimeMs: totalTimeMs ?? this.totalTimeMs,
      favorites: favorites ?? this.favorites,
      favCameras: favCameras ?? this.favCameras,
    );
  }
}

/// Centralized per-user app state manager.
/// 
/// Usage:
///   await AppStateService.instance.load();   // on app start
///   AppStateService.instance.state          // current UserAppState
///   await AppStateService.instance.save(state.copyWith(mapZoom: 14)); // after change
class AppStateService extends ChangeNotifier {
  AppStateService._();

  static final AppStateService _instance = AppStateService._();
  static AppStateService get instance => _instance;

  UserAppState _state = UserAppState(userId: 0);
  UserAppState get state => _state;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  DateTime? _sessionStart;

  // ─── Lifecycle ──────────────────────────────────────────────────────

  /// Call once at app startup. Reads current userId then loads state.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt(_K.userId) ?? 0;
    await _loadForUser(uid, prefs);
    _sessionStart = DateTime.now();

    // Increment launch count
    final newCount = _state.launchCount + 1;
    await _patch((s) => s.copyWith(
      launchCount: newCount,
      lastLaunch: DateTime.now(),
    ));

    _loaded = true;
    notifyListeners();
  }

  /// Call when userId changes (after login).
  Future<void> onUserIdChanged(int newUid) async {
    await _flushSessionTime(); // save time for previous user
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_K.userId, newUid);
    await _loadForUser(newUid, prefs);
    _sessionStart = DateTime.now();
    notifyListeners();
  }

  /// Call when app goes to background / terminates.
  Future<void> onAppPause() async {
    await _flushSessionTime();
  }

  /// Call when app resumes.
  void onAppResume() {
    _sessionStart = DateTime.now();
  }

  // ─── Read helpers ───────────────────────────────────────────────────

  T get<T>(T Function(UserAppState s) selector) => selector(_state);

  // ─── Write helpers ──────────────────────────────────────────────────

  /// Atomically update state and persist the changes.
  Future<void> save(UserAppState updated) async {
    _state = updated;
    notifyListeners();
    await _writeAll(await SharedPreferences.getInstance());
  }

  /// Convenience: update only specific fields.
  Future<void> patch(UserAppState Function(UserAppState s) updater) async {
    await _patch(updater);
    notifyListeners();
  }

  // ─── Map state shortcuts ────────────────────────────────────────────

  Future<void> saveMapPosition({
    required double lat,
    required double lng,
    required double zoom,
  }) async {
    await _patch((s) => s.copyWith(mapLat: lat, mapLng: lng, mapZoom: zoom));
  }

  Future<void> saveMapFilters({
    required List<String> categories,
    required List<String> districts,
  }) async {
    await _patch((s) =>
        s.copyWith(mapCategories: categories, mapDistricts: districts));
  }

  Future<void> saveMapLayers({
    bool? problems,
    bool? events,
    bool? cameras,
    bool? transport,
    bool? lostFound,
  }) async {
    await _patch((s) => s.copyWith(
      layerProblems: problems,
      layerEvents: events,
      layerCameras: cameras,
      layerTransport: transport,
      layerLostFound: lostFound,
    ));
  }

  Future<void> saveMapDisplayMode({
    bool? satellite,
    bool? nightMode,
  }) async {
    await _patch((s) =>
        s.copyWith(mapSatellite: satellite, mapNightMode: nightMode));
  }

  // ─── Settings shortcuts ─────────────────────────────────────────────

  Future<void> saveNotificationSettings({
    bool? enabled,
    bool? sound,
    double? volume,
    bool? voice,
    bool? weatherAlerts,
    Map<String, bool>? categories,
  }) async {
    await _patch((s) => s.copyWith(
      notifEnabled: enabled,
      soundEnabled: sound,
      soundVolume: volume,
      voiceEnabled: voice,
      weatherAlerts: weatherAlerts,
      notifCategories: categories,
    ));
  }

  Future<void> saveActiveCity(String cityId) async {
    await _patch((s) => s.copyWith(activeCity: cityId));
  }

  Future<void> saveLastRoute(String route) async {
    // Only persist meaningful routes (skip splash/lock screens)
    if (route == '/' || route.contains('security') || route.contains('splash')) return;
    await _patch((s) => s.copyWith(lastRoute: route));
  }

  Future<void> saveTheme(String themeMode) async {
    await _patch((s) => s.copyWith(themeMode: themeMode));
  }

  Future<void> saveMenuPosition(bool isRight) async {
    await _patch((s) => s.copyWith(isMenuOnRight: isRight));
  }

  Future<void> saveProfile({String? name, String? avatar, String? district}) async {
    await _patch((s) => s.copyWith(
      userName: name,
      userAvatar: avatar,
      userDistrict: district,
    ));
  }

  Future<void> toggleFavorite(String itemId) async {
    final favs = List<String>.from(_state.favorites);
    if (favs.contains(itemId)) {
      favs.remove(itemId);
    } else {
      favs.add(itemId);
    }
    await _patch((s) => s.copyWith(favorites: favs));
  }

  Future<void> toggleFavoriteCamera(String url) async {
    final cams = List<String>.from(_state.favCameras);
    if (cams.contains(url)) {
      cams.remove(url);
    } else {
      cams.add(url);
    }
    await _patch((s) => s.copyWith(favCameras: cams));
  }

  bool isFavorite(String itemId) => _state.favorites.contains(itemId);
  bool isCameraFavorite(String url) => _state.favCameras.contains(url);

  // ─── Session time tracking ──────────────────────────────────────────

  Future<void> _flushSessionTime() async {
    if (_sessionStart == null) return;
    final elapsed = DateTime.now().difference(_sessionStart!).inMilliseconds;
    _sessionStart = null;
    await _patch((s) => s.copyWith(totalTimeMs: s.totalTimeMs + elapsed));
  }

  // ─── Internal: load / write ─────────────────────────────────────────

  Future<void> _loadForUser(int uid, SharedPreferences prefs) async {
    _state = UserAppState(
      userId: uid,
      activeTab: prefs.getString(_K.activeTab(uid)) ?? '/map',
      lastRoute: prefs.getString(_K.lastRoute(uid)) ?? '/map',
      mapLat: prefs.getDouble(_K.mapLat(uid)),
      mapLng: prefs.getDouble(_K.mapLng(uid)),
      mapZoom: prefs.getDouble(_K.mapZoom(uid)),
      mapSatellite: prefs.getBool(_K.mapSatellite(uid)) ?? false,
      mapNightMode: prefs.getBool(_K.mapNightMode(uid)) ?? false,
      mapCategories:
          prefs.getStringList(_K.mapCategories(uid)) ?? const [],
      mapDistricts:
          prefs.getStringList(_K.mapDistricts(uid)) ?? const [],
      layerProblems: prefs.getBool(_K.mapLayerProblems(uid)) ?? true,
      layerEvents: prefs.getBool(_K.mapLayerEvents(uid)) ?? true,
      layerCameras: prefs.getBool(_K.mapLayerCameras(uid)) ?? true,
      layerTransport: prefs.getBool(_K.mapLayerTransport(uid)) ?? false,
      layerLostFound: prefs.getBool(_K.mapLayerLostFound(uid)) ?? true,
      activeCity:
          prefs.getString(_K.activeCity(uid)) ?? 'nizhnevartovsk',
      themeMode: prefs.getString(_K.themeMode(uid)) ?? 'dark',
      splashTheme: prefs.getString(_K.splashTheme(uid)) ?? 'gravity',
      isMenuOnRight: prefs.getBool(_K.isMenuOnRight(uid)) ?? false,
      autoReturnCamera: prefs.getBool(_K.autoReturnCamera(uid)) ?? true,
      notifEnabled: prefs.getBool(_K.notifEnabled(uid)) ?? true,
      soundEnabled: prefs.getBool(_K.soundEnabled(uid)) ?? true,
      soundVolume: prefs.getDouble(_K.soundVolume(uid)) ?? 0.8,
      voiceEnabled: prefs.getBool(_K.voiceEnabled(uid)) ?? false,
      weatherAlerts: prefs.getBool(_K.weatherAlerts(uid)) ?? true,
      notifCategories: _decodeMap(prefs.getString(_K.notifCategories(uid))),
      userName: prefs.getString(_K.userName(uid)) ?? '',
      userAvatar: prefs.getString(_K.userAvatar(uid)),
      userDistrict: prefs.getString(_K.userDistrict(uid)),
      launchCount: prefs.getInt(_K.launchCount(uid)) ?? 0,
      lastLaunch: _decodeDateTime(prefs.getString(_K.lastLaunchTs(uid))),
      totalTimeMs: prefs.getInt(_K.totalTimeMs(uid)) ?? 0,
      favorites:
          prefs.getStringList(_K.favorites(uid)) ?? const [],
      favCameras:
          prefs.getStringList(_K.favCameras(uid)) ?? const [],
    );
  }

  Future<void> _writeAll(SharedPreferences prefs) async {
    final s = _state;
    final uid = s.userId;

    await Future.wait([
      prefs.setString(_K.activeTab(uid), s.activeTab),
      prefs.setString(_K.lastRoute(uid), s.lastRoute),
      if (s.mapLat != null) prefs.setDouble(_K.mapLat(uid), s.mapLat!),
      if (s.mapLng != null) prefs.setDouble(_K.mapLng(uid), s.mapLng!),
      if (s.mapZoom != null) prefs.setDouble(_K.mapZoom(uid), s.mapZoom!),
      prefs.setBool(_K.mapSatellite(uid), s.mapSatellite),
      prefs.setBool(_K.mapNightMode(uid), s.mapNightMode),
      prefs.setStringList(_K.mapCategories(uid), s.mapCategories),
      prefs.setStringList(_K.mapDistricts(uid), s.mapDistricts),
      prefs.setBool(_K.mapLayerProblems(uid), s.layerProblems),
      prefs.setBool(_K.mapLayerEvents(uid), s.layerEvents),
      prefs.setBool(_K.mapLayerCameras(uid), s.layerCameras),
      prefs.setBool(_K.mapLayerTransport(uid), s.layerTransport),
      prefs.setBool(_K.mapLayerLostFound(uid), s.layerLostFound),
      prefs.setString(_K.activeCity(uid), s.activeCity),
      prefs.setString(_K.themeMode(uid), s.themeMode),
      prefs.setString(_K.splashTheme(uid), s.splashTheme),
      prefs.setBool(_K.isMenuOnRight(uid), s.isMenuOnRight),
      prefs.setBool(_K.autoReturnCamera(uid), s.autoReturnCamera),
      // Mirror splash theme to the global key so SplashRouterScreen
      // (read before user profile is hydrated) always sees the latest choice.
      prefs.setString('splash_theme', s.splashTheme),
      prefs.setBool(_K.notifEnabled(uid), s.notifEnabled),
      prefs.setBool(_K.soundEnabled(uid), s.soundEnabled),
      prefs.setDouble(_K.soundVolume(uid), s.soundVolume),
      prefs.setBool(_K.voiceEnabled(uid), s.voiceEnabled),
      prefs.setBool(_K.weatherAlerts(uid), s.weatherAlerts),
      prefs.setString(_K.notifCategories(uid), _encodeMap(s.notifCategories)),
      if (s.userName.isNotEmpty) prefs.setString(_K.userName(uid), s.userName),
      if (s.userAvatar != null) prefs.setString(_K.userAvatar(uid), s.userAvatar!),
      if (s.userDistrict != null) prefs.setString(_K.userDistrict(uid), s.userDistrict!),
      prefs.setInt(_K.launchCount(uid), s.launchCount),
      if (s.lastLaunch != null)
        prefs.setString(_K.lastLaunchTs(uid), s.lastLaunch!.toIso8601String()),
      prefs.setInt(_K.totalTimeMs(uid), s.totalTimeMs),
      prefs.setStringList(_K.favorites(uid), s.favorites),
      prefs.setStringList(_K.favCameras(uid), s.favCameras),
    ]);
  }

  Future<void> _patch(UserAppState Function(UserAppState s) updater) async {
    _state = updater(_state);
    final prefs = await SharedPreferences.getInstance();
    await _writeAll(prefs);
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  static Map<String, bool> _decodeMap(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final raw = jsonDecode(json) as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {
      return {};
    }
  }

  static String _encodeMap(Map<String, bool> map) {
    try {
      return jsonEncode(map);
    } catch (_) {
      return '{}';
    }
  }

  static DateTime? _decodeDateTime(String? str) {
    if (str == null) return null;
    try {
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  /// Debug: print all state (dev builds only)
  void debugDump() {
    if (!kDebugMode) return;
    debugPrint('''
══════════════════════════════
AppStateService — uid:${_state.userId}
  lastRoute     : ${_state.lastRoute}
  activeCity    : ${_state.activeCity}
  mapZoom       : ${_state.mapZoom}
  mapNightMode  : ${_state.mapNightMode}
  mapSatellite  : ${_state.mapSatellite}
  categories    : ${_state.mapCategories}
  districts     : ${_state.mapDistricts}
  launchCount   : ${_state.launchCount}
  totalTime     : ${Duration(milliseconds: _state.totalTimeMs)}
══════════════════════════════''');
  }
}
