import 'package:flutter/material.dart';
import '../core/app_router.dart';
import 'oil_splash_screen.dart';

enum SplashTheme { oil, pulse, gravity, vipCyber }

/// Единый сплэш-экран приложения «Самотлор Gold»
class SplashRouterScreen extends StatelessWidget {
  final SplashTheme? initialTheme;
  final VoidCallback? onComplete;
  const SplashRouterScreen({super.key, this.initialTheme, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return OilSplashScreen(
      onComplete: onComplete ?? () {
        AppRouter.navigateAfterSplash(context);
      },
    );
  }
}
