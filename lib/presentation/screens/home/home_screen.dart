import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/file_utils.dart';
import '../../providers/app_providers.dart';
import '../../widgets/app_top_bar.dart';
import 'peer_panel.dart';
import 'chat_panel.dart';
import 'side_panel.dart';

final selectedPeerIdProvider = StateProvider<String?>((ref) => null);
final selectedPeerNameProvider = StateProvider<String?>((ref) => null);
final sidePanelExpandedProvider = StateProvider<bool>((ref) => true);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // Load user settings from SharedPreferences
      final settings = await ref.read(settingsServiceProvider.future);
      ref.read(nicknameProvider.notifier).state = settings.nickname;
      ref.read(downloadDirProvider.notifier).state = settings.downloadDir;
      FileUtils.setDownloadDirectory(settings.hasCustomDownloadDir ? settings.downloadDir : null);

      // Initialize server and discovery
      ref.read(httpServerProvider);
      ref.read(discoveryServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showSidePanel = screenWidth >= 1200;
    final sidePanelExpanded = ref.watch(sidePanelExpandedProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(),
          Expanded(
            child: Row(
              children: [
                // Left: Peer Panel
                SizedBox(
                  width: 260,
                  child: PeerPanel(
                    onPeerSelected: (peerId, peerName) {
                      ref.read(selectedPeerIdProvider.notifier).state = peerId;
                      ref.read(selectedPeerNameProvider.notifier).state = peerName;
                    },
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                // Center: Chat Panel
                const Expanded(
                  child: ChatPanel(),
                ),
                // Right: Side Panel (collapsible)
                if (showSidePanel && sidePanelExpanded) ...[
                  const VerticalDivider(width: 1, thickness: 1),
                  const SizedBox(
                    width: 280,
                    child: SidePanel(),
                  ),
                ],
              ],
            ),
          ),
          _StatusBar(showSidePanel: showSidePanel),
        ],
      ),
      floatingActionButton: !showSidePanel
          ? FloatingActionButton.small(
              onPressed: () => _showSidePanelSheet(context),
              child: const Icon(Icons.swap_horiz),
            )
          : null,
    );
  }

  void _showSidePanelSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => const SidePanel(),
      ),
    );
  }
}

class _StatusBar extends ConsumerWidget {
  final bool showSidePanel;

  const _StatusBar({required this.showSidePanel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final serverStatus = ref.watch(serverStatusProvider);
    final peersAsync = ref.watch(discoveredPeersProvider);
    final peerCount = peersAsync.valueOrNull?.length ?? 0;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              serverStatus,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Text(
            '$peerCount peer${peerCount == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (!showSidePanel) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: () => ref.read(sidePanelExpandedProvider.notifier).state =
                  !ref.read(sidePanelExpandedProvider),
              child: Icon(
                Icons.view_sidebar_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
