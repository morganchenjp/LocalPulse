import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'nsd_discovery_service.dart';
import 'udp_broadcast_service.dart';

/// 混合发现服务 - 结合mDNS和UDP广播
///
/// 此服务同时使用mDNS（Bonsoir）和UDP广播来发现设备
/// - mDNS: 标准协议，跨平台兼容性好，但可能较慢
/// - UDP广播: 快速发现，作为mDNS的补充
///
/// 两种机制发现的设备会自动合并，提供更快的发现速度
class HybridDiscoveryService {
  final _logger = Logger(printer: SimplePrinter());

  final NsdDiscoveryService _nsdService;
  final UdpBroadcastService _udpService;

  final _peersController =
      StreamController<Map<String, DiscoveredPeer>>.broadcast();
  final Map<String, DiscoveredPeer> _allPeers = {};

  Stream<Map<String, DiscoveredPeer>> get peersStream =>
      _peersController.stream;
  Map<String, DiscoveredPeer> get currentPeers => Map.unmodifiable(_allPeers);

  HybridDiscoveryService({
    required String deviceId,
    required int serverPort,
    String? nickname,
  }) : _nsdService = NsdDiscoveryService(
         deviceId: deviceId,
         serverPort: serverPort,
         nickname: nickname,
       ),
       _udpService = UdpBroadcastService(
         deviceId: deviceId,
         serverPort: serverPort,
         nickname: nickname,
       );

  /// 启动所有发现服务
  Future<void> startAll() async {
    if (kIsWeb) return;

    _logger.i('Hybrid: Starting all discovery services...');

    // 订阅mDNS流
    _nsdService.peersStream.listen((peers) {
      _logger.d('Hybrid: mDNS peers update: ${peers.length} peers');
      _mergePeers(peers, 'mDNS');
    });

    // 订阅UDP广播流
    _udpService.peersStream.listen((peers) {
      _logger.d('Hybrid: UDP peers update: ${peers.length} peers');
      _mergePeers(peers, 'UDP');
    });

    // 启动mDNS
    await _nsdService.startAdvertising();
    await _nsdService.startDiscovery();

    // 启动UDP广播
    await _udpService.startBroadcasting();
    await _udpService.startListening();

    _logger.i('Hybrid: All discovery services started');
  }

  /// 合并来自不同源的peers
  void _mergePeers(Map<String, DiscoveredPeer> newPeers, String source) {
    bool updated = false;

    for (final entry in newPeers.entries) {
      final deviceId = entry.key;
      final peer = entry.value;

      // 如果peer不存在，或者来自不同源，则更新
      if (!_allPeers.containsKey(deviceId)) {
        _allPeers[deviceId] = peer;
        updated = true;
        _logger.i('Hybrid: New peer from $source: $peer');
      } else {
        // 如果peer已存在，更新信息（UDP广播可能提供更新的IP）
        _allPeers[deviceId] = peer;
        updated = true;
      }
    }

    // 如果有更新，通知监听者
    if (updated) {
      _peersController.add(Map.from(_allPeers));
    }
  }

  /// 停止所有服务
  Future<void> stopAll() async {
    _logger.i('Hybrid: Stopping all discovery services...');

    await _nsdService.stopAll();
    await _udpService.stopAll();

    _allPeers.clear();
    _logger.i('Hybrid: All services stopped');
  }

  void dispose() {
    stopAll();
    _peersController.close();
    _nsdService.dispose();
    _udpService.dispose();
  }
}
