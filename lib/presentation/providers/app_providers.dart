import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/network_utils.dart';
import '../../core/utils/platform_utils.dart';
import '../../data/database/app_database.dart';
import '../../data/services/client/peer_api_client.dart';
import '../../data/services/discovery/nsd_discovery_service.dart';
import '../../data/services/clipboard/clipboard_sync_service.dart';
import '../../data/services/server/lan_http_server.dart';
import '../../data/services/server/handlers/message_handler.dart';
import '../../data/services/server/handlers/file_handler.dart';
import '../../data/services/server/handlers/clipboard_handler.dart';
import '../../data/services/transfer/file_send_service.dart';

// ─── Settings Service ───

final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  return SettingsService.create();
});

// ─── User Settings (reactive state, synced with SharedPreferences) ───

final nicknameProvider = StateProvider<String>((ref) => '');
final downloadDirProvider = StateProvider<String>((ref) => '');

// ─── Device Identity ───

final deviceIdProvider = Provider<String>((ref) {
  // In a real app, this would be persisted to SharedPreferences
  return const Uuid().v4();
});

// ─── Database ───

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

// ─── API Client ───

final apiClientProvider = Provider<PeerApiClient>((ref) {
  final client = PeerApiClient();
  ref.onDispose(() => client.dispose());
  return client;
});

// ─── Server Port ───

final serverPortProvider = FutureProvider<int>((ref) async {
  if (kIsWeb) return 0;
  return NetworkUtils.findAvailablePort();
});

// ─── Local IP ───

final localIpProvider = FutureProvider<String>((ref) async {
  if (kIsWeb) return '127.0.0.1';
  return PlatformUtils.getLocalIpAddress();
});

// ─── Message Handling ───

final _incomingMessageController =
    StreamController<Map<String, dynamic>>.broadcast();

final incomingMessageStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  return _incomingMessageController.stream;
});

// ─── Clipboard Handling ───

final _incomingClipboardController =
    StreamController<Map<String, dynamic>>.broadcast();

final incomingClipboardStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  return _incomingClipboardController.stream;
});

// ─── HTTP Server ───

final httpServerProvider = FutureProvider<LanHttpServer?>((ref) async {
  if (kIsWeb) return null;

  final port = await ref.watch(serverPortProvider.future);
  final deviceId = ref.read(deviceIdProvider);

  final messageHandler = MessageHandler(
    onMessageReceived: (data) async {
      _incomingMessageController.add(data);

      // Persist to DB
      final db = ref.read(databaseProvider);
      await db.messageDao.insertMessage(MessagesCompanion(
        id: Value(data['id'] as String),
        peerId: Value(data['senderId'] as String),
        type: Value(data['type'] as String? ?? 'text'),
        content: Value(data['content'] as String?),
        isOutgoing: const Value(false),
        status: const Value('delivered'),
        createdAt: Value(data['timestamp'] as int? ??
            DateTime.now().millisecondsSinceEpoch),
      ));
    },
  );

  final fileHandler = FileHandler(
    onPrepare: (data) async {
      final db = ref.read(databaseProvider);
      final transferId = data['transferId'] as String;
      final senderId = data['senderId'] as String;
      final fileName = data['fileName'] as String;
      final fileSize = data['fileSize'] as int;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Store transfer record
      await db.transferDao.insertTransfer(FileTransfersCompanion(
        id: Value(transferId),
        peerId: Value(senderId),
        fileName: Value(fileName),
        filePath: Value(data['filePath'] as String?),
        fileSize: Value(fileSize),
        isOutgoing: const Value(false),
        status: const Value('transferring'),
        checksum: Value(data['checksum'] as String?),
        createdAt: Value(timestamp),
      ));

      // Also add a file message in chat
      await db.messageDao.insertMessage(MessagesCompanion(
        id: Value(transferId),
        peerId: Value(senderId),
        type: const Value('file'),
        content: Value(fileName),
        metadata: Value('$transferId|$fileSize'),
        isOutgoing: const Value(false),
        status: const Value('sent'),
        createdAt: Value(timestamp),
      ));
    },
    onChunkReceived: (transferId, _, bytesReceived) async {
      final db = ref.read(databaseProvider);
      await db.transferDao.updateProgress(transferId, bytesReceived);
    },
    onCancel: (transferId) async {
      final db = ref.read(databaseProvider);
      await db.transferDao.updateStatus(transferId, 'cancelled');
      await db.messageDao.updateMessageStatus(transferId, 'failed');
    },
  );

  final clipboardHandler = ClipboardHandler(
    onClipboardReceived: (data) {
      _incomingClipboardController.add(data);
      // Forward to clipboard sync service for auto-paste
      final clipSvc = ref.read(clipboardSyncServiceProvider);
      clipSvc.onClipboardReceived(data);
    },
  );

  final server = LanHttpServer(
    deviceId: deviceId,
    port: port,
    messageHandler: messageHandler,
    fileHandler: fileHandler,
    clipboardHandler: clipboardHandler,
  );

  await server.start();
  ref.onDispose(() => server.stop());
  return server;
});

// ─── Discovery Service ───

final discoveryServiceProvider =
    FutureProvider<NsdDiscoveryService?>((ref) async {
  if (kIsWeb) return null;

  final port = await ref.watch(serverPortProvider.future);
  final deviceId = ref.read(deviceIdProvider);

  final nickname = ref.read(nicknameProvider);

  final service = NsdDiscoveryService(
    deviceId: deviceId,
    serverPort: port,
    nickname: nickname.isNotEmpty ? nickname : null,
  );

  await service.startAdvertising();
  await service.startDiscovery();

  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Discovered Peers Stream ───

final discoveredPeersProvider =
    StreamProvider<Map<String, DiscoveredPeer>>((ref) async* {
  final service = await ref.watch(discoveryServiceProvider.future);
  if (service == null) {
    yield {};
    return;
  }
  yield service.currentPeers;
  yield* service.peersStream;
});

// ─── Peers from DB ───

final dbPeersProvider = StreamProvider<List<Peer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.peerDao.watchAllPeers();
});

// ─── Messages for Peer ───

final messagesForPeerProvider =
    StreamProvider.family<List<Message>, String>((ref, peerId) {
  final db = ref.watch(databaseProvider);
  return db.messageDao.watchMessagesForPeer(peerId);
});

// ─── Active Transfers ───

final activeTransfersProvider = StreamProvider<List<FileTransfer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.transferDao.watchActiveTransfers();
});

// ─── File Send Service ───

final fileSendServiceProvider = Provider<FileSendService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return FileSendService(apiClient: apiClient);
});

// ─── Clipboard Sync Service ───

final clipboardSyncServiceProvider = Provider<ClipboardSyncService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final deviceId = ref.read(deviceIdProvider);
  final service = ClipboardSyncService(apiClient: apiClient, deviceId: deviceId);
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Server Status ───

final serverStatusProvider = Provider<String>((ref) {
  final serverAsync = ref.watch(httpServerProvider);
  final ipAsync = ref.watch(localIpProvider);
  final portAsync = ref.watch(serverPortProvider);

  return serverAsync.when(
    data: (server) {
      if (server == null) return 'Web mode (no server)';
      final ip = ipAsync.valueOrNull ?? '...';
      final port = portAsync.valueOrNull ?? 0;
      return 'Server running on $ip:$port';
    },
    loading: () => 'Starting server...',
    error: (e, _) => 'Server error: $e',
  );
});
