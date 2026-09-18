import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Виджет пульсирующего маяка выбранного маркера.
class FocusedMarkerRipple extends StatefulWidget {
  final Color color;
  final double size;

  const FocusedMarkerRipple({
    super.key,
    required this.color,
    this.size = 56.0,
  });

  @override
  State<FocusedMarkerRipple> createState() => _FocusedMarkerRippleState();
}

class _FocusedMarkerRippleState extends State<FocusedMarkerRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size * (0.4 + 0.6 * t),
                height: widget.size * (0.4 + 0.6 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity((1.0 - t).clamp(0.0, 1.0)),
                    width: 2.0 * (1.0 - t * 0.5),
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Высокопроизводительный 3D кластер меток на карте с неоновым свечением.
class PointCloudClusterWidget extends StatefulWidget {
  final int count;
  final Color accentColor;
  final VoidCallback onTap;

  const PointCloudClusterWidget({
    super.key,
    required this.count,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<PointCloudClusterWidget> createState() => _PointCloudClusterWidgetState();
}

class _PointCloudClusterWidgetState extends State<PointCloudClusterWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.count > 99 ? 52.0 : (widget.count > 9 ? 46.0 : 40.0);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = _pulseController.value;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.accentColor.withOpacity(0.9),
                    const Color(0xFF0F172A),
                  ],
                ),
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.7 + pulse * 0.3),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.3 + pulse * 0.3),
                    blurRadius: 12 + pulse * 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.count}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
