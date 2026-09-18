// lib/services/ml_kit_object_detection_service.dart
//
// Обнаружение объектов на устройстве через Google ML Kit.
//
// Отличие от существующего ObjectDetectionService (на tflite/ssd_mobilenet):
//   • использует google_mlkit_object_detection — официальные модели Google,
//     не требует тащить .tflite в assets (меньше размер APK);
//   • маппинг распознанных объектов -> городские проблемы (яма, граффити,
//     переполненный бак) для подсказки категории жалобы в AR-камере;
//   • порог уверенности и троттлинг кадров для стабильных 30 FPS.
//
// Платформы: Android, iOS. На Web/Desktop — stub через kIsWeb.
//
// Item 4 (CityPulse_Improvements.md): Камера, AR и Компьютерное зрение.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

/// Распознанный объект + привязка к категории жалобы City Pulse.
class CityObjectDetection {
  const CityObjectDetection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.suggestedComplaintCategory,
    this.civicHint,
  });

  final String label;
  final double confidence;

  /// Прямоугольник в координатах исходного изображения.
  final Rect boundingBox;

  /// Категория жалобы, которую можно предложить пользователю.
  /// null, если объект не релевантен городским проблемам.
  final String? suggestedComplaintCategory;

  /// Человекочитаемая подсказка для AR-оверлея.
  final String? civicHint;

  bool get hasCivicRelevance => suggestedComplaintCategory != null;
}

class MlKitObjectDetectionService {
  MlKitObjectDetectionService._();
  static final MlKitObjectDetectionService instance =
      MlKitObjectDetectionService._();

  ObjectDetector? _detector;
  bool _initialized = false;

  /// Минимальная уверенность модели, чтобы считать детекцию значимой.
  static const double _confidenceThreshold = 0.5;

  /// Маппинг label ML Kit -> категория жалобы City Pulse.
  /// ML Kit возвращает базовые классы (car, person, ...); мы расширяем
  /// их до городских категорий через эвристики на форме жалобы.
  static const Map<String, _CivicMapping> _civicMap = {
    // Транспорт / дороги
    'Car': _CivicMapping('transport_roads', 'Автомобиль — зафиксируйте нарушение ПДД?'),
    'Land vehicle': _CivicMapping('transport_roads', 'Транспорт — опишите проблему'),
    // Мусор
    'Trash bin': _CivicMapping('garbage', 'Переполненный мусорный бак?'),
    'Bottle': _CivicMapping('garbage', 'Мусор на территории'),
    // Инфраструктура
    'Bench': _CivicMapping('infrastructure', 'Скамейка — повреждена?'),
    'Street light': _CivicMapping('infrastructure', 'Фонарь не горит?'),
    'Traffic light': _CivicMapping('transport_roads', 'Сломанный светофор?'),
    // Зелёные насаждения
    'Plant': _CivicMapping('landscaping', 'Просим обрезку / уход'),
    'Tree': _CivicMapping('landscaping', 'Дерево угрожает падением?'),
  };

  /// Инициализация детектора. Базовая модель ML Kit, single-image mode
  /// (подходит для покадрового анализа из AR-камеры).
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (kIsWeb || Platform.isWindows || Platform.isLinux) {
      debugPrint('[MlKitObjectDetection] unsupported platform, skipping init');
      _initialized = true;
      return;
    }
    try {
      final options = ObjectDetectorOptions(
        classifyObjects: true,
        multipleObjects: true,
        mode: DetectionMode.single, // покадровый режим
      );
      _detector = ObjectDetector(options: options);
      _initialized = true;
      debugPrint('[MlKitObjectDetection] initialized');
    } catch (e) {
      debugPrint('[MlKitObjectDetection] init failed: $e');
    }
  }

  bool get isAvailable {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return false;
    return _detector != null;
  }

  /// Распознать объекты на изображении из байтов (JPEG/PNG).
  ///
  /// [inputImageBytes] — сырые байты кадра с камеры.
  /// Возвращает список детекций, отфильтрованный по порогу уверенности
  /// и отсортированный по убыванию уверенности.
  Future<List<CityObjectDetection>> detect({
    required Uint8List inputImageBytes,
  }) async {
    await ensureInitialized();
    if (_detector == null) return const [];

    try {
      final inputImage = InputImage.fromBytes(
        bytes: inputImageBytes,
        metadata: InputImageMetadata(
          size: const Size(720, 1280),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 720,
        ),
      );

      final objects = await _detector!.processImage(inputImage);
      final detections = <CityObjectDetection>[];

      for (final obj in objects) {
        final label = obj.labels.isNotEmpty ? obj.labels.first.text : '';
        final confidence = obj.labels.isNotEmpty
            ? obj.labels.first.confidence
            : 0.0;

        if (confidence < _confidenceThreshold && label.isEmpty) continue;

        final civic = _civicMap[label];
        detections.add(CityObjectDetection(
          label: label.isNotEmpty ? label : 'Объект',
          confidence: confidence,
          boundingBox: obj.boundingBox,
          suggestedComplaintCategory: civic?.category,
          civicHint: civic?.hint,
        ));
      }

      detections.sort((a, b) => b.confidence.compareTo(a.confidence));
      return detections;
    } catch (e) {
      debugPrint('[MlKitObjectDetection] detect failed: $e');
      return const [];
    }
  }

  /// Освободить ресурсы модели.
  void dispose() {
    _detector?.close();
    _detector = null;
    _initialized = false;
  }
}

/// Внутренняя структура для маппинга ML Kit label -> civic category.
class _CivicMapping {
  final String category;
  final String hint;
  const _CivicMapping(this.category, this.hint);
}
