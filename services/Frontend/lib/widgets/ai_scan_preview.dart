import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

enum AiScanStage {
  scanning,
  classification,
  duplicateSearch,
  complete,
}

class AiScanProgress {
  const AiScanProgress({
    required this.stage,
    required this.value,
    required this.active,
    this.title,
    this.subtitle,
  });

  const AiScanProgress.idle()
      : stage = AiScanStage.scanning,
        value = 0,
        active = false,
        title = null,
        subtitle = null;

  final AiScanStage stage;
  final double value;
  final bool active;
  final String? title;
  final String? subtitle;

  double get clampedValue => value.clamp(0.0, 1.0).toDouble();
  int get percent => (clampedValue * 100).round();

  String get resolvedTitle {
    if (title != null && title!.trim().isNotEmpty) {
      return title!;
    }
    switch (stage) {
      case AiScanStage.scanning:
        return 'Сканирование кадра';
      case AiScanStage.classification:
        return 'Классификация AI';
      case AiScanStage.duplicateSearch:
        return 'Поиск дублей';
      case AiScanStage.complete:
        return 'Сканирование завершено';
    }
  }

  String get resolvedSubtitle {
    if (subtitle != null && subtitle!.trim().isNotEmpty) {
      return subtitle!;
    }
    switch (stage) {
      case AiScanStage.scanning:
        return 'Нормализуем изображение и снимаем визуальные признаки.';
      case AiScanStage.classification:
        return 'Определяем категорию, описание и пространственный контекст.';
      case AiScanStage.duplicateSearch:
        return 'Проверяем ближайшие обращения и карту похожих сигналов.';
      case AiScanStage.complete:
        return 'AI-подсказки готовы к отправке.';
    }
  }

  int get stageIndex {
    switch (stage) {
      case AiScanStage.scanning:
        return 0;
      case AiScanStage.classification:
        return 1;
      case AiScanStage.duplicateSearch:
        return 2;
      case AiScanStage.complete:
        return 3;
    }
  }
}

class AiScanPreview extends StatefulWidget {
  const AiScanPreview({
    super.key,
    required this.imageProvider,
    required this.progress,
    this.height = 170,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.onRemove,
    this.activeColor = const Color(0xFF00E5FF),
    this.idleBorderColor = const Color(0x332196F3),
  });

  final ImageProvider imageProvider;
  final AiScanProgress progress;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback? onRemove;
  final Color activeColor;
  final Color idleBorderColor;

  @override
  State<AiScanPreview> createState() => _AiScanPreviewState();
}

