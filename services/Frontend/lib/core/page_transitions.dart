import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Page transition utilities for GoRouter.
/// Provides consistent, native-feeling animations across all screens.
final class AppPageTransitions {
  AppPageTransitions._();

  /// Fade transition — used for splash / lock screens
  static CustomTransitionPage fade({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      transitionDuration: const Duration(milliseconds: 300),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
    );
  }

  /// Slide from bottom (upward) — used for modal sheets, forms
  static CustomTransitionPage slideUp({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      transitionDuration: const Duration(milliseconds: 350),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        );
      },
    );
  }

  /// Slide from right (forward navigation) — drill-down
  static CustomTransitionPage slideRight({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      transitionDuration: const Duration(milliseconds: 300),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        );
      },
    );
  }

  /// Slide from bottom (map screen default)
  static CustomTransitionPage slideBottom({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      transitionDuration: const Duration(milliseconds: 400),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        );
      },
    );
  }

  /// Immersive portal scale-fade with circular expansion transition
  static CustomTransitionPage portalExpansion({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      transitionDuration: const Duration(milliseconds: 650),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleCurve = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
        );
        final fadeCurve = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.7, curve: Curves.easeInCubic),
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(scaleCurve),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(fadeCurve),
            child: child,
          ),
        );
      },
    );
  }

  /// Shared-element Hero transition wrapper
  static Widget heroWrapper({
    required String tag,
    required Widget child,
  }) {
    return Hero(
      tag: tag,
      child: child,
    );
  }
}
