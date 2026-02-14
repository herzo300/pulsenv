// lib/services/image_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Сервис для работы с изображениями
class ImageService {
  static final ImagePicker _picker = ImagePicker();
  
  /// Выбор фото из галереи
  static Future<Map<String, dynamic>?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _processImage(image);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }
  
  /// Сделать фото камерой
  static Future<Map<String, dynamic>?> captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (image != null) {
        return await _processImage(image);
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
    }
    return null;
  }
  
  /// Обработка изображения (EXIF + копирование)
  static Future<Map<String, dynamic>> _processImage(XFile image) async {
    final File file = File(image.path);
    final bytes = await file.readAsBytes();
    
    // Чтение EXIF
    final exifData = await readExifFromBytes(bytes);
    
    // Извлечение геоданных
    double? latitude;
    double? longitude;
    
    if (exifData.containsKey('GPS GPSLatitude') && 
        exifData.containsKey('GPS GPSLongitude')) {
      latitude = _parseGpsCoordinate(exifData['GPS GPSLatitude']);
      longitude = _parseGpsCoordinate(exifData['GPS GPSLongitude']);
      
      // Учет направления (N/S, E/W)
      if (exifData.containsKey('GPS GPSLatitudeRef')) {
        final ref = exifData['GPS GPSLatitudeRef']?.toString();
        if (ref == 'S') latitude = -latitude!;
      }
      if (exifData.containsKey('GPS GPSLongitudeRef')) {
        final ref = exifData['GPS GPSLongitudeRef']?.toString();
        if (ref == 'W') longitude = -longitude!;
      }
    }
    
    // Копирование в постоянное хранилище
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'complaint_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImage = await file.copy('${appDir.path}/$fileName');
    
    return {
      'path': savedImage.path,
      'original_path': image.path,
      'latitude': latitude,
      'longitude': longitude,
      'exif': exifData.map((key, value) => MapEntry(key, value.toString())),
      'size': bytes.length,
    };
  }
  
  /// Парсинг GPS координат из EXIF
  static double? _parseGpsCoordinate(IfdTag? tag) {
    if (tag == null) return null;
    
    try {
      final values = tag.values.toList();
      if (values.length >= 3) {
        final degrees = _toDouble(values[0]);
        final minutes = _toDouble(values[1]);
        final seconds = _toDouble(values[2]);
        return degrees + (minutes / 60.0) + (seconds / 3600.0);
      }
    } catch (e) {
      debugPrint('Error parsing GPS: $e');
    }
    return null;
  }
  
  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is Ratio) return value.toDouble();
    return 0.0;
  }
  
  /// Сжатие изображения
  static Future<File?> compressImage(File file, {int quality = 70}) async {
    try {
      // Используйте flutter_image_compress для лучшего сжатия
      // Сейчас просто возвращаем оригинал
      return file;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file;
    }
  }
  
  /// Удаление временных файлов
  static Future<void> cleanup() async {
    final tempDir = await getTemporaryDirectory();
    final files = tempDir.listSync();
    
    for (var file in files) {
      if (file is File && file.path.contains('image_picker')) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('Error deleting temp file: $e');
        }
      }
    }
  }
}
