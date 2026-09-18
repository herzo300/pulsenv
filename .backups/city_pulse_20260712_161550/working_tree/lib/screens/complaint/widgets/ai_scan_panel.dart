import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../widgets/ai_scan_preview.dart';

class AiScanPanel extends StatelessWidget {
  const AiScanPanel({
    super.key,
    required this.selectedImage,
    required this.detectedPreviewBytes,
    required this.scanProgress,
    required this.onRemoveImage,
  });

  final File? selectedImage;
  final Uint8List? detectedPreviewBytes;
  final AiScanProgress scanProgress;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    if (selectedImage == null) {
      return const SizedBox.shrink();
    }

    return AiScanPreview(
      imageProvider: detectedPreviewBytes != null
          ? MemoryImage(detectedPreviewBytes!)
          : FileImage(selectedImage!),
      originalImageProvider: detectedPreviewBytes != null ? FileImage(selectedImage!) : null,
      progress: scanProgress,
      idleBorderColor: const Color(0xFF00E5FF).withAlpha(50),
      onRemove: onRemoveImage,
    );
  }
}
