import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Режимы «бюджета эффектов» приложения.
enum EffectsMode { auto, full, eco }

/// Глобальный бюджет визуальных эффектов.
///
/// Правило: не более одного тяжёлого анимированного слоя на экран,
/// а при режиме `eco` (или системном «уменьшить анимацию» / экономии
/// заряда) тяжёлые шейдеры и атмосферные эффекты заменяются
/// статичными фонами — визуал сохраняется, но без перерисовок 60 FPS.
///
/// Режим хранится в SharedPreferences и может быть изменён
/// из настроек (см. settings_screen.dart).
class PerformanceModeService {
  PerformanceModeService._();

  static final PerformanceModeService instance = PerformanceModeService._();

  static const String _prefsKey = 'effects_mode';

  /// Текущий режим. Слушайте через [ValueListenableBuilder] или
  /// проверяйте [effectsEnabled] в тикерах/билдерах.
  final ValueNotifier<EffectsMode> mode = ValueNotifier(EffectsMode.auto);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        mode.value = EffectsMode.values.firstWhere(
          (m) => m.name == raw,
          orElse: () => EffectsMode.auto,
        );
      }
    } catch (e) {
      debugPrint('PerformanceModeService: failed to load mode: $e');
    }
  }

  Future<void> setMode(EffectsMode next) async {
    mode.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next.name);
    } catch (e) {
      debugPrint('PerformanceModeService: failed to save mode: $e');
    }
  }

  /// Включены ли тяжёлые эффекты в данном контексте.
  ///
  /// - `eco` — всегда выключены;
  /// - `full` — включены всегда;
  /// - `auto` — выключены, если система просит уменьшить анимацию
  ///   (disableAnimations / accessibleNavigation).
  bool effectsEnabled(BuildContext? context) {
    switch (mode.value) {
      case EffectsMode.eco:
        return false;
      case EffectsMode.full:
        return true;
      case EffectsMode.auto:
        if (context == null) return true;
        final mq = MediaQuery.maybeOf(context);
        if (mq == null) return true;
        return !(mq.disableAnimations || mq.accessibleNavigation);
    }
  }
}
