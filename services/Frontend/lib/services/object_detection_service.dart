import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

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

class ObjectDetectionService {
  ObjectDetectionService._();

  static final ObjectDetectionService instance = ObjectDetectionService._();

  static const String _modelAsset = 'assets/model/ssd_mobilenet_v1.tflite';
  static const String _labelsAsset = 'assets/label/labels.txt';
  static const double _scoreThreshold = 0.45;
  static const int _previewSize = 1024;

  static const Map<String, String> _labelMap = {
    'person': '\u0447\u0435\u043b\u043e\u0432\u0435\u043a',
    'bicycle': '\u0432\u0435\u043b\u043e\u0441\u0438\u043f\u0435\u0434',
    'car': '\u043c\u0430\u0448\u0438\u043d\u0430',
    'motorbike': '\u043c\u043e\u0442\u043e\u0446\u0438\u043a\u043b',
    'bus': '\u0430\u0432\u0442\u043e\u0431\u0443\u0441',
    'train': '\u043f\u043e\u0435\u0437\u0434',
    'truck': '\u0433\u0440\u0443\u0437\u043e\u0432\u0438\u043a',
    'boat': '\u043b\u043e\u0434\u043a\u0430',
    'bench': '\u0441\u043a\u0430\u043c\u0435\u0439\u043a\u0430',
    'bird': '\u043f\u0442\u0438\u0446\u0430',
    'cat': '\u043a\u043e\u0448\u043a\u0430',
    'dog': '\u0441\u043e\u0431\u0430\u043a\u0430',
    'horse': '\u043b\u043e\u0448\u0430\u0434\u044c',
    'backpack': '\u0440\u044e\u043a\u0437\u0430\u043a',
    'umbrella': '\u0437\u043e\u043d\u0442',
    'handbag': '\u0441\u0443\u043c\u043a\u0430',
    'suitcase': '\u0447\u0435\u043c\u043e\u0434\u0430\u043d',
    'bottle': '\u0431\u0443\u0442\u044b\u043b\u043a\u0430',
    'cup': '\u0447\u0430\u0448\u043a\u0430',
    'chair': '\u0441\u0442\u0443\u043b',
    'sofa': '\u0434\u0438\u0432\u0430\u043d',
    'tv': '\u0442\u0435\u043b\u0435\u0432\u0438\u0437\u043e\u0440',
    'laptop': '\u043d\u043e\u0443\u0442\u0431\u0443\u043a',
    'cell phone': '\u0442\u0435\u043b\u0435\u0444\u043e\u043d',
    'book': '\u043a\u043d\u0438\u0433\u0430',
    'clock': '\u0447\u0430\u0441\u044b',
    'teddy bear': '\u0438\u0433\u0440\u0443\u0448\u043a\u0430',
  };

