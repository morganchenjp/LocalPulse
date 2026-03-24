import 'dart:io';

class PlatformUtils {
  PlatformUtils._();

  static String get osType {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  static String get deviceName {
    return Platform.localHostname;
  }

  static Future<String> getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.address.startsWith('127.')) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }
}
