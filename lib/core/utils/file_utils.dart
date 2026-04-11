import 'dart:io';
import 'package:mime/mime.dart';

class FileUtils {
  FileUtils._();

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String getMimeType(String filePath) {
    return lookupMimeType(filePath) ?? 'application/octet-stream';
  }

  static String? _customDownloadDir;

  static void setDownloadDirectory(String? path) {
    _customDownloadDir = path;
  }

  static Future<String> getDownloadDirectory() async {
    if (_customDownloadDir != null && _customDownloadDir!.isNotEmpty) {
      final dir = Directory(_customDownloadDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    }
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final dir = Directory('$home/LocalPulse');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }
}
