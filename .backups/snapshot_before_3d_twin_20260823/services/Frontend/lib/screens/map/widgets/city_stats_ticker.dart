import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/pulse_colors.dart';
import '../../../theme/theme_provider.dart';

/// Premium Liquid-Glass stats ticker for the map overlay.
///
/// Applies the following Pro Max design principles:
///   • BackdropFilter blur for true glass-morphism effect
///   • Staggered entry animation per stat item
///   • Inline sparkline indicator showing directional trend
///   • Gradient shimmer border (top glow) for premium depth
class CityStatsTicker extends StatefulWidget {
  final int total;
  final int resolved;
  final int active;

  /// Optional sparkline data points (last N snapshots).
  /// If null, shows a static directional arrow instead.
  final List<int>? totalHistory;
  final List<int>? resolvedHistory;
  final List<int>? activeHistory;

  const CityStatsTicker({
    super.key,
    required this.total,
    required this.resolved,
    required this.active,
    this.totalHistory,
    this.resolvedHistory,
    this.activeHistory,
  });

  @override
  State<CityStatsTicker> createState() => _CityStatsTickerState();
}

class _CityStatsTickerState extends State<CityStatsTicker>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        // Do not repeat in tests to avoid pumpAndSettle timeouts
      } else {
        _shimmerController.repeat();
      }
    } catch (_) {
      _shimmerController.repeat();
    }
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.6, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNight = ThemeProvider.instance.isDarkMode;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isNight ? 24 : 14,
              sigmaY: isNight ? 24 : 14,
            ),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isNight
                        ? PulseColors.surface.withOpacity(0.55)
                        : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isNight
                          ? PulseColors.primary.withOpacity(0.18)
                          : const Color(0x18000000),
                      width: 0.8,
                    ),
                    gradient: isNight
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              PulseColors.primary.withOpacity(0.06),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35],
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: isNight
                            ? Colors.black.withOpacity(0.25)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: isNight ? 18 : 12,
                        offset: Offset(0, isNight ? 6 : 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatItem(
                        icon: Icons.analytics_outlined,
                        label: 'Сегодня',
                        value: widget.total,
                        color: PulseColors.primary,
                        history: widget.totalHistory,
                        delay: 0,
                        controller: _controller,
                      ),
                      _divider(),
                      _StatItem(
                        icon: Icons.check_circle_outline,
                        label: 'Решено',
                        value: widget.resolved,
                        color: PulseColors.success,
                        history: widget.resolvedHistory,
                        delay: 1,
                        controller: _controller,
                      ),
                      _divider(),
                      _StatItem(
                        icon: Icons.timer_outlined,
                        label: 'Работа',
                        value: widget.active,
                        color: PulseColors.warning,
                        history: widget.activeHistory,
                        delay: 2,
                        controller: _controller,
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return _ShimmerOverlay(
                            progress: _shimmerController.value,
                            isNight: isNight,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    final isNight = ThemeProvider.instance.isDarkMode;
    return Container(
      width: 0.6,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: isNight
          ? PulseColors.textSecondary.withOpacity(0.2)
          : const Color(0x1A000000),
    );
  }
}

/// Individual stat item with staggered entry and optional sparkline.
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final List<int>? history;
  final int delay;
  final AnimationController controller;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.delay,
    required this.controller,
    this.history,
  });

  @override
  Widget build(BuildContext context) {
    // Stagger each item by 120ms
    final interval = Interval(
      (delay * 0.12).clamp(0.0, 0.6),
      ((delay * 0.12) + 0.5).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );
    final anim = CurvedAnimation(parent: controller, curve: interval);

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.3),
          end: Offset.zero,
        ).animate(anim),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ThemeProvider.instance.isDarkMode
                        ? PulseColors.textSecondary
                        : const Color(0xFF64748B),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Sparkline or trend arrow
                    if (history != null && history!.length >= 2)
                      _MiniSparkline(data: history!, color: color)
                    else
                      _trendArrow(color),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendArrow(Color c) {
    return Icon(
      Icons.trending_flat_rounded,
      size: 12,
      color: c.withOpacity(0.5),
    );
  }
}

/// Tiny sparkline graph rendered via CustomPainter.
class _MiniSparkline extends StatelessWidget {
  final List<int> data;
  final Color color;

  const _MiniSparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 12),
      painter: _SparklinePainter(data: data, color: color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> data;
  final Color color;

  const _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b).toDouble();
    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();
    final range = maxVal - minVal;
    if (range == 0) return;

    final stepX = size.width / (data.length - 1);
    final path = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    // Gradient fill below line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.18), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

class _ShimmerOverlay extends StatelessWidget {
  final double progress;
  final bool isNight;

  const _ShimmerOverlay({required this.progress, required this.isNight});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment(-2.0 + progress * 4.0, -2.0),
          end: Alignment(-1.0 + progress * 4.0, 2.0),
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(isNight ? 0.04 : 0.12),
            Colors.white.withOpacity(isNight ? 0.14 : 0.3),
            Colors.white.withOpacity(isNight ? 0.04 : 0.12),
            Colors.white.withOpacity(0.0),
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        ),
      ),
    );
  }
}
