import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/platform_utils.dart';

class InfoHandler {
  static Response handle(String deviceId) {
    final info = {
      'deviceId': deviceId,
      'deviceName': PlatformUtils.deviceName,
      'os': PlatformUtils.osType,
      'version': AppConstants.protocolVersion,
    };
    return Response.ok(
      jsonEncode(info),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
