import 'package:flutter/material.dart';

abstract final class PulseColors {
  // ─── Dark mode (default) ───
  static const Color background = Color(0xFF020617);
  static const Color backgroundRaised = Color(0xFF08111F);
  static const Color surface = Color(0xFF0C1628);
  static const Color surfaceSoft = Color(0xFF112036);
  static const Color surfaceElevated = Color(0xFF16263D);
  static const Color surfaceGlass = Color(0xCC111C31);
  static const Color surfaceLight = Color(0xFFF2FBFF);
  static const Color textPrimary = Color(0xFFE6FAFF);
  static const Color textSecondary = Color(0xFF8EAFC2);
  static const Color textTertiary = Color(0xFF66849A);

  // ─── Light mode variants ───
  static const Color lightBackground = Color(0xFFF5FAFF);
  static const Color lightBackgroundRaised = Color(0xFFE8F2FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSoft = Color(0xFFF0F6FC);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceGlass = Color(0xCCFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0A2540);
  static const Color lightTextSecondary = Color(0xFF4A6B8A);
  static const Color lightTextTertiary = Color(0xFF7A96B2);
  static const Color lightBorder = Color(0x330EA5C7);
  static const Color lightBorderStrong = Color(0x660EA5C7);

  // ─── Shared accents ───
  static const Color primary = Color(0xFF00E5FF);
  static const Color primarySoft = Color(0xFF7DF2FF);
  static const Color primaryDeep = Color(0xFF0EA5C7);
  static const Color accentViolet = Color(0xFF7C4DFF);
  static const Color accentGold = Color(0xFFFFC857);
  static const Color negative = Color(0xFFFF3D00);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFC857);
  static const Color neutral = Color(0xFF90A4AE);
  static const Color border = Color(0x223FD8F8);
  static const Color borderStrong = Color(0x443FD8F8);

  /// Resolve color based on brightness context.
  static Color resolve({
    required Brightness brightness,
    required Color dark,
    required Color light,
  }) {
    return brightness == Brightness.dark ? dark : light;
  }
}
