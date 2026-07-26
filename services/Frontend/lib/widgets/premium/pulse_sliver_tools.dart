// lib/widgets/premium/pulse_sliver_tools.dart
//
// Премиальные sliver-эффекты: parallax-фоны и sticky-заголовки.
//
// На базе sliver_tools — расширяет MultiSliver, SliverPinnedHeader,
// SliverCrossAxisPinnedHeader для композиции нескольких slivers.
//
// Применение: профили, ленты сигналов, инфографика — длинные списки с
// «прилипающими» секциями и параллакс-картинками при скролле.
//
// Премиум-визуал: глубина и кинематографичность длинных экранов.
import 'package:flutter/material.dart';
import 'package:sliver_tools/sliver_tools.dart';

// Примечание: PulseParallaxHeader (через Flow-делегат) временно убран —
// API FlowPaintingContext.getChild нестабилен между версиями Flutter.
// Parallax можно реализовать через ScrollController + AnimatedBuilder
// при необходимости. PulseStickyHeader + PulseSliverSection работают.

/// Sticky/pinned заголовок секции — «прилипает» к верху при скролле.
///
/// Использование в CustomScrollView:
///   PulseStickyHeader(title: 'Открытые сигналы', child: ...sliver...)
/// или через MultiSliver для композиции.
class PulseStickyHeader extends StatelessWidget {
  const PulseStickyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.color,
    this.textColor,
  });

  final String title;
  final String? subtitle;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return SliverPinnedHeader(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: (textColor ?? Theme.of(context).colorScheme.onSurface)
                        .withOpacity(0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Композитный sliver: несколько slivers в одном через MultiSliver.
/// Удобно для секций экрана с parallax-header + sticky + content.
class PulseSliverSection extends StatelessWidget {
  const PulseSliverSection({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return MultiSliver(
      children: children,
    );
  }
}
