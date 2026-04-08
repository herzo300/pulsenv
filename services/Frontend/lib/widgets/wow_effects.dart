import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/pulse_colors.dart';

/// -------------------------------------------------------------
/// 1. AI RADAR EFFECT (Для наложения на карту)
/// -------------------------------------------------------------
class PulseRadarRadar extends StatefulWidget {
  final double radius;
  final Color color;

  const PulseRadarRadar({
    super.key,
    this.radius = 150.0,
    this.color = PulseColors.primary,
  });

  @override
  State<PulseRadarRadar> createState() => _PulseRadarRadarState();
}

class _PulseRadarRadarState extends State<PulseRadarRadar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
        return Stack(
          alignment: Alignment.center,
          children: [
            // Пульсирующие круги
            ...List.generate(3, (index) {
              double progress = (_controller.value + (index / 3)) % 1.0;
              return Container(
                width: widget.radius * 2 * progress,
                height: widget.radius * 2 * progress,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity(1.0 - progress),
                    width: 2.0,
                  ),
                ),
              );
            }),
            // Вращающийся луч сканера
            Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: Container(
                width: widget.radius * 2,
                height: widget.radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    center: Alignment.center,
                    startAngle: 0.0,
                    endAngle: math.pi / 4,
                    colors: [
                      widget.color.withOpacity(0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            // Центр радара
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: widget.color, blurRadius: 10, spreadRadius: 2),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// -------------------------------------------------------------
/// 2. WATCHDOG TRANSACTION CARD (Список покупок)
/// -------------------------------------------------------------
class WatchdogStatusCard extends StatelessWidget {
  final String title;
  final DateTime expiryDate;
  final int cameraCount;
  final bool isActive;

  const WatchdogStatusCard({
    super.key,
    required this.title,
    required this.expiryDate,
    required this.cameraCount,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final timeLeft = expiryDate.difference(DateTime.now());
    final hoursLeft = timeLeft.inHours;
    final minsLeft = timeLeft.inMinutes % 60;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PulseColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? PulseColors.primary.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isActive ? Icons.security : Icons.history,
                    color: isActive ? PulseColors.primary : PulseColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(color: PulseColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? PulseColors.success.withOpacity(0.1) : PulseColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'АКТИВНО' : 'ЗАВЕРШЕНО',
                  style: TextStyle(
                    color: isActive ? PulseColors.success : PulseColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat("Камер", "$cameraCount"),
              _buildStat("Осталось", isActive ? "$hoursLeftч $minsLeftм" : "0ч"),
              _buildStat("Тариф", title.contains("3ч") ? "250₽" : (title.contains("24ч") ? "500₽" : "1499₽")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: PulseColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: PulseColors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// -------------------------------------------------------------
/// 3. VLM ANALYSIS LOADER (WOW-эффект при подаче жалобы)
/// -------------------------------------------------------------
class VlmAnalysisOverlay extends StatelessWidget {
  final bool isAnalyzing;
  final String statusText;

  const VlmAnalysisOverlay({
    super.key,
    required this.isAnalyzing,
    this.statusText = "ИИ ГЕМИНИ АНАЛИЗИРУЕТ ФОТО...",
  });

  @override
  Widget build(BuildContext context) {
    if (!isAnalyzing) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PulseRadarRadar(radius: 80, color: PulseColors.primary),
            const SizedBox(height: 40),
            Text(
              statusText,
              style: const TextStyle(
                color: PulseColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "ОПРЕДЕЛЕНИЕ КАТЕГОРИИ И ОПИСАНИЕ ОБЪЕКТА",
              style: TextStyle(color: PulseColors.textSecondary, fontSize: 10),
            ),
            const SizedBox(height: 30),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: PulseColors.surfaceSoft,
                valueColor: AlwaysStoppedAnimation<Color>(PulseColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
