import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/file_opener.dart';
import '../../../core/utils/file_utils.dart';
import '../../../data/database/app_database.dart';
import '../../providers/app_providers.dart';
import 'home_screen.dart';

class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final FocusNode _inputFocusNode;

  @override
  void initState() {
    super.initState();
    _inputFocusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _sendMessage();
          return KeyEventResult.handled; // consume Enter, prevent duplicate
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final peerId = ref.read(selectedPeerIdProvider);
    if (peerId == null) return;

    final deviceId = ref.read(deviceIdProvider);
    final db = ref.read(databaseProvider);
    final apiClient = ref.read(apiClientProvider);

    final messageId = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Save to local DB
    await db.messageDao.insertMessage(MessagesCompanion(
      id: Value(messageId),
      peerId: Value(peerId),
      type: const Value('text'),
      content: Value(text),
      isOutgoing: const Value(true),
      status: const Value('sent'),
      createdAt: Value(timestamp),
    ));

    _controller.clear();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    // Send to peer via HTTP
    final peers = ref.read(discoveredPeersProvider).valueOrNull ?? {};
    final peer = peers[peerId];
    if (peer != null) {
      final success = await apiClient.sendMessage(
        ip: peer.ipAddress,
        port: peer.port,
        message: {
          'id': messageId,
          'senderId': deviceId,
          'type': 'text',
          'content': text,
          'timestamp': timestamp,
        },
      );

      if (success) {
        await db.messageDao.updateMessageStatus(messageId, 'delivered');
      } else {
        await db.messageDao.updateMessageStatus(messageId, 'failed');
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    final peerId = ref.read(selectedPeerIdProvider);
    if (peerId == null) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    final deviceId = ref.read(deviceIdProvider);
    final db = ref.read(databaseProvider);
    final fileSendService = ref.read(fileSendServiceProvider);

    final fileName = result.files.single.name;
    final fileSize = result.files.single.size;
    final transferId = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Insert a file message in chat
    final messageId = const Uuid().v4();
    await db.messageDao.insertMessage(MessagesCompanion(
      id: Value(messageId),
      peerId: Value(peerId),
      type: const Value('file'),
      content: Value(fileName),
      metadata: Value('$transferId|$fileSize'),
      isOutgoing: const Value(true),
      status: const Value('sent'),
      createdAt: Value(timestamp),
    ));

    // Insert transfer record
    await db.transferDao.insertTransfer(FileTransfersCompanion(
      id: Value(transferId),
      peerId: Value(peerId),
      fileName: Value(fileName),
      filePath: Value(filePath),
      fileSize: Value(fileSize),
      isOutgoing: const Value(true),
      status: const Value('transferring'),
      createdAt: Value(timestamp),
    ));

    // Get peer connection info
    final peers = ref.read(discoveredPeersProvider).valueOrNull ?? {};
    final peer = peers[peerId];
    if (peer == null) {
      await db.transferDao.updateStatus(transferId, 'failed');
      await db.messageDao.updateMessageStatus(messageId, 'failed');
      return;
    }

    // Send file in background
    await fileSendService.sendFile(
      ip: peer.ipAddress,
      port: peer.port,
      filePath: filePath,
      senderId: deviceId,
      onProgress: (tid, sent, total) async {
        await db.transferDao.updateProgress(transferId, sent);
      },
      onComplete: (tid, checksum) async {
        await db.transferDao.updateStatus(transferId, 'completed');
        await db.messageDao.updateMessageStatus(messageId, 'delivered');
      },
      onFailed: (tid, error) async {
        await db.transferDao.updateStatus(transferId, 'failed');
        await db.messageDao.updateMessageStatus(messageId, 'failed');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPeerId = ref.watch(selectedPeerIdProvider);
    final selectedPeerName = ref.watch(selectedPeerNameProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (selectedPeerId == null) {
      return _NoPeerSelected(theme: theme, colorScheme: colorScheme);
    }

    final messagesAsync = ref.watch(messagesForPeerProvider(selectedPeerId));

    return Column(
      children: [
        // Chat header
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Chat with ${selectedPeerName ?? 'Peer'}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text('No messages yet. Say hello!',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) => _MessageBubble(
                  message: messages[index],
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
        // Input area
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                tooltip: 'Send file',
                onPressed: _pickAndSendFile,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _inputFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send),
                tooltip: 'Send',
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _MessageBubble({required this.message, required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.isOutgoing;
    final timeStr = DateFormat.Hm().format(
      DateTime.fromMillisecondsSinceEpoch(message.createdAt),
    );

    // Different display based on message type
    if (message.type == 'file') {
      return _FileBubble(message: message, isOutgoing: isOutgoing,
        timeStr: timeStr, colorScheme: colorScheme, theme: theme);
    }
    if (message.type == 'clipboard') {
      return _ClipboardBubble(message: message, timeStr: timeStr,
        colorScheme: colorScheme, theme: theme);
    }

    // Text message bubble
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isOutgoing) const Spacer(flex: 2),
          Flexible(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isOutgoing ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
                  bottomRight: Radius.circular(isOutgoing ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.content ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isOutgoing ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timeStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: (isOutgoing ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant)
                              .withValues(alpha: 0.6),
                          fontSize: 10)),
                      if (isOutgoing) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.status == 'delivered' ? Icons.done_all :
                          message.status == 'failed' ? Icons.error_outline : Icons.done,
                          size: 12,
                          color: message.status == 'failed' ? colorScheme.error :
                            colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isOutgoing) const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _FileBubble extends ConsumerWidget {
  final Message message;
  final bool isOutgoing;
  final String timeStr;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _FileBubble({required this.message, required this.isOutgoing,
    required this.timeStr, required this.colorScheme, required this.theme});

  String? _getTransferId() {
    if (message.metadata != null && message.metadata!.contains('|')) {
      return message.metadata!.split('|').first;
    }
    return null;
  }

  Future<String?> _getFilePath(WidgetRef ref) async {
    final transferId = _getTransferId();
    if (transferId == null) return null;
    final db = ref.read(databaseProvider);
    final transfer = await db.transferDao.getTransfer(transferId);
    return transfer?.filePath;
  }

  void _showContextMenu(BuildContext context, WidgetRef ref, Offset position) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 'open', child: Row(children: [
          Icon(Icons.open_in_new, size: 18), SizedBox(width: 8), Text('Open'),
        ])),
        const PopupMenuItem(value: 'folder', child: Row(children: [
          Icon(Icons.folder_open, size: 18), SizedBox(width: 8), Text('Show in Folder'),
        ])),
        const PopupMenuItem(value: 'saveas', child: Row(children: [
          Icon(Icons.save_alt, size: 18), SizedBox(width: 8), Text('Save As...'),
        ])),
      ],
    ).then((value) async {
      if (value == null) return;
      final filePath = await _getFilePath(ref);
      if (filePath == null || !context.mounted) return;

      switch (value) {
        case 'open':
          await FileOpener.openFile(filePath);
        case 'folder':
          await FileOpener.showInFolder(filePath);
        case 'saveas':
          final dest = await FilePicker.platform.saveFile(
            dialogTitle: 'Save As',
            fileName: message.content ?? 'file',
          );
          if (dest != null) {
            await FileOpener.saveAs(filePath, dest);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved to $dest'), duration: const Duration(seconds: 2)),
              );
            }
          }
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = message.content ?? 'Unknown file';
    String sizeStr = '';
    if (message.metadata != null && message.metadata!.contains('|')) {
      final parts = message.metadata!.split('|');
      if (parts.length >= 2) {
        final size = int.tryParse(parts[1]);
        if (size != null) sizeStr = FileUtils.formatFileSize(size);
      }
    }

    final statusIcon = message.status == 'delivered'
        ? Icons.done_all
        : message.status == 'failed'
            ? Icons.error_outline
            : Icons.hourglass_bottom;

    // Only enable interactions for incoming completed files
    final isInteractable = !isOutgoing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isOutgoing) const Spacer(flex: 2),
          Flexible(
            flex: 5,
            child: GestureDetector(
              onDoubleTap: isInteractable ? () async {
                final filePath = await _getFilePath(ref);
                if (filePath != null) await FileOpener.openFile(filePath);
              } : null,
              onSecondaryTapUp: isInteractable ? (details) {
                _showContextMenu(context, ref, details.globalPosition);
              } : null,
              child: MouseRegion(
                cursor: isInteractable ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insert_drive_file, color: colorScheme.primary, size: 28),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fileName, style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (sizeStr.isNotEmpty)
                                  Text('$sizeStr  ', style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 10)),
                                Text(timeStr, style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10)),
                                if (isOutgoing) ...[
                                  const SizedBox(width: 4),
                                  Icon(statusIcon, size: 12,
                                    color: message.status == 'failed' ? colorScheme.error : colorScheme.onSurfaceVariant),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isOutgoing) const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _ClipboardBubble extends StatelessWidget {
  final Message message;
  final String timeStr;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _ClipboardBubble({required this.message, required this.timeStr,
    required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.content_paste, size: 14, color: colorScheme.tertiary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Clipboard: ${message.content ?? ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onTertiaryContainer),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(timeStr, style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onTertiaryContainer.withValues(alpha: 0.6), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPeerSelected extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _NoPeerSelected({required this.theme, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Select a peer to start chatting',
            style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Choose a device from the left panel\nto send messages, files, or sync clipboard',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
