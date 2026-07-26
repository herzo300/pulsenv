// lib/core/living/aura_theme_service.dart
//
// Сервис выбора и персистентности премиум-темы AuraLiving.
//
// Хранит выбор пользователя в SharedPreferences и строит готовую сцену
// для AuraLivingBackground. Уведомляет подписчиков при смене темы
// (ChangeNotifier) — экраны перестраивают фон автоматически.
//
// Заменяет прямые вызовы AuraLivingEngine.resolve() в экранах единым
// источником правды: themeService.currentScene.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'aura_living_engine.dart';
import 'aura_theme_catalog.dart';

class AuraThemeService extends ChangeNotifier {
  AuraThemeService._();
  static final AuraThemeService instance = AuraThemeService._();

  static const _prefKey = 'aura_theme_id_v1';
  static const _bgPrefKey = 'aura_theme_bg_v1';

  AuraTheme _theme = AuraThemeCatalog.defaultTheme;
  String? _backgroundImage;
  bool _initialized = false;

  /// Текущая выбранная тема.
  AuraTheme get theme => _theme;

  /// Пользовательское фоновое фото (опционально, поверх темы).
  String? get backgroundImage => _backgroundImage;

  /// Готовая сцена для AuraLivingBackground (тема + фоновое фото).
  AuraLivingScene get currentScene => _theme.toScene(backgroundImage: _backgroundImage);

  /// Инициализация — загрузить сохранённый выбор. Безопасно вызывать多次.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefKey);
      final bg = prefs.getString(_bgPrefKey);
      _theme = AuraThemeCatalog.byId(id);
      _backgroundImage = bg;
      _initialized = true;
      debugPrint('[AuraTheme] loaded: ${_theme.id}');
    } catch (e) {
      debugPrint('[AuraTheme] init failed: $e');
      _initialized = true;
    }
  }

  /// Выбрать тему по id. Персистентно.
  Future<void> selectTheme(String id) async {
    final newTheme = AuraThemeCatalog.byId(id);
    if (newTheme.id == _theme.id) return;
    _theme = newTheme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, id);
      debugPrint('[AuraTheme] selected: $id');
    } catch (e) {
      debugPrint('[AuraTheme] save failed: $e');
    }
  }

  /// Установить пользовательское фоновое фото (URL/file://). null = убрать.
  Future<void> setBackgroundImage(String? url) async {
    if (url == _backgroundImage) return;
    _backgroundImage = url;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url != null) {
        await prefs.setString(_bgPrefKey, url);
      } else {
        await prefs.remove(_bgPrefKey);
      }
    } catch (e) {
      debugPrint('[AuraTheme] save bg failed: $e');
    }
  }
}
