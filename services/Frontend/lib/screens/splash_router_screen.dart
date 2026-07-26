import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_router.dart';
import 'pulse_splash_screen.dart';
import 'oil_splash_screen.dart';
import 'gravity_splash_screen.dart';
import 'cyber_premium_splash_screen.dart';

enum SplashTheme { pulse, oil, gravity, vipCyber }

class SplashRouterScreen extends StatefulWidget {
  final SplashTheme? initialTheme;
  final VoidCallback? onComplete;
  const SplashRouterScreen({super.key, this.initialTheme, this.onComplete});

  @override
  State<SplashRouterScreen> createState() => _SplashRouterScreenState();
}

class _SplashRouterScreenState extends State<SplashRouterScreen> {
  SplashTheme _theme = SplashTheme.pulse;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    if (widget.initialTheme != null) {
      if (mounted) {
        setState(() {
          _theme = widget.initialTheme!;
          _loaded = true;
        });
      }
      return;
    }
    
    try {
      final choices = [SplashTheme.pulse, SplashTheme.oil, SplashTheme.gravity, SplashTheme.vipCyber];
      final selected = choices[math.Random().nextInt(choices.length)];
      if (mounted) {
        setState(() {
          _theme = selected;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _theme = SplashTheme.pulse;
          _loaded = true;
        });
      }
    }
  }

  /// Effective onComplete: use caller's callback or default to AppRouter navigation.
  VoidCallback get _effectiveOnComplete =>
      widget.onComplete ??
      () {
        if (mounted) AppRouter.navigateAfterSplash(context);
      };

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF01040C),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    switch (_theme) {
      case SplashTheme.vipCyber:
        return CyberPremiumSplashScreen(onComplete: _effectiveOnComplete);
      case SplashTheme.oil:
        return OilSplashScreen(onComplete: _effectiveOnComplete);
      case SplashTheme.gravity:
        return GravitySplashScreen(onComplete: _effectiveOnComplete);
      case SplashTheme.pulse:
      default:
        return PulseSplashScreen(onComplete: _effectiveOnComplete);
    }
  }
}
