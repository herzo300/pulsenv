import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget that renders a 3D weather object (PNG with alpha)
/// with glassmorphism, levitation, and subtle rotation.
class Weather3DObject extends StatefulWidget {
  final String assetPath;
  final double size;
  final bool animate;
  final double blurAmount;
  
  const Weather3DObject({
    super.key,
    required this.assetPath,
    this.size = 200,
    this.animate = true,
    this.blurAmount = 4.0,
  });

  @override
  State<Weather3DObject> createState() => _Weather3DObjectState();
}

class _Weather3DObjectState extends State<Weather3DObject> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Subtle levitation (up and down)
          final yOffset = math.sin(_controller.value * math.pi) * 15.0;
          // Subtle rotation (wobble)
          final rotation = math.sin(_controller.value * math.pi * 0.5) * 0.05;

          return Transform.translate(
            offset: Offset(0, yOffset),
            child: Transform.rotate(
              angle: rotation,
              child: child,
            ),
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The actual 3D asset
            Image.asset(
              widget.assetPath,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
