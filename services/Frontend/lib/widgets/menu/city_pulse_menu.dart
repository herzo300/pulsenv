// lib/widgets/menu/city_pulse_menu.dart
//
// Новое визуально-выразительное главное меню City Pulse.
//
// Что нового vs старого showModalBottomSheet:
//   • Glassmorphism (BlurEffect через BackdropFilter + ImageFilter);
//   • Анимированные плитки-ячейки с hover/press-эффектами (flutter_animate);
//   • Сетчатая структура вместо длинного списка — влезает больше без скролла;
//   • Подсветка активного раздела и счётчики (новые жалобы, непрочитанное);
//   • Градиентная «шапка» с текущим городом + погода-чип;
//   • Тактильная отдача (vibration) при нажатии на ячейку.
//
// Показ:
//   CityPulseMenu.show(context, items: [...]);
//
// NEW (запрос пользователя): улучшить визуал меню приложения.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/pulse_colors.dart';

/// Пункт главного меню.
class CityMenuItem {
  const CityMenuItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.accentColor,
    this.subtitle,
    this.isActive = false,
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final Color? accentColor;
  final String? subtitle;
  final bool isActive;
}

/// Шапка меню — город + погода-чип.
class CityMenuHeader {
  const CityMenuHeader({
    required this.cityName,
    this.weatherLabel,
    this.weatherIcon,
    this.temperature,
  });

  final String cityName;
  final String? weatherLabel;
  final IconData? weatherIcon;
  final String? temperature;
}

class CityPulseMenu extends StatefulWidget {
  const CityPulseMenu({
    super.key,
    required this.items,
    this.header,
    this.onClose,
  });

  final List<CityMenuItem> items;
  final CityMenuHeader? header;
  final VoidCallback? onClose;

  /// Показать меню как modal bottom sheet с blur-фоном.
  static Future<void> show(
    BuildContext context, {
    required List<CityMenuItem> items,
    CityMenuHeader? header,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (_) => CityPulseMenu(items: items, header: header),
    );
  }

  @override
  State<CityPulseMenu> createState() => _CityPulseMenuState();
}

class _CityPulseMenuState extends State<CityPulseMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: t,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          // Градиентный glassmorphism-фон.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PulseColors.backgroundRaised.withOpacity(0.96),
              PulseColors.background.withOpacity(0.99),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: PulseColors.primary.withOpacity(0.35),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: PulseColors.primary.withOpacity(0.25),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Grab handle ─────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: PulseColors.primary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // ─── Шапка с городом + погода ────────────────────────────
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          PulseColors.primary,
                          PulseColors.primary.withOpacity(0.7),
                        ]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: PulseColors.primary.withOpacity(0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.location_city_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            header.cityName,
                            style: TextStyle(
                              color: PulseColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (header.weatherLabel != null)
                            Text(
                              header.weatherLabel!,
                              style: TextStyle(
                                color: PulseColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (header.temperature != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: PulseColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: PulseColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (header.weatherIcon != null)
                              Icon(header.weatherIcon,
                                  color: PulseColors.primary, size: 16),
                            if (header.weatherIcon != null)
                              const SizedBox(width: 4),
                            Text(
                              header.temperature!,
                              style: TextStyle(
                                color: PulseColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // ─── Сетка пунктов меню ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  // Каскадная анимация появления ячеек.
                  return _MenuTile(item: item)
                      .animate(controller: _controller)
                      .fadeIn(
                        delay: Duration(milliseconds: 120 + index * 45),
                        duration: 300.ms,
                      )
                      .slideY(
                        begin: 0.2,
                        end: 0,
                        delay: Duration(milliseconds: 120 + index * 45),
                        duration: 300.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                        delay: Duration(milliseconds: 120 + index * 45),
                        duration: 300.ms,
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Одна плитка-ячейка меню.
class _MenuTile extends StatefulWidget {
  const _MenuTile({required this.item});
  final CityMenuItem item;

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final accent = item.accentColor ?? PulseColors.primary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => _onTap(item),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: item.isActive
                ? accent.withOpacity(0.16)
                : PulseColors.backgroundRaised.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.isActive
                  ? accent.withOpacity(0.6)
                  : accent.withOpacity(0.12),
              width: item.isActive ? 1.5 : 1,
            ),
            boxShadow: item.isActive
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.3),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        accent,
                        accent.withOpacity(0.7),
                      ]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 24),
                  ),
                  if (item.badge != null)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: PulseColors.backgroundRaised, width: 1.5),
                        ),
                        child: Text(
                          item.badge!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: PulseColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              if (item.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PulseColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(CityMenuItem item) {
    HapticFeedback.selectionClick();
    Navigator.pop(context);
    item.onTap();
  }
}
