import 'package:flutter/material.dart';

class UpscaleImageButton extends StatelessWidget {
  const UpscaleImageButton({
    super.key,
    required this.hasImage,
    required this.isProcessing,
    required this.isUpscaling,
    required this.onPressed,
  });

  final bool hasImage;
  final bool isProcessing;
  final bool isUpscaling;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!hasImage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        onPressed: (isProcessing || isUpscaling) ? null : onPressed,
        icon: isUpscaling
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome),
        label: Text(
          isUpscaling
              ? 'Real-ESRGAN x4...'
              : '\u0423\u043b\u0443\u0447\u0448\u0438\u0442\u044c \u0444\u043e\u0442\u043e \u00d74',
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: const Color(0xFF6EE7B7).withAlpha(160)),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          backgroundColor: const Color(0xFF0F1B17),
        ),
      ),
    );
  }
}
