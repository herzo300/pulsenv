// lib/services/object_detection_models.dart
//
// DTO для обнаружения объектов.
// Существует как backward-compatible API для complaint_form_screen.
// Реальная ML-детекция теперь в ml_kit_object_detection_service.dart.
import 'dart:typed_data';

class DetectedSearchObject {
  const DetectedSearchObject({
    required this.label,
    required this.displayLabel,
    required this.confidence,
    required this.rect,
  });

  final String label;
  final String displayLabel;
  final double confidence;
  final RectData rect;
}

class RectData {
  const RectData({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class ObjectDetectionResult {
  const ObjectDetectionResult({
    required this.objects,
    this.previewBytes,
  });

  final List<DetectedSearchObject> objects;
  final Uint8List? previewBytes;
}
