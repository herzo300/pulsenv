import 'package:flutter/material.dart';

/// A custom widget that applies a 3D perspective tilt effect on drag/pan gestures.
class TiltWidget extends StatefulWidget {
  const TiltWidget({super.key, required this.child});
  final Widget child;

  @override
  State<TiltWidget> createState() => _TiltWidgetState();
}

class _TiltWidgetState extends State<TiltWidget> {
  double _xAngle = 0.0;
  double _yAngle = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _yAngle += details.delta.dx * 0.002;
          _xAngle -= details.delta.dy * 0.002;
          _xAngle = _xAngle.clamp(-0.25, 0.25);
          _yAngle = _yAngle.clamp(-0.25, 0.25);
        });
      },
      onPanEnd: (_) => _resetTilt(),
      onPanCancel: () => _resetTilt(),
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015) // perspective depth
          ..rotateX(_xAngle)
          ..rotateY(_yAngle),
        alignment: FractionalOffset.center,
        child: widget.child,
      ),
    );
  }

  void _resetTilt() {
    setState(() {
      _xAngle = 0.0;
      _yAngle = 0.0;
    });
  }
}
