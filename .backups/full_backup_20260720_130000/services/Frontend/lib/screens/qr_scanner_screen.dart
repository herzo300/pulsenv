// lib/screens/qr_scanner_screen.dart
//
// Экран сканирования QR-кодов на базе mobile_scanner (Google ML Kit).
//
// Сценарии City Pulse:
//   • QR на квитанциях ЖКХ → быстрый переход к форме жалобы об услугах ЖКХ;
//   • QR на инфо-стендах / остановках → переход к карте с сигналом объекта;
//   • QR сDeep-link на конкретную жалобу → открытие деталей.
//
// После успешного сканирования:
//   • Распознаётся URL или scheme (citypulse://...);
//   • Запускается callback [onDetected] (или навигация через go_router);
//   • Лёгкая тактильная отдача + звук успешного скана.
//
// Item 4 (CityPulse_Improvements.md): Камера, AR и Компьютерное зрение.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../theme/pulse_colors.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  bool _hasScanned = false;
  late final AnimationController _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _scanLineAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanLineAnim.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_hasScanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _hasScanned = true;

    // Тактильная отдача (ignore errors on unsupported devices).
    try {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib) Vibration.vibrate(duration: 60);
    } catch (_) {}

    if (!mounted) return;

    // Пытаемся интерпретировать как deep-link / route City Pulse.
    final route = _resolveRoute(raw);
    if (route != null) {
      context.go(route);
      return;
    }

    // Иначе показываем результат + действия (открыть / копировать).
    _showResultDialog(raw);
  }

  /// Если QR содержит citypulse:// или относительный путь — вернуть go_router path.
  /// Иначе вернуть null (обработаем как URL).
  String? _resolveRoute(String raw) {
    const scheme = 'citypulse://';
    if (raw.startsWith(scheme)) {
      return raw.substring(scheme.length);
    }
    // /complaint-form?lat=...&lng=...
    if (raw.startsWith('/complaint') ||
        raw.startsWith('/map') ||
        raw.startsWith('/profile')) {
      return raw;
    }
    return null;
  }

  void _showResultDialog(String raw) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: PulseColors.backgroundRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: PulseColors.primary),
            const SizedBox(width: 10),
            const Text('QR-код распознан'),
          ],
        ),
        content: SelectableText(
          raw,
          style: TextStyle(color: PulseColors.textPrimary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: raw));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                _hasScanned = false; // разрешить повторный скан
              }
            },
            child: const Text('Копировать'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, raw); // вернуть результат вызывающему
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Камера ────────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),

          // ─── Затемнение по краям (vignette) ────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
                radius: 0.9,
              ),
            ),
          ),

          // ─── Рамка сканера + анимация линии ────────────────────────
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                children: [
                  // Углы рамки
                  CustomPaint(
                    size: const Size(280, 280),
                    painter: _ScannerFramePainter(
                      color: PulseColors.primary,
                    ),
                  ),
                  // Бегущая линия
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (context, child) {
                      return Positioned(
                        left: 16,
                        right: 16,
                        top: 16 + (_scanLineAnim.value * 248),
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              PulseColors.primary,
                              Colors.transparent,
                            ]),
                            boxShadow: [
                              BoxShadow(
                                color: PulseColors.primary.withValues(alpha: 0.6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ─── AppBar (полупрозрачный) ───────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    _CircleButton(
                      icon: Icons.flash_off_rounded,
                      onTap: () => _controller.toggleTorch(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Подсказка снизу ───────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    Text(
                      'Наведите камеру на QR-код',
                      style: TextStyle(
                        color: PulseColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ЖКХ, остановки, инфо-стенды города',
                      style: TextStyle(
                        color: PulseColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: PulseColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}

/// Рисует угловые L-скобки рамки сканера.
class _ScannerFramePainter extends CustomPainter {
  const _ScannerFramePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const cornerLen = 32.0;
    final w = size.width;
    final h = size.height;

    // Верхний-левый
    canvas.drawLine(const Offset(0, cornerLen), Offset.zero, paint);
    canvas.drawLine(Offset.zero, const Offset(cornerLen, 0), paint);
    // Верхний-правый
    canvas.drawLine(Offset(w - cornerLen, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, cornerLen), paint);
    // Нижний-левый
    canvas.drawLine(Offset(0, h - cornerLen), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(cornerLen, h), paint);
    // Нижний-правый
    canvas.drawLine(Offset(w - cornerLen, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h - cornerLen), Offset(w, h), paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter old) =>
      old.color != color;
}
