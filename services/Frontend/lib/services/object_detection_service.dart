// lib/services/object_detection_service.dart
//
// Dispatcher-фасад для обнаружения объектов.
// Делегирует реальную ML-детекцию в MlKitObjectDetectionService (Google ML Kit).
import 'dart:typed_data';

import 'ml_kit_object_detection_service.dart';
import 'object_detection_models.dart';

// Re-export моделей для обратной совместимости импортов complaint_form_screen.
export 'object_detection_models.dart';

class ObjectDetectionService {
  ObjectDetectionService._();

  static final ObjectDetectionService instance = ObjectDetectionService._();

  /// Инициализация ML Kit ленивая — выполняется при первом detect.
  Future<void> ensureInitialized() async {
    try {
      await MlKitObjectDetectionService.instance.ensureInitialized();
    } catch (_) {
      // ML Kit недоступен на этой платформе — detect вернёт пустой результат,
      // форма жалобы продолжит работу без локальной детекции.
    }
  }

  /// Обнаружение объектов через Google ML Kit (реальная детекция).
  Future<ObjectDetectionResult> detectObjects(List<int> imageBytes) async {
    try {
      final detections = await MlKitObjectDetectionService.instance.detect(
        inputImageBytes: Uint8List.fromList(imageBytes),
      );
      return ObjectDetectionResult(
        objects: detections
            .map(
              (d) => DetectedSearchObject(
                label: d.label,
                displayLabel: d.civicHint ?? d.label,
                confidence: d.confidence,
                rect: RectData(
                  left: d.boundingBox.left,
                  top: d.boundingBox.top,
                  right: d.boundingBox.right,
                  bottom: d.boundingBox.bottom,
                ),
              ),
            )
            .toList(),
      );
    } catch (_) {
      return const ObjectDetectionResult(objects: []);
    }
  }
}

