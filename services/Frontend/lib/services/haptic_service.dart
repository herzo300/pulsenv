import 'package:flutter/services.dart';

/// Centralized 3D Haptic Engine service for tactile feedback.
/// Provides graded haptic responses (Apple Taptic Engine standard).
class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  bool isEnabled = true;

  /// Selection click feedback for pickers, sliders, tabs
  Future<void> selection() async {
    if (!isEnabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Light impact for subtler interactions (glass cards, chip toggles)
  Future<void> light() async {
    if (!isEnabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium impact for standard button presses, drawer items
  Future<void> medium() async {
    if (!isEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact for critical actions, emergency/SOS buttons
  Future<void> heavy() async {
    if (!isEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Success haptic pattern (two crisp ticks)
  Future<void> success() async {
    if (!isEnabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
  }

  /// Warning haptic pattern (rapid pulse)
  Future<void> warning() async {
    if (!isEnabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// Error haptic alert (heavy vibration sequence)
  Future<void> error() async {
    if (!isEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  /// Radar pulse haptic when scanning area
  Future<void> radarPulse() async {
    if (!isEnabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Meter OCR captured pulse (confirmation)
  Future<void> meterCaptured() async {
    if (!isEnabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  /// Standard alert vibration
  Future<void> alert() async {
    if (!isEnabled) return;
    await HapticFeedback.vibrate();
  }
}
