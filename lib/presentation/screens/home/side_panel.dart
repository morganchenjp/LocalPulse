import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/file_utils.dart';
import '../../../data/database/app_database.dart';
import '../../providers/app_providers.dart';

final clipboardSyncEnabledProvider = StateProvider<bool>((ref) => false);

class SidePanel extends ConsumerWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final transfersAsync = ref.watch(activeTransfersProvider);
    final clipboardEnabled = ref.watch(clipboardSyncEnabledProvider);
    final transfers = transfersAsync.valueOrNull ?? [];

    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          _SectionHeader(
            icon: Icons.swap_vert, title: 'Transfers', count: transfers.length,
            colorScheme: colorScheme, theme: theme,
          ),
          const Divider(height: 1),
          Expanded(
            flex: 1,
            child: transfers.isEmpty
                ? _EmptySection(
                    icon: Icons.cloud_upload_outlined,
                    label: 'No active transfers',
                    colorScheme: colorScheme, theme: theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: transfers.length,
                    itemBuilder: (context, index) => _TransferCard(
                      transfer: transfers[index],
                      colorScheme: colorScheme, theme: theme),
                  ),
          ),
          const Divider(height: 1),
          _SectionHeader(
            icon: Icons.content_paste, title: 'Clipboard',
            colorScheme: colorScheme, theme: theme,
            trailing: Switch(
              value: clipboardEnabled,
              onChanged: (v) {
                ref.read(clipboardSyncEnabledProvider.notifier).state = v;
                final clipSvc = ref.read(clipboardSyncServiceProvider);
                if (v) {
                  // Update sync targets from discovered peers
                  final peers = ref.read(discoveredPeersProvider).valueOrNull ?? {};
                  clipSvc.updateSyncTargets({
                    for (final e in peers.entries) e.key: (e.value.ipAddress, e.value.port),
                  });
                  clipSvc.start();
                } else {
                  clipSvc.stop();
                }
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 1,
            child: _EmptySection(
              icon: clipboardEnabled ? Icons.content_copy : Icons.content_paste_off,
              label: clipboardEnabled ? 'Listening for clipboard...' : 'Clipboard sync off',
              colorScheme: colorScheme, theme: theme),
          ),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final FileTransfer transfer;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _TransferCard({required this.transfer, required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    final progress = transfer.fileSize > 0
        ? transfer.bytesTransferred / transfer.fileSize
        : 0.0;
    final progressStr = '${FileUtils.formatFileSize(transfer.bytesTransferred)} / ${FileUtils.formatFileSize(transfer.fileSize)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  transfer.isOutgoing ? Icons.upload : Icons.download,
                  size: 16, color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(transfer.fileName,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 4),
            Text(progressStr,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _EmptySection({required this.icon, required this.label, required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;
  final Widget? trailing;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _SectionHeader({
    required this.icon, required this.title, this.count, this.trailing,
    required this.colorScheme, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onPrimaryContainer)),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
