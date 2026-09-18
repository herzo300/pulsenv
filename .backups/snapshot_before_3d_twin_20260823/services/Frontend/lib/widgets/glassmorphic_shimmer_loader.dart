import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Premium Glassmorphic Shimmer Loader with animated reflection glare sweep.
/// Blends BackdropFilter blur with an animated diagonal white highlight.
class GlassmorphicShimmerLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const GlassmorphicShimmerLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16.0,
  });

  @override
  State<GlassmorphicShimmerLoader> createState() => _GlassmorphicShimmerLoaderState();
}

class _GlassmorphicShimmerLoaderState extends State<GlassmorphicShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.0,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FractionallySizedBox(
                      widthFactor: 2.0,
                      alignment: Alignment(
                        -1.5 + (_controller.value * 3.0),
                        0.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.09),
                              Colors.white.withOpacity(0.0),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
