import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/platform_utils.dart';
import 'nsd_discovery_service.dart';

/// UDP广播辅助服务 - 用于加速设备发现
///
/// mDNS在跨平台环境下可能较慢，此服务通过UDP广播作为补充机制
/// 可以显著加快设备发现速度
class UdpBroadcastService {
  final _logger = Logger(printer: SimplePrinter());
  final String _deviceId;
  final int _serverPort;
  final String? _nickname;

  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _receiveSocket;

  Timer? _broadcastTimer;

  final _peersController =
      StreamController<Map<String, DiscoveredPeer>>.broadcast();
  final Map<String, DiscoveredPeer> _discoveredPeers = {};

  Stream<Map<String, DiscoveredPeer>> get peersStream =>
      _peersController.stream;
  Map<String, DiscoveredPeer> get currentPeers =>
      Map.unmodifiable(_discoveredPeers);

  // UDP广播端口
  static const int broadcastPort = 53199;
  static const String broadcastAddress = '255.255.255.255';

  // 广播间隔（毫秒）- 每2秒发送一次
  static const int broadcastIntervalMs = 2000;

  UdpBroadcastService({
    required String deviceId,
    required int serverPort,
    String? nickname,
  }) : _deviceId = deviceId,
       _serverPort = serverPort,
       _nickname = nickname;

  /// 开始发送UDP广播宣告自己
  Future<void> startBroadcasting() async {
    if (kIsWeb) return;

    try {
      // 创建广播发送socket
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // 系统分配端口
      );
      _broadcastSocket!.broadcastEnabled = true;

      // 定期发送广播
      _broadcastTimer = Timer.periodic(
        const Duration(milliseconds: broadcastIntervalMs),
        (_) => _sendBroadcast(),
      );

      // 立即发送一次
      _sendBroadcast();

      _logger.i('UDP: Started broadcasting on port $broadcastPort');
    } catch (e) {
      _logger.e('UDP: Failed to start broadcasting: $e');
    }
  }

  /// 开始监听UDP广播
  Future<void> startListening() async {
    if (kIsWeb) return;

    try {
      // 创建接收socket
      _receiveSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        broadcastPort,
      );

      _receiveSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          _receiveBroadcast();
        }
      });

      _logger.i('UDP: Started listening on port $broadcastPort');
    } catch (e) {
      _logger.e('UDP: Failed to start listening: $e');
    }
  }

  /// 发送广播消息
  void _sendBroadcast() {
    if (_broadcastSocket == null) return;

    try {
      final deviceName = _nickname?.isNotEmpty == true
          ? _nickname!
          : PlatformUtils.deviceName;

      // 构建广播消息: deviceId|deviceName|os|port|version
      final message =
          '$_deviceId|$deviceName|${PlatformUtils.osType}|$_serverPort|${AppConstants.protocolVersion}';
      final data = message.codeUnits;

      _broadcastSocket!.send(
        data,
        InternetAddress(broadcastAddress),
        broadcastPort,
      );

      _logger.d('UDP: Broadcast sent: $message');
    } catch (e) {
      _logger.e('UDP: Failed to send broadcast: $e');
    }
  }

  /// 接收广播消息
  void _receiveBroadcast() {
    if (_receiveSocket == null) return;

    try {
      final datagram = _receiveSocket!.receive();
      if (datagram == null) return;

      final message = String.fromCharCodes(datagram.data);
      final parts = message.split('|');

      if (parts.length != 5) {
        _logger.w('UDP: Invalid message format: $message');
        return;
      }

      final deviceId = parts[0];
      final deviceName = parts[1];
      final os = parts[2];
      final port = int.tryParse(parts[3]) ?? 0;
      final version = int.tryParse(parts[4]) ?? 0;

      // 忽略自己
      if (deviceId == _deviceId) return;

      // 验证协议版本
      if (version != AppConstants.protocolVersion) {
        _logger.w(
          'UDP: Protocol version mismatch: $version (expected ${AppConstants.protocolVersion})',
        );
        return;
      }

      final peer = DiscoveredPeer(
        deviceId: deviceId,
        deviceName: deviceName,
        os: os,
        ipAddress: datagram.address.address,
        port: port,
      );

      // 只在新增或更新时通知
      if (!_discoveredPeers.containsKey(deviceId)) {
        _discoveredPeers[deviceId] = peer;
        _peersController.add(Map.from(_discoveredPeers));
        _logger.i('UDP: Found peer via broadcast: $peer');
      } else {
        // 更新现有peer
        _discoveredPeers[deviceId] = peer;
      }
    } catch (e) {
      _logger.e('UDP: Failed to receive broadcast: $e');
    }
  }

  /// 停止所有UDP服务
  Future<void> stopAll() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    _broadcastSocket?.close();
    _broadcastSocket = null;

    _receiveSocket?.close();
    _receiveSocket = null;

    _logger.i('UDP: Stopped all services');
  }

  void dispose() {
    stopAll();
    _peersController.close();
  }
}
