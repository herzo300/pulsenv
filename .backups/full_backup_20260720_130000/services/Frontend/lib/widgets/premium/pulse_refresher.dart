// lib/widgets/premium/pulse_refresher.dart
//
// Унифицированный pull-to-refresh + infinite scroll на базе smart_refresher.
//
// Заменяет стандартный RefreshIndicator на премиум-индикаторы с поддержкой:
//   • Кастомные индикаторы (MaterialClassic, Bezier, WaterDrop, Custom).
//   • Загрузка следующей страницы при прокрутке вниз (infinite scroll).
//   • Состояния: idle/loading/refreshing/noMore/failed.
//
// Премиум-функционал: плавная подгрузка лент сигналов/находок без ручной
// пагинации в каждом экране.
import 'package:flutter/material.dart';
import 'package:smart_refresher/smart_refresher.dart';

import '../../theme/pulse_colors.dart';

/// Тип индикатора pull-to-refresh.
enum PulseRefreshStyle {
  /// Классический Material-индикатор.
  material,

  /// Bezier-кривая (плавная, премиум).
  bezier,

  /// Капля воды (WaterDrop).
  waterDrop,

  /// Кастомный (передаётся через builder).
  custom,
}

/// Обёртка над списком с pull-to-refresh и опциональным infinite scroll.
class PulseRefresher extends StatefulWidget {
  const PulseRefresher({
    super.key,
    required this.child,
    required this.onRefresh,
    this.onLoading,
    this.style = PulseRefreshStyle.bezier,
    this.enablePullUp = false,
    this.noMoreText = 'Больше нет данных',
    this.controller,
  });

  final Widget child;

  /// Колбэк pull-to-refresh.
  final RefreshCallback onRefresh;

  /// Колбэк загрузки следующей страницы (для infinite scroll).
  /// null → pull-up отключён.
  final Future<void> Function()? onLoading;

  final PulseRefreshStyle style;

  /// Включить загрузку при прокрутке вниз (infinite scroll).
  final bool enablePullUp;

  final String noMoreText;

  /// Внешний контроллер (если нужен доступ из родителя).
  final RefreshController? controller;

  @override
  State<PulseRefresher> createState() => _PulseRefresherState();
}

class _PulseRefresherState extends State<PulseRefresher> {
  late RefreshController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? RefreshController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    try {
      await widget.onRefresh();
      _controller.refreshCompleted();
    } catch (e) {
      _controller.refreshFailed();
    }
  }

  Future<void> _onLoading() async {
    if (widget.onLoading == null) {
      _controller.loadComplete();
      return;
    }
    try {
      await widget.onLoading!();
      // Родитель сам вызовет loadComplete/loadNoData через контроллер,
      // но по умолчанию считаем что страница загружена.
      _controller.loadComplete();
    } catch (e) {
      _controller.loadFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshConfiguration(
      headerBuilder: () => _buildHeader(),
      footerBuilder: () => _buildFooter(),
      headerTriggerDistance: 80,
      child: SmartRefresher(
        controller: _controller,
        onRefresh: _onRefresh,
        onLoading: widget.enablePullUp ? _onLoading : null,
        enablePullDown: true,
        enablePullUp: widget.enablePullUp,
        header: _buildHeader(),
        footer: widget.enablePullUp ? _buildFooter() : null,
        child: widget.child,
      ),
    );
  }

  Widget _buildHeader() {
    switch (widget.style) {
      case PulseRefreshStyle.material:
        return const ClassicHeader(
          idleText: 'Потяните вниз',
          releaseText: 'Отпустите для обновления',
          refreshingText: 'Обновление…',
          completeText: 'Готово',
          failedText: 'Ошибка',
        );
      case PulseRefreshStyle.bezier:
        // Bezier-индикатор (плавная кривая).
        return BezierHeader(
          child: Center(
            child: CircularProgressIndicator(
              color: PulseColors.primary,
              strokeWidth: 2.5,
            ),
          ),
        );
      case PulseRefreshStyle.waterDrop:
        return WaterDropHeader(
          waterDropColor: PulseColors.primary,
        );
      case PulseRefreshStyle.custom:
        return const ClassicHeader();
    }
  }

  Widget _buildFooter() {
    return ClassicFooter(
      idleText: 'Потяните вверх для ещё',
      loadingText: 'Загрузка…',
      noDataText: widget.noMoreText,
      failedText: 'Ошибка загрузки',
      canLoadingText: 'Отпустите для загрузки',
      noMoreIcon: Icon(Icons.check_circle_outline,
          color: PulseColors.textSecondary, size: 18),
    );
  }
}
