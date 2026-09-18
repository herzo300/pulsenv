import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages app-wide theme mode (dark/light/system) with persistence.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();

  static const _prefsKey = 'app_theme_mode';
  static ThemeProvider? _instance;
  static ThemeProvider get instance => _instance ??= ThemeProvider._();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _themeMode = switch (saved) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    } catch (e, st) {
      debugPrint('[ThemeProvider] Failed to load saved theme: $e\n$st');
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey,
          switch (mode) {
            ThemeMode.dark => 'dark',
            ThemeMode.light => 'light',
            ThemeMode.system => 'system',
          });
    } catch (e, st) {
      debugPrint('[ThemeProvider] Theme persistence failed: $e\n$st');
    }
    notifyListeners();
  }

  Future<void> toggleDarkLight() async {
    await setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }
}
