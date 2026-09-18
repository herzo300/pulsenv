// lib/widgets/aura_theme_picker.dart
//
// Премиальный пикер тем AuraLiving — галерея с визуальными превью.
//
// Каждая тема показана как мини-карточка с живым превью её палитры
// (градиент-образец). При выборе — мгновенное применение через
// AuraThemeService (фон перестраивается, выбор персистентный).
//
// Запуск: AuraThemePicker.show(context)
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/living/aura_theme_catalog.dart';
import '../core/living/aura_theme_service.dart';
import '../theme/pulse_colors.dart';
import '../theme/pulse_typography.dart';
import '../utils/pulse_haptics.dart';

class AuraThemePicker {
  AuraThemePicker._();

  /// Показать пикер как modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulseColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _AuraThemePickerSheet(),
    );
  }
}

class _AuraThemePickerSheet extends StatefulWidget {
  const _AuraThemePickerSheet();

  @override
  State<_AuraThemePickerSheet> createState() => _AuraThemePickerSheetState();
}

class _AuraThemePickerSheetState extends State<_AuraThemePickerSheet> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = AuraThemeService.instance.theme.id;
  }

  Future<void> _select(AuraTheme theme) async {
    PulseHaptics.tap();
    setState(() => _selectedId = theme.id);
    await AuraThemeService.instance.selectTheme(theme.id);
    PulseHaptics.success();
  }

  @override
  Widget build(BuildContext context) {
    final current = AuraThemeService.instance.theme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: PulseColors.primary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.palette_rounded,
                    color: PulseColors.primary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Тема фона', style: PulseTypography.titleLarge),
                      Text(
                        '${AuraThemeCatalog.all.length} премиальных образа',
                        style: PulseTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: PulseColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Сетка тем
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.85,
              ),
              itemCount: AuraThemeCatalog.all.length,
              itemBuilder: (context, index) {
                final theme = AuraThemeCatalog.all[index];
                final selected = theme.id == _selectedId;
                return _ThemeCard(
                  theme: theme,
                  selected: selected,
                  onTap: () => _select(theme),
                )
                    .animate()
                    .fadeIn(delay: (index * 60).ms, duration: 300.ms)
                    .slideY(
                        begin: 0.15,
                        end: 0,
                        delay: (index * 60).ms,
                        duration: 300.ms);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка одной темы с живым превью палитры.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final AuraTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.previewColor
                : PulseColors.primary.withOpacity(0.15),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.previewColor.withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── Живое превью палитры ──────────────────────────────
              _PalettePreview(theme: theme),
              // Затемнение для читаемости
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              // ─── Инфо снизу ─────────────────────────────────────────
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(theme.icon, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            theme.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      theme.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // ─── Галочка выбора ────────────────────────────────────
              if (selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.previewColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.previewColor.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Живое превью палитры темы — анимированный градиент.
/// Даёт визуальное представление характера темы до выбора.
class _PalettePreview extends StatefulWidget {
  const _PalettePreview({required this.theme});
  final AuraTheme theme;

  @override
  State<_PalettePreview> createState() => _PalettePreviewState();
}

class _PalettePreviewState extends State<_PalettePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final displayColors = p.length >= 2
        ? p
        : [widget.theme.previewColor, const Color(0xFF1E293B)];

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + t * 0.5, -1.0),
              end: Alignment(1.0 - t * 0.5, 1.0),
              colors: [
                displayColors[0],
                if (displayColors.length > 2) displayColors[2] else displayColors.last,
                displayColors.last,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _RadialGlowPainter(
                  center: Alignment(0.4 * math.sin(t * math.pi * 2), 0.4 * math.cos(t * math.pi * 2)),
                  color: widget.theme.previewColor.withOpacity(0.6),
                  radius: 0.7,
                  intensity: 0.8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Радиальное свечение (софт-блик).
class _RadialGlowPainter extends CustomPainter {
  const _RadialGlowPainter({
    required this.center,
    required this.color,
    required this.radius,
    required this.intensity,
  });

  final Alignment center;
  final Color color;
  final double radius;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final offset = center.alongSize(size);
    final r = size.longestSide * radius;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(center.x, center.y),
        radius: 1.0,
        colors: [
          color.withOpacity(0.85 * intensity),
          color.withOpacity(0.3 * intensity),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(offset, r, paint);
  }

  @override
  bool shouldRepaint(covariant _RadialGlowPainter old) =>
      old.center != center ||
      old.radius != radius ||
      old.color != color ||
      old.intensity != intensity;
}

/// Точечные искры (звёзды/частицы) — детерминированные по seed темы.
class _SparklePainter extends CustomPainter {
  const _SparklePainter({
    required this.color,
    required this.density,
    required this.seed,
    required this.t,
  });

  final Color color;
  final double density;
  final int seed;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final count = (30 * density).round();
    final rng = _SeededRng(seed);
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final baseSize = 0.5 + rng.nextDouble() * 1.8;
      // Мерцание: каждая искра пульсирует со своей фазой.
      final twinkle = 0.4 + 0.6 * ((math.sin((t + i * 0.3) * math.pi * 2) + 1) / 2);
      paint.color = color.withOpacity(twinkle);
      canvas.drawCircle(Offset(x, y), baseSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}

/// Детерминированный ГПСЧ для стабильных искр по seed темы.
class _SeededRng {
  _SeededRng(int seed) : _state = seed.abs() + 1;
  int _state;
  double nextDouble() {
    // xorshift32
    _state ^= _state << 13;
    _state ^= _state >> 17;
    _state ^= _state << 5;
    return (_state.abs() % 10000) / 10000.0;
  }
}
