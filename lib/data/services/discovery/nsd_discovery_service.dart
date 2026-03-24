import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/platform_utils.dart';

class DiscoveredPeer {
  final String deviceId;
  final String deviceName;
  final String os;
  final String ipAddress;
  final int port;

  DiscoveredPeer({
    required this.deviceId,
    required this.deviceName,
    required this.os,
    required this.ipAddress,
    required this.port,
  });

  @override
  String toString() => 'DiscoveredPeer($deviceName @ $ipAddress:$port)';
}

class NsdDiscoveryService {
  final _logger = Logger(printer: SimplePrinter());
  final String _deviceId;
  final int _serverPort;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  final _peersController = StreamController<Map<String, DiscoveredPeer>>.broadcast();
  final Map<String, DiscoveredPeer> _discoveredPeers = {};

  Stream<Map<String, DiscoveredPeer>> get peersStream => _peersController.stream;
  Map<String, DiscoveredPeer> get currentPeers => Map.unmodifiable(_discoveredPeers);

  NsdDiscoveryService({
    required String deviceId,
    required int serverPort,
    String? nickname,
  })  : _deviceId = deviceId,
        _serverPort = serverPort,
        _nickname = nickname;

  final String? _nickname;

  Future<void> startAdvertising() async {
    if (kIsWeb) return;

    final deviceName = _nickname?.isNotEmpty == true ? _nickname! : PlatformUtils.deviceName;
    final service = BonsoirService(
      name: '$deviceName-${_deviceId.substring(0, 4)}',
      type: AppConstants.serviceType,
      port: _serverPort,
      attributes: {
        'deviceId': _deviceId,
        'deviceName': deviceName,
        'os': PlatformUtils.osType,
        'version': '${AppConstants.protocolVersion}',
      },
    );

    try {
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      await _broadcast!.start();
      _logger.i('mDNS: Advertising as ${service.name} on port $_serverPort');
    } catch (e) {
      _logger.e('mDNS: Failed to start advertising: $e');
    }
  }

  Future<void> startDiscovery() async {
    if (kIsWeb) return;

    try {
      _discovery = BonsoirDiscovery(type: AppConstants.serviceType);
      await _discovery!.initialize();

      _discovery!.eventStream!.listen((event) {
        if (event is BonsoirDiscoveryServiceResolvedEvent) {
          _onServiceResolved(event.service);
        } else if (event is BonsoirDiscoveryServiceFoundEvent) {
          // Request resolution to get host/ip
          event.service.resolve(_discovery!.serviceResolver);
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          _onServiceLost(event.service);
        }
      });

      await _discovery!.start();
      _logger.i('mDNS: Started discovery for ${AppConstants.serviceType}');
    } catch (e) {
      _logger.e('mDNS: Failed to start discovery: $e');
    }
  }

  void _onServiceResolved(BonsoirService service) {
    final attrs = service.attributes;
    final deviceId = attrs['deviceId'];
    if (deviceId == null || deviceId == _deviceId) return;

    final deviceName = attrs['deviceName'] ?? service.name;
    final os = attrs['os'] ?? 'unknown';
    final host = service.host;
    final port = service.port;

    if (host == null || host.isEmpty) return;

    final peer = DiscoveredPeer(
      deviceId: deviceId,
      deviceName: deviceName,
      os: os,
      ipAddress: host,
      port: port,
    );

    _discoveredPeers[deviceId] = peer;
    _peersController.add(Map.from(_discoveredPeers));
    _logger.i('mDNS: Found peer: $peer');
  }

  void _onServiceLost(BonsoirService service) {
    final deviceId = service.attributes['deviceId'];
    if (deviceId != null) {
      _discoveredPeers.remove(deviceId);
      _peersController.add(Map.from(_discoveredPeers));
      _logger.i('mDNS: Lost peer: $deviceId');
    }
  }

  Future<void> stopAll() async {
    await _broadcast?.stop();
    _broadcast = null;
    await _discovery?.stop();
    _discovery = null;
    _discoveredPeers.clear();
    _logger.i('mDNS: Stopped all services');
  }

  void dispose() {
    stopAll();
    _peersController.close();
  }
}
