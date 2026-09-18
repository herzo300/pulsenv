// lib/widgets/skeleton_loaders.dart
//
// Готовые скелетоны-загрузчики на базе skeletonizer (уже в pubspec.yaml).
// Заменяют CircularProgressIndicator на UI-плейсхолдеры, повторяющие форму
// реального контента — это снижает perceived loading time.
//
// Использование:
//   if (loading) ComplaintCardSkeleton() else ComplaintCard(complaint: c);
//
// Item 6 (CityPulse_Improvements.md): UX/UI и Перформанс — shimmer эффекты.
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../theme/pulse_colors.dart';

/// Скелетон карточки жалобы для списка на карте / экране жалоб.
class ComplaintCardSkeleton extends StatelessWidget {
  const ComplaintCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Card(
        color: PulseColors.backgroundRaised,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Иконка категории
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PulseColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      color: PulseColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 180,
                      color: PulseColors.primary,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: 120,
                      color: PulseColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Список из [count] скелетонов карточек жалоб.
class ComplaintListSkeleton extends StatelessWidget {
  const ComplaintListSkeleton({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const ComplaintCardSkeleton()),
    );
  }
}

/// Скелетон карточки погоды (используется на новом WeatherScreen).
class WeatherCardSkeleton extends StatelessWidget {
  const WeatherCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: PulseColors.backgroundRaised,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PulseColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 28, width: 100, color: PulseColors.primary),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 160, color: PulseColors.primary),
                  const SizedBox(height: 6),
                  Container(height: 14, width: 120, color: PulseColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Скелетон карточки камеры.
class CameraCardSkeleton extends StatelessWidget {
  const CameraCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Card(
        color: PulseColors.backgroundRaised,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              color: PulseColors.primary,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 180, color: PulseColors.primary),
                  const SizedBox(height: 6),
                  Container(height: 12, width: 120, color: PulseColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Универсальный скелетон — принимает child (форму реального виджета).
class SkeletonContainer extends StatelessWidget {
  const SkeletonContainer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(enabled: enabled, child: child);
  }
}

/// Замена CircularProgressIndicator на скелетон, если задан [loading].
/// Иначе рендерит [child].
class SkeletonReplace extends StatelessWidget {
  const SkeletonReplace({
    super.key,
    required this.loading,
    required this.child,
    required this.placeholder,
  });

  final bool loading;
  final Widget child;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    if (loading) return placeholder;
    return child;
  }
}
