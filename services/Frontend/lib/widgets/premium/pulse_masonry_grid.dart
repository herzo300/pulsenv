// lib/widgets/premium/pulse_masonry_grid.dart
//
// Премиальная masonry-сетка (Pinterest-style) на базе waterfall_flow.
//
// Карточки разной высоты выстраиваются в «водопадные» колонки — идеально
// для фото-обложек находок/сигналов, где высота зависит от изображения.
// Заменяет обычный GridView, который «обрезает» карточки под одинаковую высоту.
//
// Премиум-визуал: лента выглядит как кураторская галерея.
import 'package:flutter/material.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

/// Masonry-сетка с карточками переменной высоты.
class PulseMasonryGrid<T> extends StatelessWidget {
  const PulseMasonryGrid({
    super.key,
    required this.items,
    required this.builder,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
  });

  final List<T> items;

  /// Билдер карточки. Возвращает виджет с ЕСТЕСТВЕННОЙ высотой
  /// (сетка измерит её сама).
  final Widget Function(BuildContext context, T item, int index) builder;

  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return WaterfallFlow.builder(
      controller: controller,
      padding: padding ?? const EdgeInsets.all(12),
      physics: physics,
      shrinkWrap: shrinkWrap,
      gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          builder(context, items[index], index),
    );
  }
}

/// Sliver-версия masonry-сетки для CustomScrollView (с другими slivers).
class PulseMasonrySliver<T> extends StatelessWidget {
  const PulseMasonrySliver({
    super.key,
    required this.items,
    required this.builder,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) builder;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  @override
  Widget build(BuildContext context) {
    return SliverWaterfallFlow(
      gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => builder(context, items[index], index),
        childCount: items.length,
      ),
    );
  }
}
