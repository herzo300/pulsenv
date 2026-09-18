import 'package:flutter/material.dart';

import '../theme/pulse_colors.dart';

/// Base class for splash screen themes.
///
/// Usage:
/// ```dart
/// class GoldSplashTheme extends SplashThemeData {
///   @override
///   Color get background => PulseColors.background;
///   @override
///   Color get primary => PulseColors.accentGold;
///   @override
///   String get title => 'НИЖНЕВАРТОВСК';
///   // ...
/// }
/// ```
abstract class SplashThemeData {
  const SplashThemeData();

  /// Screen background color
  Color get background;

  /// Primary accent color
  Color get primary;

  /// Secondary accent (optional)
  Color? get secondary;

  /// Main title text
  String get title;

  /// Subtitle text
  String get subtitle;

  /// Description text
  String get description;

  /// Ready state description
  String get readyDescription;

  /// Loading status label
  String get loadingLabel => 'ЗАГРУЗКА КОНТУРА';

  /// Ready status label
  String get readyLabel => 'ГОТОВО К РАБОТЕ';

  /// Sync label
  String get syncLabel => 'СИНХРОНИЗАЦИЯ СЕВЕРНОГО МОНИТОРИНГА';

  /// Progress text template (use {} for percentage placeholder)
  String progressText(double percent) => '${(percent * 100).round()}%';

  /// Whether to show grid overlay
  bool get showGrid => false;

  /// Whether to show particle/rain effect
  bool get showParticles => false;

  /// Whether to show aurora waves
  bool get showAurora => false;
}

/// Gold/Oil theme — main splash
class GoldSplashTheme extends SplashThemeData {
  const GoldSplashTheme();

  @override
  Color get background => PulseColors.background;
  @override
  Color get primary => PulseColors.accentGold;
  @override
  Color? get secondary => PulseColors.primary;
  @override
  String get title => 'НИЖНЕВАРТОВСК';
  @override
  String get subtitle => 'НЕФТЕГАЗОВАЯ СТОЛИЦА';
  @override
  String get description =>
      'Запускаем северный индустриальный контур: aurora-слой, пульс города, карту событий и мониторинг жизненно важной инфраструктуры.';
  @override
  String get readyDescription =>
      'Северный контур синхронизирован. Городская карта, сигналы и индустриальные потоки готовы к работе.';
  @override
  bool get showAurora => true;
}

/// Cyber theme — network/sensors splash
class CyberSplashTheme extends SplashThemeData {
  const CyberSplashTheme();

  @override
  Color get background => PulseColors.background;
  @override
  Color get primary => PulseColors.primary;
  @override
  Color? get secondary => PulseColors.success;
  @override
  String get title => 'ПУЛЬС СЕТИ';
  @override
  String get subtitle => 'КИБЕР СЛОЙ';
  @override
  String get description =>
      'Киберслой собирает радары, камеры и городские сигналы в единый сетевой импульс.';
  @override
  String get readyDescription => 'Карта и камеры готовы к входу.';
  @override
  String get loadingLabel => 'КАЛИБРОВКА СЕНСОРОВ';
  @override
  String get readyLabel => 'АКТИВИРОВАТЬ СИСТЕМУ';
  @override
  String get syncLabel => 'Собираем слой города и стабилизируем сетевой контур.';
  @override
  bool get showGrid => true;
}

/// Swamp theme — monitoring/telemetry splash
class SwampSplashTheme extends SplashThemeData {
  const SwampSplashTheme();

  @override
  Color get background => PulseColors.background;
  @override
  Color get primary => PulseColors.success;
  @override
  Color? get secondary => PulseColors.primaryDeep;
  @override
  String get title => 'НЕФТЕЮГАНСКИЙ МОНИТОР';
  @override
  String get subtitle => 'КОМПЛЕКСНЫЙ АНАЛИЗ БОЛОТНЫХ МАССИВОВ';
  @override
  String get description => 'Инициализация телеметрии скважин...';
  @override
  String get readyDescription => 'Система телеметрии активна.';
  @override
  String get loadingLabel => 'БУРЕНИЕ...';
  @override
  String get readyLabel => 'ДОСТУП';
  @override
  bool get showParticles => true;
}
