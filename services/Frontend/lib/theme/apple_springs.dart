// services/Frontend/lib/theme/apple_springs.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Apple Design System Physics & Glass Utilities for City Pulse
class AppleSprings {
  /// Critically Damped Spring (Damping ratio = 1.0)
  /// Ideal for modal dialogs, drawer transitions, and clean UI state changes
  static const SpringDescription responsiveDamped = SpringDescription(
    mass: 1.0,
    stiffness: 220.0,
    damping: 29.66,
  );

  /// Momentum Spring with Subtle Bounce (Damping ratio ~ 0.75)
  /// Ideal for flicked cards, swipe actions, and physical gesture release
  static const SpringDescription momentumBounce = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 19.0,
  );

  /// Snappy Touch Spring
  /// Ideal for instant button scale feedback and tab transitions
  static const SpringDescription snappyTouch = SpringDescription(
    mass: 0.8,
    stiffness: 320.0,
    damping: 24.5,
  );
}

/// Zero-Latency Touch Feedback Wrapper (Apple Design Principle #1)
/// Responds instantly on pointer down (0ms delay) with subtle scale & haptic feedback.
class AppleTouchFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const AppleTouchFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<AppleTouchFeedback> createState() => _AppleTouchFeedbackState();
}

class _AppleTouchFeedbackState extends State<AppleTouchFeedback> {
  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent event) {
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? widget.pressedScale : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/// VisionOS Ultra-Glassmorphism Material Panel (Apple Design Principle #3/4)
/// Features multi-layered BackdropFilter blur, subtle gradient borders, and soft depth shadows.
class AppleGlassPanel extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;

  const AppleGlassPanel({
    super.key,
    required this.child,
    this.blurSigma = 24.0,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(14.0),
    this.backgroundColor = const Color(0x22121824),
    this.borderColor = const Color(0x33FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x25000000),
                blurRadius: 20,
                spreadRadius: 2,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Interactive Swipe-to-Action Card with Spring Resistance & 3D Depth Stack (Apple Principles #12, #13)
class AppleSwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final double threshold;

  const AppleSwipeableCard({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.threshold = 100.0,
  });

  @override
  State<AppleSwipeableCard> createState() => _AppleSwipeableCardState();
}

class _AppleSwipeableCardState extends State<AppleSwipeableCard> {
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final absOffset = _dragOffset.abs();
    final shadowElevation = _isDragging ? (8.0 + (absOffset * 0.12).clamp(0.0, 16.0)) : 4.0;
    final rotationAngle = (_dragOffset / 1000.0).clamp(-0.15, 0.15);

    return GestureDetector(
      onHorizontalDragStart: (_) {
        setState(() => _isDragging = true);
        HapticFeedback.selectionClick();
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          // Rubber-band physics spring resistance
          final resistance = 1.0 / (1.0 + (absOffset * 0.004));
          _dragOffset += details.delta.dx * resistance;
        });
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dx;
        setState(() => _isDragging = false);

        if (_dragOffset > widget.threshold || velocity > 400) {
          HapticFeedback.mediumImpact();
          widget.onSwipeRight?.call();
        } else if (_dragOffset < -widget.threshold || velocity < -400) {
          HapticFeedback.mediumImpact();
          widget.onSwipeLeft?.call();
        }

        // Spring snap back to center
        setState(() => _dragOffset = 0.0);
      },
      child: AnimatedContainer(
        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
        transform: Matrix4.identity()
          ..translate(_dragOffset, 0.0)
          ..rotateZ(rotationAngle),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDragging ? 0.35 : 0.18),
              blurRadius: shadowElevation * 2,
              spreadRadius: _isDragging ? 2 : 0,
              offset: Offset(0, shadowElevation),
            ),
            if (_isDragging)
              BoxShadow(
                color: (_dragOffset > 0 ? Colors.cyanAccent : Colors.amberAccent).withOpacity(0.2),
                blurRadius: 16,
                spreadRadius: 1,
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Spatial Anchor Origin Dialog Route (Apple Principle #2, #7)
/// Grows out directly from a specified spatial origin point on screen
class AppleAnchorOriginRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Offset origin;

  AppleAnchorOriginRoute({
    required this.page,
    required this.origin,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            );
            final screenSize = MediaQuery.of(context).size;
            final alignmentX = ((origin.dx / screenSize.width) * 2.0) - 1.0;
            final alignmentY = ((origin.dy / screenSize.height) * 2.0) - 1.0;

            return ScaleTransition(
              alignment: Alignment(alignmentX.clamp(-1.0, 1.0), alignmentY.clamp(-1.0, 1.0)),
              scale: Tween<double>(begin: 0.1, end: 1.0).animate(curved),
              child: FadeTransition(
                opacity: curved,
                child: child,
              ),
            );
          },
        );
}
