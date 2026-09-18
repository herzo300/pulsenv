import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/pulse_colors.dart';
import 'app_ui.dart';

/// -------------------------------------------------------------
/// 1. AI RADAR EFFECT (Для наложения на карту)
/// -------------------------------------------------------------
class PulseRadarRadar extends StatefulWidget {
  final double radius;
  final Color? color;

  PulseRadarRadar({
    super.key,
    this.radius = 150.0,
    this.color,
  });

  @override
  State<PulseRadarRadar> createState() => _PulseRadarRadarState();
}

class _PulseRadarRadarState extends State<PulseRadarRadar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _activeColor => widget.color ?? PulseColors.primary;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Пульсирующие круги
              ...List.generate(3, (index) {
                double progress = (_controller.value + (index / 3)) % 1.0;
                return Container(
                  width: widget.radius * 2 * progress,
                  height: widget.radius * 2 * progress,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _activeColor.withOpacity(1.0 - progress),
                      width: 2.0,
                    ),
                  ),
                );
              }),
              // Вращающийся луч сканера
              Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: Container(
                  width: widget.radius * 2,
                  height: widget.radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      center: Alignment.center,
                      startAngle: 0.0,
                      endAngle: math.pi / 4,
                      colors: [
                        _activeColor.withOpacity(0.5),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
              // Центр радара
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _activeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _activeColor, blurRadius: 10, spreadRadius: 2),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// -------------------------------------------------------------
/// 3. VLM ANALYSIS LOADER (WOW-эффект при подаче жалобы)
/// -------------------------------------------------------------
class VlmAnalysisOverlay extends StatelessWidget {
  final bool isAnalyzing;
  final String statusText;

  const VlmAnalysisOverlay({
    super.key,
    required this.isAnalyzing,
    this.statusText = "ИИ ГЕМИНИ АНАЛИЗИРУЕТ ФОТО...",
  });

  @override
  Widget build(BuildContext context) {
    if (!isAnalyzing) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseRadarRadar(radius: 80, color: PulseColors.primary),
            const SizedBox(height: 40),
            Text(
              statusText,
              style: AppTextStyles.overline.copyWith(color: PulseColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              "ОПРЕДЕЛЕНИЕ КАТЕГОРИИ И ОПИСАНИЕ ОБЪЕКТА",
              style: AppTextStyles.overline.copyWith(letterSpacing: 0),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: PulseColors.surfaceSoft,
                valueColor: AlwaysStoppedAnimation<Color>(PulseColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------
/// 4. ANIMATED MAP MARKER (WOW-эффект для событий на карте города)
/// -------------------------------------------------------------
class AnimatedPulseMarker extends StatefulWidget {
  final Color color;
  final double size;
  final IconData icon;

  const AnimatedPulseMarker({
    super.key,
    this.color = PulseColors.negative,
    this.size = 40.0,
    this.icon = Icons.local_fire_department_rounded,
  });

  @override
  State<AnimatedPulseMarker> createState() => _AnimatedPulseMarkerState();
}

class _AnimatedPulseMarkerState extends State<AnimatedPulseMarker> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.animateTo(0.78, duration: const Duration(milliseconds: 80));
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.forward();
  }

  void _onTapCancel() {
    _scaleController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Внешнее "дыхание" (свечение)
                  Container(
                    width: widget.size * (1.2 + 0.3 * _controller.value),
                    height: widget.size * (1.2 + 0.3 * _controller.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.2 - 0.1 * _controller.value),
                    ),
                  ),
                  // Ядро маркера
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PulseColors.surfaceElevated,
                      border: Border.all(color: widget.color, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.5 * _controller.value),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: widget.size * 0.6,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------
/// 5. CYBERPUNK GLITCH EFFECT (Для текстовых блоков)
/// -------------------------------------------------------------
class GlitchEffect extends StatefulWidget {
  final Widget child;
  final bool active;

  const GlitchEffect({super.key, required this.child, this.active = true});

  @override
  State<GlitchEffect> createState() => _GlitchEffectState();
}

class _GlitchEffectState extends State<GlitchEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GlitchEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Trigger glitch frame randomly (e.g. 15% of frames)
          final isGlitching = _random.nextDouble() < 0.15;
          if (!isGlitching) return widget.child;

          final offsetX = (_random.nextDouble() - 0.5) * 6.0;
          final offsetY = (_random.nextDouble() - 0.5) * 2.0;

          return Stack(
            children: [
              // Red tint shift
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(-offsetX, -offsetY),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.red.withOpacity(0.35),
                      BlendMode.srcATop,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
              // Blue tint shift
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(offsetX * 1.5, offsetY * 1.5),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.blue.withOpacity(0.35),
                      BlendMode.srcATop,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
              // Original child shifted
              Transform.translate(
                offset: Offset(offsetX, offsetY),
                child: widget.child,
              ),
            ],
          );
        },
      ),
    );
  }
}
