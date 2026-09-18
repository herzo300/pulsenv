// lib/services/object_detection_service.dart
//
// Dispatcher-фасад для обнаружения объектов.
//
// Реальная ML-детекция (Google ML Kit) живёт в ml_kit_object_detection_service.dart.
// Этот файл сохранён как backward-compatible API, который использует
// complaint_form_screen. По умолчанию возвращает пустой результат (no-op);
// при желании можно делегировать в MlKitObjectDetectionService.instance.
//
// Легаси io/web реализации на tflite удалены — конфликтовали с зависимостями.
import 'object_detection_models.dart';

// Re-export моделей для обратной совместимости импортов complaint_form_screen.
export 'object_detection_models.dart';

class ObjectDetectionService {
  ObjectDetectionService._();

  static final ObjectDetectionService instance = ObjectDetectionService._();

  /// No-op инициализация. Реальная инициализация ML Kit ленивая.
  Future<void> ensureInitialized() async {}

  /// Обнаружение объектов. По умолчанию возвращает пустой результат.
  /// Для реальной детекции используйте MlKitObjectDetectionService.instance.detect().
  Future<ObjectDetectionResult> detectObjects(List<int> imageBytes) async {
    return const ObjectDetectionResult(objects: []);
  }
}

