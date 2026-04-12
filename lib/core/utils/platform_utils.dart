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

  /// Returns true if the address is a private LAN address
  /// (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
  static bool _isPrivateLanAddress(String address) {
    if (address.startsWith('192.168.')) return true;
    if (address.startsWith('10.')) return true;
    if (address.startsWith('172.')) {
      final secondOctet = int.tryParse(address.split('.')[1]) ?? 0;
      return secondOctet >= 16 && secondOctet <= 31;
    }
    return false;
  }

  static Future<String> getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    String? bestAddress;

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        final address = addr.address;

        // Skip loopback
        if (address.startsWith('127.')) continue;

        // Prefer private LAN addresses
        if (_isPrivateLanAddress(address)) {
          return address;
        }

        // Fall back to first non-loopback, non-public address
        if (bestAddress == null && !_isPublicAddress(address)) {
          bestAddress = address;
        }
      }
    }

    return bestAddress ?? '127.0.0.1';
  }

  /// Returns true if the address appears to be a public/external IP
  static bool _isPublicAddress(String address) {
    // Quick heuristics: if it doesn't look like a private LAN address
    // and is not in 169.254.x.x (link-local), consider it potentially public
    if (address.startsWith('169.254.')) return false;
    return !_isPrivateLanAddress(address);
  }
}
