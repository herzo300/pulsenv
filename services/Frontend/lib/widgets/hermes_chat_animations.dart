import 'package:flutter/material.dart';

/// Three-dot typing indicator that shows when Hermes AI is "thinking".
/// Each dot pulses with a staggered delay for a natural feel.
class HermesTypingIndicator extends StatefulWidget {
  final Color dotColor;
  final double dotSize;

  const HermesTypingIndicator({
    super.key,
    this.dotColor = const Color(0xFF00E5FF),
    this.dotSize = 8.0,
  });

  @override
  State<HermesTypingIndicator> createState() => _HermesTypingIndicatorState();
}

class _HermesTypingIndicatorState extends State<HermesTypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnimations;
  late final List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: 200 * i), () {
        if (mounted) {
          controller.repeat(reverse: true);
        }
      });
      return controller;
    });

    _scaleAnimations = _controllers.map((c) {
      return Tween<double>(begin: 0.6, end: 1.2).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    _opacityAnimations = _controllers.map((c) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      margin: const EdgeInsets.only(left: 12, right: 60, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.7),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            color: widget.dotColor.withOpacity(0.5),
            size: 14,
          ),
          const SizedBox(width: 10),
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _controllers[i],
              builder: (context, _) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.scale(
                    scale: _scaleAnimations[i].value,
                    child: Opacity(
                      opacity: _opacityAnimations[i].value,
                      child: Container(
                        width: widget.dotSize,
                        height: widget.dotSize,
                        decoration: BoxDecoration(
                          color: widget.dotColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.dotColor.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          const SizedBox(width: 8),
          Text(
            'Гермес думает...',
            style: TextStyle(
              color: widget.dotColor.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrapper widget that adds entry animation to chat message bubbles.
/// Applies slide-up + fade-in + subtle scale for a natural feel.
class AnimatedBubbleEntry extends StatelessWidget {
  final Widget child;
  final int index;

  const AnimatedBubbleEntry({
    super.key,
    required this.child,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.95 + 0.05 * value,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Animated live status indicator — green pulsing dot for online cameras.
class LiveStatusDot extends StatefulWidget {
  final bool isOnline;
  final double size;

  const LiveStatusDot({
    super.key,
    this.isOnline = true,
    this.size = 10,
  });

  @override
  State<LiveStatusDot> createState() => _LiveStatusDotState();
}

class _LiveStatusDotState extends State<LiveStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.isOnline) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(LiveStatusDot old) {
    super.didUpdateWidget(old);
    if (widget.isOnline && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isOnline && _controller.isAnimating) {
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
    final color = widget.isOnline
        ? const Color(0xFF00E676)
        : const Color(0xFF757575);

    if (!widget.isOnline) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = 1.0 + 0.3 * _controller.value;
        final opacity = 1.0 - 0.6 * _controller.value;
        return SizedBox(
          width: widget.size * 2.5,
          height: widget.size * 2.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: widget.size * scale * 1.8,
                height: widget.size * scale * 1.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(opacity * 0.4),
                    width: 1.5,
                  ),
                ),
              ),
              // Core dot
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
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
