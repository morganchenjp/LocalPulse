import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:logger/logger.dart';

typedef OnMessageReceived = void Function(Map<String, dynamic> messageData);

class MessageHandler {
  final _logger = Logger(printer: SimplePrinter());
  final OnMessageReceived onMessageReceived;

  MessageHandler({required this.onMessageReceived});

  Future<Response> handle(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final requiredFields = ['id', 'senderId', 'type', 'content', 'timestamp'];
      for (final field in requiredFields) {
        if (!data.containsKey(field)) {
          return Response(400,
            body: jsonEncode({'status': 'error', 'message': 'Missing field: $field'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      onMessageReceived(data);

      return Response.ok(
        jsonEncode({'status': 'ok'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _logger.e('MessageHandler error: $e');
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
