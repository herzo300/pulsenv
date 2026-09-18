import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_core_splash_screen.dart';
import 'monitor_splash_screen.dart';
import 'oil_splash_screen.dart';
import 'blender_splash_screen.dart';
import 'cyber_premium_splash_screen.dart';

class SplashRouterScreen extends StatefulWidget {
  const SplashRouterScreen({super.key});

  @override
  State<SplashRouterScreen> createState() => _SplashRouterScreenState();
}

class _SplashRouterScreenState extends State<SplashRouterScreen> {
  String _theme = 'gravity';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final choices = ['cyber_premium', 'oil', 'ai_core'];
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
          _theme = 'cyber_premium';
          _loaded = true;
        });
      }
    }
  }

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
      case 'cyber_premium':
        return const CyberPremiumSplashScreen();
      case 'ai_core':
      case 'cyber':
        return const AiCoreSplashScreen();
      case 'monitor':
      case 'swamp':
        return const MonitorSplashScreen();
      case 'oil':
        return const OilSplashScreen();
      case 'gravity':
      case 'radar':
      default:
        return const BlenderSplashScreen();
    }
  }
}
