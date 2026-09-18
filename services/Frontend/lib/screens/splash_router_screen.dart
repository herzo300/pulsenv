import 'package:flutter/material.dart';
import '../core/app_router.dart';
import 'oil_splash_screen.dart';

/// Единый сплэш-экран приложения.
///
/// Раньше здесь был роутер между четырьмя вариантами сплэша
/// (oil / pulse / gravity / vipCyber). Альтернативные реализации
/// удалены как неиспользуемые — оставлен один фирменный OilSplashScreen
/// с 3D-логотипом. Класс сохранён, чтобы не трогать маршрутизацию.
class SplashRouterScreen extends StatelessWidget {
  final VoidCallback? onComplete;
  const SplashRouterScreen({super.key, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return OilSplashScreen(
      onComplete: onComplete ?? () {
        AppRouter.navigateAfterSplash(context);
      },
    );
  }
}
