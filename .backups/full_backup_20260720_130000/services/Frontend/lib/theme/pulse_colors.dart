import 'package:flutter/material.dart';
import 'theme_provider.dart';

abstract final class PulseColors {
  // ─── Dark mode constants (explicit/fixed) ───
  static const Color darkBackground = Color(0xFF0C1424);
  static const Color darkBackgroundRaised = Color(0xFF121E33);
  static const Color darkSurface = Color(0xFF182944);
  static const Color darkSurfaceSoft = Color(0xFF1E3557);
  static const Color darkSurfaceElevated = Color(0xFF24416A);
  static const Color darkSurfaceGlass = Color(0x29182944);
  static const Color darkTextPrimary = Color(0xFFE6FAFF);
  static const Color darkTextSecondary = Color(0xFF8EAFC2);
  static const Color darkTextTertiary = Color(0xFF66849A);
  static const Color darkBorder = Color(0x223FD8F8);
  static const Color darkBorderStrong = Color(0x443FD8F8);

  // ─── Light mode constants (explicit/fixed) ───
  static const Color lightBackground = Color(0xFFF5FAFF);
  static const Color lightBackgroundRaised = Color(0xFFE8F2FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSoft = Color(0xFFF0F6FC);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceGlass = Color(0x38FFFFFF);
  static const Color lightTextPrimary = Color(0xFF0A2540);
  static const Color lightTextSecondary = Color(0xFF243B53);
  static const Color lightTextTertiary = Color(0xFF486581);
  static const Color lightBorder = Color(0x330EA5C7);
  static const Color lightBorderStrong = Color(0x660EA5C7);

  // ─── Dynamic getters resolving online ───
  static Color get background => ThemeProvider.instance.isDarkMode ? darkBackground : lightBackground;
  static Color get backgroundRaised => ThemeProvider.instance.isDarkMode ? darkBackgroundRaised : lightBackgroundRaised;
  static Color get surface => ThemeProvider.instance.isDarkMode ? darkSurface : lightSurface;
  static Color get surfaceSoft => ThemeProvider.instance.isDarkMode ? darkSurfaceSoft : lightSurfaceSoft;
  static Color get surfaceElevated => ThemeProvider.instance.isDarkMode ? darkSurfaceElevated : lightSurfaceElevated;
  static Color get surfaceGlass => ThemeProvider.instance.isDarkMode ? darkSurfaceGlass : lightSurfaceGlass;
  static const Color surfaceLight = Color(0xFFF2FBFF);
  
  static Color get textPrimary => ThemeProvider.instance.isDarkMode ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary => ThemeProvider.instance.isDarkMode ? darkTextSecondary : lightTextSecondary;
  static Color get textTertiary => ThemeProvider.instance.isDarkMode ? darkTextTertiary : lightTextTertiary;

  static Color get border => ThemeProvider.instance.isDarkMode ? darkBorder : lightBorder;
  static Color get borderStrong => ThemeProvider.instance.isDarkMode ? darkBorderStrong : lightBorderStrong;

  // ─── Shared brand & accents ───
  static Color get primary => ThemeProvider.instance.isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF0EA5C7);
  static const Color primarySoft = Color(0xFF7DF2FF);
  static const Color primaryDeep = Color(0xFF0EA5C7);
  static const Color accentViolet = Color(0xFF7C4DFF);
  static const Color accentGold = Color(0xFFFFC857);
  static const Color negative = Color(0xFFFF3D00);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFC857);
  static const Color neutral = Color(0xFF90A4AE);

  /// Resolve color based on brightness context.
  static Color resolve({
    required Brightness brightness,
    required Color dark,
    required Color light,
  }) {
    return brightness == Brightness.dark ? dark : light;
  }
}
