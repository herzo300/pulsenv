import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoCapturePanel extends StatelessWidget {
  const PhotoCapturePanel({
    super.key,
    required this.imageProcessing,
    required this.selectedImage,
    required this.detectedPreviewBytes,
    required this.detectedObjects,
    required this.searchPrompt,
    required this.isSearchCategory,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onEnhanceImage,
    this.imagePreviewWidget,
    this.upscaleButtonWidget,
    this.detectionSummaryWidget,
  });

  final bool imageProcessing;
  final File? selectedImage;
  final Uint8List? detectedPreviewBytes;
  final List<dynamic> detectedObjects;
  final String? searchPrompt;
  final bool isSearchCategory;
  final Function(ImageSource) onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onEnhanceImage;
  final Widget? imagePreviewWidget;
  final Widget? upscaleButtonWidget;
  final Widget? detectionSummaryWidget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPhotoButtons(),
        if (selectedImage != null) ...[
          imagePreviewWidget ?? const SizedBox.shrink(),
          upscaleButtonWidget ?? const SizedBox.shrink(),
          detectionSummaryWidget ?? const SizedBox.shrink(),
        ],
      ],
    );
  }

  Widget _buildPhotoButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                imageProcessing ? null : () => onPickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt, color: Colors.white70),
            label: const Text('Сделать фото',
                style: TextStyle(color: Colors.white70)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF00E5FF).withAlpha(100)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                imageProcessing ? null : () => onPickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library, color: Colors.white70),
            label:
                const Text('Галерея', style: TextStyle(color: Colors.white70)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF00E5FF).withAlpha(100)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
