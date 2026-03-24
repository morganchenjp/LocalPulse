import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:logger/logger.dart';

typedef OnClipboardReceived = void Function(Map<String, dynamic> clipboardData);

class ClipboardHandler {
  final _logger = Logger(printer: SimplePrinter());
  final OnClipboardReceived onClipboardReceived;

  ClipboardHandler({required this.onClipboardReceived});

  Future<Response> handle(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      onClipboardReceived(data);

      return Response.ok(
        jsonEncode({'status': 'ok'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _logger.e('ClipboardHandler error: $e');
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
