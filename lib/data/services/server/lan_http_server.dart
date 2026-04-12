import 'dart:io';
import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../../../core/constants/protocol_constants.dart';
import 'handlers/info_handler.dart';
import 'handlers/message_handler.dart';
import 'handlers/file_handler.dart';
import 'handlers/clipboard_handler.dart';

class LanHttpServer {
  final _logger = Logger(printer: SimplePrinter());
  final String deviceId;
  final int port;
  final String bindAddress;
  final MessageHandler messageHandler;
  final FileHandler fileHandler;
  final ClipboardHandler clipboardHandler;

  HttpServer? _server;
  bool get isRunning => _server != null;

  LanHttpServer({
    required this.deviceId,
    required this.port,
    required this.bindAddress,
    required this.messageHandler,
    required this.fileHandler,
    required this.clipboardHandler,
  });

  Future<void> start() async {
    final router = Router();

    // Info endpoint
    router.get(ProtocolConstants.infoPath, (Request request) async {
      return InfoHandler.handle(deviceId);
    });

    // Message endpoint
    router.post(ProtocolConstants.messagePath, (Request request) async {
      return messageHandler.handle(request);
    });

    // File prepare endpoint
    router.post(ProtocolConstants.filePreparePath, (Request request) async {
      return fileHandler.handlePrepare(request);
    });

    // File upload endpoint
    router.post('${ProtocolConstants.fileUploadPath}/<transferId>',
        (Request request, String transferId) async {
      return fileHandler.handleUpload(request, transferId);
    });

    // File transfer cancel endpoint
    router.delete('${ProtocolConstants.fileTransferPath}/<transferId>',
        (Request request, String transferId) async {
      return fileHandler.handleCancel(request, transferId);
    });

    // Clipboard endpoint
    router.post(ProtocolConstants.clipboardPath, (Request request) async {
      return clipboardHandler.handle(request);
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests(logger: (msg, isError) {
          if (isError) {
            _logger.e(msg);
          }
        }))
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress(bindAddress), port);
    _logger.i('HTTP Server started on $bindAddress:$port');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _logger.i('HTTP Server stopped');
  }
}