class _AiScanPreviewState extends State<AiScanPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hudController;

  @override
  void initState() {
    super.initState();
    _hudController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _hudController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.progress.active;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: isActive
                      ? widget.activeColor.withAlpha(145)
                      : widget.idleBorderColor,
                ),
                image: DecorationImage(
                  image: widget.imageProvider,
                  fit: BoxFit.cover,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: widget.activeColor.withAlpha(40),
                          blurRadius: 24,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(isActive ? 44 : 16),
                        Colors.transparent,
                        Colors.black.withAlpha(isActive ? 52 : 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isActive)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: widget.borderRadius,
                  child: AnimatedBuilder(
                    animation: _hudController,
                    builder: (context, _) {
                      final phase = _hudController.value;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 0.8, sigmaY: 0.8),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0x2400E5FF),
                                    Colors.transparent,
                                    const Color(0x1800E5FF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _AiScanHudPainter(
                                phase: phase,
                                color: widget.activeColor,
                              ),
                            ),
                          ),
                          _buildScanBeam(phase),
                          _buildTelemetryHeader(),
                          _buildPercentBadge(),
                          _buildBottomHud(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            if (widget.onRemove != null)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  icon: const Icon(Icons.close, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        isActive ? Colors.black.withAlpha(120) : Colors.black54,
                  ),
                  onPressed: isActive ? null : widget.onRemove,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanBeam(double phase) {
    final top = 16 + (widget.height - 44) * phase;
    final beamOpacity = 0.58 + (math.sin(phase * math.pi) * 0.24);

    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  widget.activeColor.withAlpha((beamOpacity * 255).round()),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      widget.activeColor.withAlpha((beamOpacity * 170).round()),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.activeColor.withAlpha(70),
                  const Color(0x0000E5FF),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryHeader() {
    return Positioned(
      left: 12,
      top: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(118),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: widget.activeColor.withAlpha(72)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.activeColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.activeColor.withAlpha(160),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'PULSE.AI VISION',
              style: TextStyle(
                color: Colors.white.withAlpha(232),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentBadge() {
    return Positioned(
      right: 12,
      top: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(126),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.activeColor.withAlpha(82)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${widget.progress.percent}%',
              style: TextStyle(
                color: Colors.white.withAlpha(242),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'SYSTEM LOCK',
              style: TextStyle(
                color: widget.activeColor.withAlpha(210),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomHud() {
    const stages = [
      (AiScanStage.scanning, 'Сканирование'),
      (AiScanStage.classification, 'Классификация'),
      (AiScanStage.duplicateSearch, 'Поиск дублей'),
    ];

    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(132),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.activeColor.withAlpha(74)),
          boxShadow: [
            BoxShadow(
              color: widget.activeColor.withAlpha(28),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.progress.resolvedTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.progress.resolvedSubtitle,
                        style: TextStyle(
                          color: Colors.white.withAlpha(170),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${widget.progress.percent} / 100',
                  style: TextStyle(
                    color: widget.activeColor.withAlpha(228),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: widget.progress.clampedValue,
                backgroundColor: Colors.white.withAlpha(20),
                valueColor: AlwaysStoppedAnimation<Color>(widget.activeColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < stages.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _StageChip(
                      label: stages[i].$2,
                      isActive: widget.progress.stageIndex == i &&
                          widget.progress.stage != AiScanStage.complete,
                      isComplete: widget.progress.stageIndex > i ||
                          widget.progress.stage == AiScanStage.complete,
                      color: widget.activeColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.isActive,
    required this.isComplete,
    required this.color,
  });

  final String label;
  final bool isActive;
  final bool isComplete;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fill = isComplete
        ? color.withAlpha(34)
        : isActive
            ? color.withAlpha(22)
            : Colors.white.withAlpha(10);
    final border = isComplete
        ? color.withAlpha(140)
        : isActive
            ? color.withAlpha(92)
            : Colors.white.withAlpha(20);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isComplete || isActive ? color : Colors.white24,
              shape: BoxShape.circle,
              boxShadow: (isComplete || isActive)
                  ? [
                      BoxShadow(
                        color: color.withAlpha(110),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isComplete || isActive
                    ? Colors.white.withAlpha(228)
                    : Colors.white60,
                fontSize: 10,
                fontWeight:
                    isActive || isComplete ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiScanHudPainter extends CustomPainter {
  const _AiScanHudPainter({
    required this.phase,
    required this.color,
  });

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final verticalPaint = Paint()
      ..color = color.withAlpha(20)
      ..strokeWidth = 1;
    final horizontalPaint = Paint()
      ..color = color.withAlpha(12)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), verticalPaint);
    }
    for (double y = 0; y <= size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), horizontalPaint);
    }

    final scanlinePaint = Paint()
      ..color = Colors.white.withAlpha(8)
      ..strokeWidth = 1;
    for (double y = 0; y <= size.height; y += 9) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    final cornerPaint = Paint()
      ..color = color.withAlpha(170)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const corner = 24.0;
    const inset = 10.0;
    _drawCorner(canvas, cornerPaint, Offset(inset, inset), corner, true, true);
    _drawCorner(
      canvas,
      cornerPaint,
      Offset(size.width - inset, inset),
      corner,
      false,
      true,
    );
    _drawCorner(
      canvas,
      cornerPaint,
      Offset(inset, size.height - inset),
      corner,
      true,
      false,
    );
    _drawCorner(
      canvas,
      cornerPaint,
      Offset(size.width - inset, size.height - inset),
      corner,
      false,
      false,
    );

    final center = Offset(size.width / 2, size.height / 2 - 8);
    final radius = math.min(size.width, size.height) * 0.16 +
        math.sin(phase * math.pi * 2) * 3;
    final lockPaint = Paint()
      ..color = color.withAlpha(110)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, radius, lockPaint);
    canvas.drawCircle(
        center, radius * 0.62, lockPaint..color = color.withAlpha(70));

    final axisPaint = Paint()
      ..color = color.withAlpha(130)
      ..strokeWidth = 1.1;
    canvas.drawLine(
      Offset(center.dx - radius - 16, center.dy),
      Offset(center.dx - radius + 6, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx + radius - 6, center.dy),
      Offset(center.dx + radius + 16, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - 16),
      Offset(center.dx, center.dy - radius + 6),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + radius - 6),
      Offset(center.dx, center.dy + radius + 16),
      axisPaint,
    );

    final noisePaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 46; i++) {
      final tick = phase * 32 + i * 0.73;
      final x = (math.sin(tick * 1.27) * 0.5 + 0.5) * size.width;
      final y = (math.cos(tick * 1.81 + i) * 0.5 + 0.5) * size.height;
      final alpha = 10 + ((math.sin(tick * 2.14) + 1) * 0.5 * 24).round();
      noisePaint.color = color.withAlpha(alpha);
      canvas.drawCircle(Offset(x, y), i.isEven ? 0.9 : 1.3, noisePaint);
    }
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    Offset anchor,
    double length,
    bool left,
    bool top,
  ) {
    final horizontalEnd = Offset(
      anchor.dx + (left ? length : -length),
      anchor.dy,
    );
    final verticalEnd = Offset(
      anchor.dx,
      anchor.dy + (top ? length : -length),
    );
    canvas.drawLine(anchor, horizontalEnd, paint);
    canvas.drawLine(anchor, verticalEnd, paint);
  }

  @override
  bool shouldRepaint(covariant _AiScanHudPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.color != color;
  }
}
