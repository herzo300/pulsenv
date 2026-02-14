// lib/lib/services/file_download_service.dart
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileDownloadService {
  static Future<String?> downloadFile({
    required String url,
    String? savedDir = 'downloads',
    String? fileName,
    bool showNotification = true,
    bool openFileFromNotification = true,
  }) async {
    try {
      final directory = await _getDirectory(savedDir);
      
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: directory,
        showNotification: showNotification,
        openFileFromNotification: openFileFromNotification,
        fileName: fileName,
      );

      return taskId;
    } catch (e) {
      throw Exception('Ошибка загрузки файла: $e');
    }
  }

  static Future<String> _getDirectory(String? savedDir) async {
    if (await Permission.storage.isGranted) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$savedDir';
    } else {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        final directory = await getApplicationDocumentsDirectory();
        return '${directory.path}/$savedDir';
      } else {
        throw Exception('Нет доступа к хранилищу');
      }
    }
  }

  static Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId);
  }

  static Future<void> pauseDownload(String taskId) async {
    await FlutterDownloader.pause(taskId);
  }

  static Future<void> resumeDownload(String taskId) async {
    await FlutterDownloader.resume(taskId);
  }
}
