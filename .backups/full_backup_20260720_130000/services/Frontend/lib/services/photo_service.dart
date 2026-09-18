// lib/services/photo_service.dart
//
// Переиспользуемый сервис работы с фото: пикер, сжатие, загрузка в storage.
//
// Извлечено из complaint_form_screen.dart (_uploadSelectedImageToStorage +
// _compressImageIsolate) в единый сервис, чтобы переиспользовать в форме
// бюро находок и других экранах без дублирования логики.
//
// Возможности:
//   • pickImage(ImageSource) — камера или галерея (image_picker)
//   • compressImage(File) — сжатие JPEG q75 в isolate (без фриза UI)
//   • uploadToStorage(File, {bucket}) — raw-bytes POST → публичный URL
//   • pickAndUpload(ImageSource) — полный пайплайн пикер→сжатие→загрузка
//   • toLocalPath(File) — file:// path для offline-сохранения
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../map/map_config.dart';

/// Ошибка загрузки фото в storage.
class StorageUploadException implements Exception {
  const StorageUploadException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'StorageUploadException: $message (${statusCode ?? "?"})';
}

class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();

  static final _picker = ImagePicker();

  /// Максимальная сторона изображения после ресайза (px).
  static const int maxDimension = 1280;

  /// Качество JPEG при сжатии.
  static const int jpegQuality = 75;

  // ─── Пикер ─────────────────────────────────────────────────────────────────

  /// Выбрать фото из камеры или галереи. Возвращает File или null (отмена).
  Future<File?> pickImage(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 85, // первичное сжатие пикером
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (xfile == null) return null;
    return File(xfile.path);
  }

  /// Сделать фото с камеры. Сокращение для pickImage(camera).
  Future<File?> fromCamera() => pickImage(ImageSource.camera);

  /// Выбрать из галереи. Сокращение для pickImage(gallery).
  Future<File?> fromGallery() => pickImage(ImageSource.gallery);

  // ─── Сжатие ─────────────────────────────────────────────────────────────────

  /// Сжать изображение в JPEG q75 в фоне (через compute isolate).
  /// Возвращает сжатые байты.
  Future<Uint8List> compressImage(File file) async {
    final rawBytes = await file.readAsBytes();
    final compressed = await compute(_compressImageIsolate, rawBytes);
    return Uint8List.fromList(compressed);
  }

  // ─── Загрузка в storage ───────────────────────────────────────────────────

  /// Загрузить файл в backend storage.
  ///
  /// [bucket] — бакет (по умолчанию reportsMediaBucket, как в complaint_form).
  /// [subpath] — подпапка (по умолчанию 'reports'; для бюро находок — 'lostfound').
  /// Возвращает публичный URL загруженного изображения.
  Future<String> uploadToStorage(
    File file, {
    String? bucket,
    String subpath = 'reports',
  }) async {
    final compressedBytes = await compressImage(file);

    final objectPath =
        '$subpath/${DateTime.now().toUtc().millisecondsSinceEpoch}_${math.Random().nextInt(1 << 32)}.jpg';
    final targetBucket = bucket ?? MapConfig.reportsMediaBucket;

    final response = await http
        .post(
          Uri.parse(MapConfig.storageUploadUrl(targetBucket, objectPath)),
          headers: {
            'Content-Type': 'image/jpeg',
            'x-upsert': 'false',
          },
          body: compressedBytes,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StorageUploadException(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }
    return MapConfig.storagePublicUrl(targetBucket, objectPath);
  }

  // ─── Полный пайплайн ─────────────────────────────────────────────────────────

  /// Пикер → сжатие → загрузка → URL. Удобный однострочник для форм.
  ///
  /// Возвращает URL загруженного фото, либо локальный file:// path если
  /// загрузка упала (offline-fallback, чтобы форма работала без сети).
  Future<String?> pickAndUpload(
    ImageSource source, {
    String subpath = 'reports',
  }) async {
    final file = await pickImage(source);
    if (file == null) return null;

    try {
      final url = await uploadToStorage(file, subpath: subpath);
      return url;
    } on StorageUploadException catch (e) {
      debugPrint('[PhotoService] upload failed, using local path: $e');
      // Offline-fallback: возвращаем file:// path для локального отображения
      return 'file://${file.path}';
    }
  }

  /// Локальный path для offline-сохранения.
  static String toLocalPath(File file) => 'file://${file.path}';

  /// Проверить, является ли URL локальным file:// путём.
  static bool isLocalPath(String? url) =>
      url != null && url.startsWith('file://');

  /// Получить File из file:// URL.
  static File? fileFromPath(String? url) {
    if (url == null || !isLocalPath(url)) return null;
    return File(url.replaceFirst('file://', ''));
  }
}

/// Top-level функция для compute() — сжимает изображение в isolate.
/// Должна быть top-level (не метод класса), чтобы быть serializable.
List<int> _compressImageIsolate(List<int> inputBytes) {
  try {
    final image = img.decodeImage(Uint8List.fromList(inputBytes));
    if (image == null) return inputBytes;

    img.Image resized = image;
    if (image.width > PhotoService.maxDimension ||
        image.height > PhotoService.maxDimension) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? PhotoService.maxDimension : null,
        height: image.height >= image.width ? PhotoService.maxDimension : null,
      );
    }

    return img.encodeJpg(resized, quality: PhotoService.jpegQuality);
  } catch (e) {
    return inputBytes;
  }
}
