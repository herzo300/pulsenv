import 'dart:math' as math;
import 'package:flutter/material.dart';

class CityPulseWave extends StatefulWidget {
  final int totalCount;
  final Map<String, int> categoryCounts;

  const CityPulseWave({
    super.key,
    required this.totalCount,
    required this.categoryCounts,
  });

  @override
  State<CityPulseWave> createState() => _CityPulseWaveState();
}

class _CityPulseWaveState extends State<CityPulseWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate intensity based on total count
    // Base speed = 1.0, increase by 0.1 for every 10 complaints
    final double intensity = 1.0 + (widget.totalCount / 50).clamp(0.0, 3.0);
    
    // Determine primary color based on dominant categories
    // If roads or danger are high, shift to reddish
    final roads = widget.categoryCounts['Дороги'] ?? 0;
    final danger = widget.categoryCounts['Безопасность'] ?? 0;
    final critical = roads + danger;
    
    final Color pulseColor = Color.lerp(
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFFFF3D00), // Red-Orange
      (critical / (widget.totalCount == 0 ? 1 : widget.totalCount)).clamp(0.0, 1.0),
    )!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _PulsePainter(
            progress: _controller.value,
            intensity: intensity,
            color: pulseColor,
          ),
          child: Container(height: 40, width: double.infinity),
        );
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  final double intensity;
  final Color color;

  _PulsePainter({
    required this.progress,
    required this.intensity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    final double midY = size.height / 2;
    
    // Draw digital vertical bars
    final double barWidth = 3.0;
    final double spacing = 6.0;

    for (double x = 0; x <= size.width; x += spacing) {
      final double normalizedX = x / size.width;
      
      // Complex wave phase for digital look
      final double phase1 = progress * 2 * math.pi * intensity - normalizedX * 20;
      final double phase2 = progress * 4 * math.pi - normalizedX * 30;
      
      // Compose pseudo-random height
      double h = (math.sin(phase1) * 0.6 + math.sin(phase2) * 0.4).abs();
      
      // Add 'spikes' to make it feel alive
      final double spikePos = (normalizedX * 2 + progress) % 1.0;
      if (spikePos > 0.45 && spikePos < 0.55 && x % (spacing * 3) == 0) {
        h += 0.8 * intensity;
      }
      
      h = h * 12 * intensity + 2; // minimum height of 2
      
      path.moveTo(x, midY - h);
      path.lineTo(x, midY + h);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) => true;
}
