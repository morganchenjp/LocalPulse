import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/platform_utils.dart';

class SettingsService {
  static const _keyNickname = 'device_nickname';
  static const _keyDownloadDir = 'download_directory';

  final SharedPreferences _prefs;

  SettingsService._(this._prefs);

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService._(prefs);
  }

  // ─── Device Nickname ───

  String get nickname => _prefs.getString(_keyNickname) ?? PlatformUtils.deviceName;

  Future<void> setNickname(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove(_keyNickname);
    } else {
      await _prefs.setString(_keyNickname, trimmed);
    }
  }

  bool get hasCustomNickname => _prefs.containsKey(_keyNickname);

  // ─── Download Directory ───

  String get downloadDir {
    return _prefs.getString(_keyDownloadDir) ?? _defaultDownloadDir;
  }

  Future<void> setDownloadDir(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove(_keyDownloadDir);
    } else {
      await _prefs.setString(_keyDownloadDir, trimmed);
    }
  }

  bool get hasCustomDownloadDir => _prefs.containsKey(_keyDownloadDir);

  static String get _defaultDownloadDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/LocalPulse';
  }
}
