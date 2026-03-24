import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/file_utils.dart';

typedef OnFileTransferRequest = void Function(Map<String, dynamic> transferData);
typedef OnFileChunkReceived = void Function(String transferId, List<int> chunk, int totalReceived);
typedef OnFileTransferCancel = void Function(String transferId);

class FileHandler {
  final _logger = Logger(printer: SimplePrinter());
  final OnFileTransferRequest onPrepare;
  final OnFileChunkReceived onChunkReceived;
  final OnFileTransferCancel onCancel;

  final Map<String, _ActiveReceive> _activeReceives = {};

  FileHandler({
    required this.onPrepare,
    required this.onChunkReceived,
    required this.onCancel,
  });

  Future<Response> handlePrepare(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final transferId = const Uuid().v4();
      final downloadDir = await FileUtils.getDownloadDirectory();
      final filePath = '$downloadDir/${data['fileName']}';

      _activeReceives[transferId] = _ActiveReceive(
        filePath: filePath,
        expectedSize: data['fileSize'] as int,
        checksum: data['checksum'] as String?,
      );

      data['transferId'] = transferId;
      data['filePath'] = filePath;
      onPrepare(data);

      return Response.ok(
        jsonEncode({'status': 'accepted', 'transferId': transferId}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _logger.e('FileHandler prepare error: $e');
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> handleUpload(Request request, String transferId) async {
    try {
      final receive = _activeReceives[transferId];
      if (receive == null) {
        return Response(404,
          body: jsonEncode({'status': 'error', 'message': 'Unknown transfer'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final tmpPath = '${receive.filePath}.lanshare_tmp';
      final file = File(tmpPath);
      final sink = file.openWrite(mode: FileMode.append);

      int bytesReceived = receive.bytesReceived;
      await for (final chunk in request.read()) {
        sink.add(chunk);
        bytesReceived += chunk.length;
      }
      await sink.close();

      receive.bytesReceived = bytesReceived;
      onChunkReceived(transferId, [], bytesReceived);

      if (bytesReceived >= receive.expectedSize) {
        // Transfer complete - rename from tmp
        await File(tmpPath).rename(receive.filePath);
        _activeReceives.remove(transferId);

        return Response.ok(
          jsonEncode({
            'status': 'complete',
            'bytesReceived': bytesReceived,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({'status': 'ok', 'bytesReceived': bytesReceived}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _logger.e('FileHandler upload error: $e');
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> handleCancel(Request request, String transferId) async {
    final receive = _activeReceives.remove(transferId);
    if (receive != null) {
      // Clean up tmp file
      final tmpFile = File('${receive.filePath}.lanshare_tmp');
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    }
    onCancel(transferId);
    return Response.ok(
      jsonEncode({'status': 'cancelled'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

class _ActiveReceive {
  final String filePath;
  final int expectedSize;
  final String? checksum;
  int bytesReceived = 0;

  _ActiveReceive({
    required this.filePath,
    required this.expectedSize,
    this.checksum,
  });
}
