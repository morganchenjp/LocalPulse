import 'dart:io';
import '../constants/app_constants.dart';

class NetworkUtils {
  NetworkUtils._();

  static Future<int> findAvailablePort({
    int min = AppConstants.defaultPortMin,
    int max = AppConstants.defaultPortMax,
  }) async {
    for (var port = min; port <= max; port++) {
      try {
        final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
        await server.close();
        return port;
      } on SocketException {
        continue;
      }
    }
    // Fallback: let OS assign a port
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }
}
