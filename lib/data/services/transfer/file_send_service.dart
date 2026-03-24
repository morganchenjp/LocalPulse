import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import '../../../core/constants/app_constants.dart';
import '../client/peer_api_client.dart';

typedef OnTransferProgress = void Function(String transferId, int bytesSent, int totalBytes);
typedef OnTransferComplete = void Function(String transferId, String checksum);
typedef OnTransferFailed = void Function(String transferId, String error);

class FileSendService {
  final _logger = Logger(printer: SimplePrinter());
  final PeerApiClient _apiClient;

  FileSendService({required PeerApiClient apiClient}) : _apiClient = apiClient;

  /// Send a file to a peer using chunked upload.
  /// Returns the remote transferId on success, null on failure.
  Future<String?> sendFile({
    required String ip,
    required int port,
    required String filePath,
    required String senderId,
    required OnTransferProgress onProgress,
    required OnTransferComplete onComplete,
    required OnTransferFailed onFailed,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      onFailed('', 'File not found: $filePath');
      return null;
    }

    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();

    // Compute SHA-256 checksum
    final digest = await sha256.bind(file.openRead()).first;
    final checksum = digest.toString();

    // Step 1: Prepare transfer on receiver side
    final transferId = await _apiClient.prepareFileTransfer(
      ip: ip,
      port: port,
      fileInfo: {
        'senderId': senderId,
        'fileName': fileName,
        'fileSize': fileSize,
        'checksum': checksum,
      },
    );

    if (transferId == null) {
      onFailed('', 'Peer rejected file transfer');
      return null;
    }

    _logger.i('File transfer prepared: $transferId ($fileName, ${fileSize}B)');

    // Step 2: Send file in chunks
    try {
      int bytesSent = 0;
      final chunkSize = AppConstants.fileChunkSize;
      final raf = await file.open(mode: FileMode.read);

      while (bytesSent < fileSize) {
        final remaining = fileSize - bytesSent;
        final currentChunkSize = remaining < chunkSize ? remaining : chunkSize;

        // Read chunk into memory
        await raf.setPosition(bytesSent);
        final chunkData = await raf.read(currentChunkSize);

        final stream = Stream.value(chunkData);

        final success = await _apiClient.uploadFileChunk(
          ip: ip,
          port: port,
          transferId: transferId,
          dataStream: stream,
          length: currentChunkSize,
          onProgress: (sent, total) {
            onProgress(transferId, bytesSent + sent, fileSize);
          },
        );

        if (!success) {
          await raf.close();
          onFailed(transferId, 'Chunk upload failed at offset $bytesSent');
          return null;
        }

        bytesSent += currentChunkSize;
        onProgress(transferId, bytesSent, fileSize);
      }

      await raf.close();
      onComplete(transferId, checksum);
      _logger.i('File transfer complete: $transferId');
      return transferId;
    } catch (e) {
      onFailed(transferId, e.toString());
      _logger.e('File transfer error: $e');
      return null;
    }
  }
}
