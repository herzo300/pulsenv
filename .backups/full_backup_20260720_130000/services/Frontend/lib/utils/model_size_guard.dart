// lib/utils/model_size_guard.dart
//
// Защита от слишком больших 3D-моделей (GLB) на клиенте.
//
// Бэкенд /ai/generate-cad может возвращать модели >10 МБ, что вызывает:
//   • фризы при загрузке в Flutter3DController;
//   • OOM на устройствах с 2 ГБ ОЗУ;
//   • долгий рендер на слабых GPU.
//
// Эта утилита:
//   1. Проверяет Content-Length / размер файла модели;
//   2. Блокирует модели свыше [maxBytes] (по умолчанию 3 МБ);
//   3. Проверяет, что модель сжата Draco (header magic / заголовок JSON);
//   4. Возвращает ModelValidationResult для UI.
//
// План: ограничить размер GLB-файлов до 2-3 МБ + сжатие Draco на бэкенде.
//
// Item 6 (CityPulse_Improvements.md): UX/UI и Перформанс — Оптимизация 3D.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Результат валидации 3D-модели.
class ModelValidationResult {
  const ModelValidationResult({
    required this.isValid,
    required this.sizeBytes,
    required this.maxBytes,
    this.isDracoCompressed = false,
    this.reason,
  });

  final bool isValid;

  /// Фактический размер модели в байтах.
  final int sizeBytes;

  /// Допустимый лимит.
  final int maxBytes;

  /// Обнаружено ли сжатие Draco в модели.
  final bool isDracoCompressed;

  /// Причина невалидности (человекочитаемая, для снекбара).
  final String? reason;

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get maxLabel {
    if (maxBytes < 1024 * 1024) return '${maxBytes ~/ 1024} KB';
    return '${(maxBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

class ModelSizeGuard {
  const ModelSizeGuard._();

  /// Лимит размера модели: 3 МБ (среднее между 2 и 3 из плана).
  static const int defaultMaxBytes = 3 * 1024 * 1024; // 3 MB

  /// Magic-число для glTF Binary (GLB): 0x46546C67 ('glTF' в little-endian).
  static const int _glbMagic = 0x46546C67;

  /// Строка с маркером Draco-сжатия в JSON-чанки GLB.
  static const String _dracoMarker = 'KHR_draco_mesh_compression';

  /// Валидировать модель по URL.
  ///
  /// Делает HEAD-запрос (чтобы не качать гигантский файл целиком),
  /// а при отсутствии Content-Length — качает и проверяет байты.
  static Future<ModelValidationResult> validateUrl(
    String url, {
    int maxBytes = defaultMaxBytes,
    Map<String, String>? headers,
  }) async {
    try {
      // 1) HEAD-запрос — дёшево, даёт Content-Length.
      final head = await http.head(Uri.parse(url), headers: headers ?? {});
      final contentLength = int.tryParse(
        head.headers['content-length'] ?? '',
      );

      if (contentLength != null) {
        if (contentLength > maxBytes) {
          return ModelValidationResult(
            isValid: false,
            sizeBytes: contentLength,
            maxBytes: maxBytes,
            reason: 'Модель слишком большая: '
                '${(contentLength / (1024 * 1024)).toStringAsFixed(1)} MB. '
                'Лимит — ${(maxBytes / (1024 * 1024)).toStringAsFixed(0)} MB. '
                'Запросите сжатие Draco на бэкенде.',
          );
        }
      }

      // 2) Если Content-Length нет или нужен Draco-чек — качаем первые 4KB.
      final headResp = await http.get(
        Uri.parse(url),
        headers: {...?headers, 'Range': 'bytes=0-4095'},
      );
      final bytes = headResp.bodyBytes;
      final size = contentLength ?? bytes.length;

      final isDraco = _detectDraco(Uint8List.fromList(bytes));
      final isGlb = _isGlb(Uint8List.fromList(bytes));

      if (size > maxBytes) {
        return ModelValidationResult(
          isValid: false,
          sizeBytes: size,
          maxBytes: maxBytes,
          isDracoCompressed: isDraco,
          reason: 'Модель слишком большая (${(size / (1024 * 1024)).toStringAsFixed(1)} MB). '
              'Запросите Draco-сжатие.',
        );
      }

      if (!isGlb) {
        debugPrint('[ModelSizeGuard] URL does not look like GLB: $url');
      }

      // Предупреждение (но не блокировка), если Draco не обнаружен.
      if (!isDraco && size > 1024 * 1024) {
        debugPrint('[ModelSizeGuard] WARNING: model >1MB without Draco compression. '
            'URL: $url, size: ${(size / (1024 * 1024)).toStringAsFixed(1)}MB');
      }

      return ModelValidationResult(
        isValid: true,
        sizeBytes: size,
        maxBytes: maxBytes,
        isDracoCompressed: isDraco,
      );
    } catch (e) {
      debugPrint('[ModelSizeGuard] validateUrl failed: $e');
      return ModelValidationResult(
        isValid: false,
        sizeBytes: 0,
        maxBytes: maxBytes,
        reason: 'Не удалось проверить модель: $e',
      );
    }
  }

  /// Валидировать локальный файл модели.
  static Future<ModelValidationResult> validateFile(
    String path, {
    int maxBytes = defaultMaxBytes,
  }) async {
    try {
      final file = File(path);
      final size = await file.length();
      final isDraco = _detectDraco(await _readFileHead(file, 8192));

      if (size > maxBytes) {
        return ModelValidationResult(
          isValid: false,
          sizeBytes: size,
          maxBytes: maxBytes,
          isDracoCompressed: isDraco,
          reason: 'Файл слишком большой: '
              '${(size / (1024 * 1024)).toStringAsFixed(1)} MB.',
        );
      }
      return ModelValidationResult(
        isValid: true,
        sizeBytes: size,
        maxBytes: maxBytes,
        isDracoCompressed: isDraco,
      );
    } catch (e) {
      return ModelValidationResult(
        isValid: false,
        sizeBytes: 0,
        maxBytes: maxBytes,
        reason: 'Не удалось прочитать файл: $e',
      );
    }
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  static bool _isGlb(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // GLB magic: 0x67 0x6C 0x54 0x46 = 'glTF' little-endian.
    final view = ByteData.sublistView(bytes, 0, 4);
    return view.getUint32(0, Endian.little) == _glbMagic;
  }

  static bool _detectDraco(Uint8List bytes) {
    // Ищем маркер KHR_draco_mesh_compression в первых байтах JSON-чанка.
    // GLB-структура: magic(4) + version(4) + length(4) + chunks...
    // JSON-чанк содержит описание расширений; если Draco применён, маркер будет там.
    try {
      final len = bytes.length < 4096 ? bytes.length : 4096;
      final head = String.fromCharCodes(bytes.sublist(0, len));
      return head.contains(_dracoMarker);
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List> _readFileHead(File file, int bytes) async {
    final raf = await file.open();
    try {
      final data = await raf.read(bytes);
      return Uint8List.fromList(data);
    } finally {
      await raf.close();
    }
  }
}
