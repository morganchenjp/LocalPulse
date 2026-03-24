import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class FileOpener {
  FileOpener._();

  /// Open a file with the system's default application.
  static Future<bool> openFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final uri = Uri.file(filePath);
    return launchUrl(uri);
  }

  /// Open the system file manager with the file's parent folder.
  static Future<bool> showInFolder(String filePath) async {
    final file = File(filePath);
    final dir = file.parent.path;

    if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [dir]);
      return result.exitCode == 0;
    } else if (Platform.isMacOS) {
      final result = await Process.run('open', ['-R', filePath]);
      return result.exitCode == 0;
    } else if (Platform.isWindows) {
      final result = await Process.run('explorer', ['/select,', filePath]);
      return result.exitCode == 0;
    }
    return false;
  }

  /// Copy a file to a new location (Save As).
  static Future<bool> saveAs(String sourcePath, String destPath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return false;
      await source.copy(destPath);
      return true;
    } catch (_) {
      return false;
    }
  }
}
