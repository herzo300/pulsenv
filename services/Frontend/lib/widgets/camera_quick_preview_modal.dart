import 'dart:async';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

/// Quick 3-second popup preview for video cameras when long-pressed on map or lists.
class CameraQuickPreviewModal extends StatefulWidget {
  final String cameraName;
  final String streamUrl;
  final String address;

  const CameraQuickPreviewModal({
    super.key,
    required this.cameraName,
    required this.streamUrl,
    required this.address,
  });

  static Future<void> show(
    BuildContext context, {
    required String cameraName,
    required String streamUrl,
    required String address,
  }) async {
    await HapticService.instance.heavy();
    if (!context.mounted) return;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CameraQuickPreviewModal(
        cameraName: cameraName,
        streamUrl: streamUrl,
        address: address,
      ),
    );
  }

  @override
  State<CameraQuickPreviewModal> createState() => _CameraQuickPreviewModalState();
}

class _CameraQuickPreviewModalState extends State<CameraQuickPreviewModal> {
  int _secondsRemaining = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.videocam_rounded, color: Colors.cyanAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'БЫСТРЫЙ ПРЕВЬЮ',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.cameraName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_secondsRemaining}s',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mock/Live Video Container
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_fill_rounded, color: Colors.cyanAccent, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            widget.address,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '● LIVE',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
