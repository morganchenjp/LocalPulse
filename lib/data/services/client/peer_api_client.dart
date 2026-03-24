import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../../core/constants/protocol_constants.dart';

class PeerApiClient {
  final _logger = Logger(printer: SimplePrinter());
  final Dio _dio;

  PeerApiClient()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ));

  String _baseUrl(String ip, int port) => 'http://$ip:$port';

  Future<Map<String, dynamic>?> getInfo(String ip, int port) async {
    try {
      final response = await _dio.get(
        '${_baseUrl(ip, port)}${ProtocolConstants.infoPath}',
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Failed to get info from $ip:$port: $e');
      return null;
    }
  }

  Future<bool> sendMessage({
    required String ip,
    required int port,
    required Map<String, dynamic> message,
  }) async {
    try {
      final response = await _dio.post(
        '${_baseUrl(ip, port)}${ProtocolConstants.messagePath}',
        data: jsonEncode(message),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return response.data['status'] == 'ok';
    } catch (e) {
      _logger.e('Failed to send message to $ip:$port: $e');
      return false;
    }
  }

  Future<String?> prepareFileTransfer({
    required String ip,
    required int port,
    required Map<String, dynamic> fileInfo,
  }) async {
    try {
      final response = await _dio.post(
        '${_baseUrl(ip, port)}${ProtocolConstants.filePreparePath}',
        data: jsonEncode(fileInfo),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.data['status'] == 'accepted') {
        return response.data['transferId'] as String;
      }
      return null;
    } catch (e) {
      _logger.e('Failed to prepare file transfer: $e');
      return null;
    }
  }

  Future<bool> uploadFileChunk({
    required String ip,
    required int port,
    required String transferId,
    required Stream<List<int>> dataStream,
    required int length,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final response = await _dio.post(
        '${_baseUrl(ip, port)}${ProtocolConstants.fileUploadPath}/$transferId',
        data: dataStream,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': length,
          },
        ),
        onSendProgress: onProgress,
      );
      return response.data['status'] == 'ok' ||
          response.data['status'] == 'complete';
    } catch (e) {
      _logger.e('Failed to upload file chunk: $e');
      return false;
    }
  }

  Future<bool> sendClipboard({
    required String ip,
    required int port,
    required Map<String, dynamic> clipboardData,
  }) async {
    try {
      final response = await _dio.post(
        '${_baseUrl(ip, port)}${ProtocolConstants.clipboardPath}',
        data: jsonEncode(clipboardData),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return response.data['status'] == 'ok';
    } catch (e) {
      _logger.e('Failed to send clipboard to $ip:$port: $e');
      return false;
    }
  }

  void dispose() {
    _dio.close();
  }
}