  Interpreter? _interpreter;
  List<String> _labels = const [];
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    final options = InterpreterOptions()..threads = 2;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        options.addDelegate(XNNPackDelegate());
      }
    } catch (_) {}

    _interpreter = await Interpreter.fromAsset(_modelAsset, options: options);
    final rawLabels = await rootBundle.loadString(_labelsAsset);
    _labels = rawLabels
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    _initialized = true;
  }

  Future<ObjectDetectionResult> detectObjects(List<int> imageBytes) async {
    await ensureInitialized();

    final source = img.decodeImage(Uint8List.fromList(imageBytes));
    final interpreter = _interpreter;
    if (source == null || interpreter == null) {
      return const ObjectDetectionResult(objects: []);
    }

    final inputTensor = interpreter.getInputTensor(0);
    final inputShape = inputTensor.shape;
    final inputType = inputTensor.type;
    final inputHeight = inputShape[1];
    final inputWidth = inputShape[2];
    final resized = img.copyResize(
      source,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.average,
    );

    final input = _buildInputBuffer(
      image: resized,
      inputHeight: inputHeight,
      inputWidth: inputWidth,
      inputType: inputType,
    );

    final outputBoxes = List.generate(
      1,
      (_) => List.generate(10, (_) => List.filled(4, 0.0)),
    );
    final outputClasses = List.generate(1, (_) => List.filled(10, 0.0));
    final outputScores = List.generate(1, (_) => List.filled(10, 0.0));
    final outputCount = List.generate(1, (_) => List.filled(1, 0.0));

    interpreter.runForMultipleInputs([input], {
      0: outputBoxes,
      1: outputClasses,
      2: outputScores,
      3: outputCount,
    });

    final detections = <DetectedSearchObject>[];
    final rawCount = outputCount.first.first.round().clamp(0, 10);

    for (var i = 0; i < rawCount; i++) {
      final score = (outputScores.first[i] as num).toDouble();
      if (score < _scoreThreshold) continue;

      final classIndex = (outputClasses.first[i] as num).round();
      if (classIndex < 0 || classIndex >= _labels.length) continue;

      final box = outputBoxes.first[i];
      final top = (box[0] as num).toDouble().clamp(0.0, 1.0);
      final left = (box[1] as num).toDouble().clamp(0.0, 1.0);
      final bottom = (box[2] as num).toDouble().clamp(0.0, 1.0);
      final right = (box[3] as num).toDouble().clamp(0.0, 1.0);
      final label = _labels[classIndex];

      detections.add(
        DetectedSearchObject(
          label: label,
          displayLabel: _labelMap[label] ?? label,
          confidence: score,
          rect: RectData(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
          ),
        ),
      );
    }

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    return ObjectDetectionResult(
      objects: detections,
      previewBytes: detections.isEmpty
          ? null
          : Uint8List.fromList(_drawPreview(source, detections)),
    );
  }

  Object _buildInputBuffer({
    required img.Image image,
    required int inputHeight,
    required int inputWidth,
    required TensorType inputType,
  }) {
    if (inputType.value == TfLiteType.kTfLiteUInt8) {
      return List.generate(
        1,
        (_) => List.generate(
          inputHeight,
          (y) => List.generate(
            inputWidth,
            (x) {
              final pixel = image.getPixel(x, y);
              return [
                pixel.r.toInt(),
                pixel.g.toInt(),
                pixel.b.toInt(),
              ];
            },
          ),
        ),
      );
    }

    return List.generate(
      1,
      (_) => List.generate(
        inputHeight,
        (y) => List.generate(
          inputWidth,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );
  }

  List<int> _drawPreview(
    img.Image source,
    List<DetectedSearchObject> detections,
  ) {
    final maxSide = source.width > source.height ? source.width : source.height;
    final scale = maxSide <= _previewSize ? 1.0 : _previewSize / maxSide;
    final preview = scale == 1.0
        ? img.copyResize(source, width: source.width, height: source.height)
        : img.copyResize(
            source,
            width: (source.width * scale).round(),
            height: (source.height * scale).round(),
          );

    for (final detection in detections.take(5)) {
      final left = (detection.rect.left * preview.width).round();
      final top = (detection.rect.top * preview.height).round();
      final right = (detection.rect.right * preview.width).round();
      final bottom = (detection.rect.bottom * preview.height).round();

      img.drawRect(
        preview,
        x1: left,
        y1: top,
        x2: right,
        y2: bottom,
        color: img.ColorRgb8(53, 214, 146),
        thickness: 4,
      );

      final labelY = top - 28 < 0 ? top + 6 : top - 28;
      img.fillRect(
        preview,
        x1: left,
        y1: labelY,
        x2: (left + 220).clamp(0, preview.width - 1),
        y2: (labelY + 22).clamp(0, preview.height - 1),
        color: img.ColorRgba8(10, 22, 18, 220),
      );
      img.drawString(
        preview,
        '${detection.displayLabel} ${(detection.confidence * 100).round()}%',
        font: img.arial14,
        x: left + 6,
        y: labelY + 4,
        color: img.ColorRgb8(244, 255, 249),
      );
    }

    return img.encodeJpg(preview, quality: 88);
  }
}
