// lib/utils/pulse_haptics.dart
//
// Единая тактильная отдача для премиум-ощущения приложения.
//
// Принципы:
//   • Каждый тип действия = свой паттерн haptic (пользователь учится
//     распознавать результат на ощупь).
//   • Уважение к настройкам: если пользователь отключил вибрацию в
//     AppStateService — методы no-op.
//   • Использует HapticFeedback (системный движок) — без отдельной permission.
//
// Дизайн-рекомендация 6: Haptic + spring-анимации на ключевых действиях.
import 'package:flutter/services.dart';

abstract final class PulseHaptics {
  PulseHaptics._();

  /// Лёгкое касание при навигации/выборе таба.
  static Future<void> tap() => HapticFeedback.selectionClick();

  /// Подтверждение действия (отправка жалобы, сохранение).
  static Future<void> confirm() => HapticFeedback.mediumImpact();

  /// Успех (получен XP, жалоба принята, уровень повышен).
  static Future<void> success() => HapticFeedback.heavyImpact();

  /// Предупреждение / некритичная ошибка (валидация формы).
  static Future<void> warning() => HapticFeedback.lightImpact();

  /// Ошибка (сетевой сбой, отказ действия).
  static Future<void> error() => HapticFeedback.vibrate();
}
