import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../../core/constants/app_constants.dart';
import '../client/peer_api_client.dart';

class ClipboardSyncService {
  final _logger = Logger(printer: SimplePrinter());
  final PeerApiClient _apiClient;
  final String _deviceId;

  Timer? _pollTimer;
  String? _lastClipboardHash;
  bool _syncEnabled = false;

  // Track recently received clipboard content to prevent echo loops
  final Set<String> _recentlyReceived = {};

  // Peers to sync with: deviceId -> (ip, port)
  final Map<String, (String, int)> _syncTargets = {};

  final _clipboardReceivedController = StreamController<String>.broadcast();
  Stream<String> get clipboardReceivedStream => _clipboardReceivedController.stream;

  ClipboardSyncService({
    required PeerApiClient apiClient,
    required String deviceId,
  })  : _apiClient = apiClient,
        _deviceId = deviceId;

  bool get isEnabled => _syncEnabled;

  void updateSyncTargets(Map<String, (String, int)> targets) {
    _syncTargets.clear();
    _syncTargets.addAll(targets);
  }

  void start() {
    if (_syncEnabled) return;
    _syncEnabled = true;
    _pollTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.clipboardPollIntervalMs),
      (_) => _checkClipboard(),
    );
    _logger.i('Clipboard sync started');
  }

  void stop() {
    _syncEnabled = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _logger.i('Clipboard sync stopped');
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) return;

      final hash = md5.convert(utf8.encode(text)).toString();
      if (hash == _lastClipboardHash) return;

      // Skip if this was content we just received from a peer
      if (_recentlyReceived.contains(hash)) return;

      _lastClipboardHash = hash;
      _broadcastClipboard(text, hash);
    } catch (e) {
      // Clipboard access may fail if app is not focused
    }
  }

  Future<void> _broadcastClipboard(String text, String hash) async {
    for (final entry in _syncTargets.entries) {
      final (ip, port) = entry.value;
      await _apiClient.sendClipboard(
        ip: ip,
        port: port,
        clipboardData: {
          'senderId': _deviceId,
          'content': text,
          'hash': hash,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    }
  }

  /// Called when receiving clipboard data from a peer
  Future<void> onClipboardReceived(Map<String, dynamic> data) async {
    final content = data['content'] as String?;
    final hash = data['hash'] as String?;
    if (content == null || content.isEmpty) return;

    final computedHash = hash ?? md5.convert(utf8.encode(content)).toString();

    // Mark as received to prevent echo loop
    _recentlyReceived.add(computedHash);
    _lastClipboardHash = computedHash;

    // Set clipboard
    await Clipboard.setData(ClipboardData(text: content));
    _clipboardReceivedController.add(content);

    _logger.i('Clipboard received from peer: ${content.length} chars');

    // Clean up old entries after a delay
    Future.delayed(const Duration(seconds: 10), () {
      _recentlyReceived.remove(computedHash);
    });
  }

  void dispose() {
    stop();
    _clipboardReceivedController.close();
  }
}
