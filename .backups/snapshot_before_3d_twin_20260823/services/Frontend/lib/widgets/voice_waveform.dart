// lib/widgets/voice_waveform.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({super.key, this.color = Colors.redAccent});

  final Color color;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (index) {
            final double phase = (index * 0.2) + _controller.value;
            final double height = 4.0 + (16.0 * (math.sin(phase * math.pi * 2).abs()));
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
