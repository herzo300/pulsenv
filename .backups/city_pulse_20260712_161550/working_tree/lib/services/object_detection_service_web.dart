import 'object_detection_models.dart';

class ObjectDetectionService {
  ObjectDetectionService._();

  static final ObjectDetectionService instance = ObjectDetectionService._();

  Future<void> ensureInitialized() async {}

  Future<ObjectDetectionResult> detectObjects(List<int> imageBytes) async {
    return const ObjectDetectionResult(objects: []);
  }
}
