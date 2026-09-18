// lib/theme/pulse_typography.dart
//
// Единая типографическая шкала City Pulse (премиальный дизайн-слой).
//
// Принципы премиум-типографики:
//   • 5 уровней иерархии (display/title/body/label/caption), не больше.
//   • 2-3 веса на всё приложение (Regular 400, SemiBold 600, Bold 700).
//   • Фиксированный line-height для визуального ритма.
//   • Display/Title — Exo2 (характер), Body/Label/Caption — Manrope (читаемость).
//
// Дизайн-рекомендация 2: Типографическая иерархия.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pulse_colors.dart';

/// Единый типографический слой приложения.
abstract final class PulseTypography {
  PulseTypography._();

  // ─── Семейства шрифтов ─────────────────────────────────────────────────────
  /// Дисплейный шрифт для крупных заголовков (Exo2 — характер, узнаваемость).
  static String get displayFamily => GoogleFonts.exo2().fontFamily!;

  /// Основной шрифт для текста (Manrope — высокая читаемость).
  static String get bodyFamily => GoogleFonts.manrope().fontFamily!;

  // ─── Дисплей (крупные числа, hero-экраны) ─────────────────────────────────
  /// Огромные числа (температура на WeatherScreen, уровень XP). 56px / w200.
  static TextStyle get displayHero => TextStyle(
        fontFamily: displayFamily,
        fontSize: 56,
        fontWeight: FontWeight.w200,
        height: 1.05,
        letterSpacing: -0.5,
        color: PulseColors.textPrimary,
      );

  /// Большие заголовки экранов. 32px / w700.
  static TextStyle get displayLarge => TextStyle(
        fontFamily: displayFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.3,
        color: PulseColors.textPrimary,
      );

  /// Средние заголовки секций. 24px / w700.
  static TextStyle get displayMedium => TextStyle(
        fontFamily: displayFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: PulseColors.textPrimary,
      );

  // ─── Заголовки ─────────────────────────────────────────────────────────────
  /// Заголовок карточки/панели. 18px / w600.
  static TextStyle get titleLarge => TextStyle(
        fontFamily: bodyFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: PulseColors.textPrimary,
      );

  /// Подзаголовок, элемент списка. 16px / w600.
  static TextStyle get titleMedium => TextStyle(
        fontFamily: bodyFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: PulseColors.textPrimary,
      );

  // ─── Основной текст ────────────────────────────────────────────────────────
  /// Основной текст (описание жалобы, тело статьи). 15px / w400.
  static TextStyle get bodyLarge => TextStyle(
        fontFamily: bodyFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: PulseColors.textPrimary,
      );

  /// Вторичный текст (подсказки, мета). 13px / w400.
  static TextStyle get bodyMedium => TextStyle(
        fontFamily: bodyFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: PulseColors.textSecondary,
      );

  // ─── Подписи ───────────────────────────────────────────────────────────────
  /// Подписи кнопок, табов. 14px / w600.
  static TextStyle get labelLarge => TextStyle(
        fontFamily: bodyFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: PulseColors.textPrimary,
      );

  /// Маленькие подписи (чипы, бейджи). 12px / w600.
  static TextStyle get labelMedium => TextStyle(
        fontFamily: bodyFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: PulseColors.textPrimary,
      );

  // ─── Caption ───────────────────────────────────────────────────────────────
  /// Вспомогательный текст (время, метаданные). 11px / w400.
  static TextStyle get caption => TextStyle(
        fontFamily: bodyFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: PulseColors.textSecondary,
      );

  // ─── Маппинг в Material TextTheme ──────────────────────────────────────────
  /// Готовая Material TextTheme для ThemeData.
  /// Используется в main.dart вместо ручного copyWith.
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displayMedium,
        headlineLarge: displayLarge,
        headlineMedium: displayMedium,
        headlineSmall: titleLarge,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: labelLarge,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: caption,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: caption,
      );
}

/// Цветовые акценты для типографики в светлой теме.
abstract final class PulseTypographyLight {
  PulseTypographyLight._();

  static TextStyle get displayHero => PulseTypography.displayHero
      .copyWith(color: PulseColors.lightTextPrimary);
  static TextStyle get displayLarge => PulseTypography.displayLarge
      .copyWith(color: PulseColors.lightTextPrimary);
}
