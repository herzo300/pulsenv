export 'object_detection_models.dart';
export 'object_detection_service_stub.dart'
    if (dart.library.io) 'object_detection_service_io.dart'
    if (dart.library.html) 'object_detection_service_web.dart';
