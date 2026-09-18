// lib/widgets/pulse_loading.dart
//
// Унифицированные индикаторы загрузки с премиум-подходом:
//   • Полноэкранная загрузка → скелетоны (рек. 7), не голый спиннер.
//   • Inline/кнопочные индикаторы → компактный PulseLoadingSpinner.
//   • Никаких «сухих» CircularProgressIndicator по всему приложению.
//
// Дизайн-рекомендация 7 + 12: скелетоны вместо спиннеров + тишина в UI.
import 'package:flutter/material.dart';

import '../theme/pulse_colors.dart';
import 'skeleton_loaders.dart';

/// Компактный премиум-спиннер для inline-случаев (внутри кнопок, в строках).
/// Меньше и аккуратнее дефолтного CircularProgressIndicator.
class PulseLoadingSpinner extends StatelessWidget {
  const PulseLoadingSpinner({
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 2,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? PulseColors.primary,
        ),
        backgroundColor: (color ?? PulseColors.primary).withValues(alpha: 0.15),
      ),
    );
  }
}

/// Полноэкранный скелетон-загрузчик для списка жалоб.
/// Использовать вместо Center(CircularProgressIndicator) при загрузке списков.
class PulseComplaintLoading extends StatelessWidget {
  const PulseComplaintLoading({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      itemBuilder: (_, __) => const ComplaintCardSkeleton(),
    );
  }
}

/// Универсальная обёртка: если [loading] — показывает [skeleton],
/// иначе — [child]. Заменяет ручные if-else по всему коду.
class PulseLoadable extends StatelessWidget {
  const PulseLoadable({
    super.key,
    required this.loading,
    required this.child,
    required this.skeleton,
    this.error,
    this.onRetry,
  });

  final bool loading;
  final Widget child;
  final Widget skeleton;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return skeleton;
    return child;
  }
}
