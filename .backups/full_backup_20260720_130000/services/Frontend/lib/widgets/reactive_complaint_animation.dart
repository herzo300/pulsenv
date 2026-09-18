import 'package:flutter/material.dart';

enum ComplaintStatus { idle, submitting, success, error }

class ReactiveComplaintAnimation extends StatefulWidget {
  final ComplaintStatus status;
  final Widget child;

  const ReactiveComplaintAnimation({
    super.key,
    required this.status,
    required this.child,
  });

  @override
  State<ReactiveComplaintAnimation> createState() => _ReactiveComplaintAnimationState();
}

class _ReactiveComplaintAnimationState extends State<ReactiveComplaintAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant ReactiveComplaintAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      if (widget.status == ComplaintStatus.submitting) {
        _controller.repeat(reverse: true);
      } else if (widget.status == ComplaintStatus.success) {
        _controller.stop();
        _controller.forward(from: 0.0);
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (widget.status == ComplaintStatus.submitting)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)),
                  ),
                ),
              ),
            ),
          if (widget.status == ComplaintStatus.success)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 64),
                      SizedBox(height: 8),
                      Text('Жалоба принята!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
