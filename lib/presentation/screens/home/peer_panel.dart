import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import 'home_screen.dart';

class PeerPanel extends ConsumerWidget {
  final void Function(String peerId, String peerName) onPeerSelected;

  const PeerPanel({super.key, required this.onPeerSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final peersAsync = ref.watch(discoveredPeersProvider);
    final dbPeersAsync = ref.watch(dbPeersProvider);
    final selectedPeerId = ref.watch(selectedPeerIdProvider);

    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Logo and Title Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: colorScheme.primary,
                          child: Icon(
                            Icons.wifi_tethering,
                            color: colorScheme.onPrimary,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LocalPulse',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      peersAsync.when(
                        data: (peers) => Text(
                          '${peers.length} peer${peers.length == 1 ? '' : 's'} online',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        loading: () => Text(
                          'Discovering peers...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                        error: (_, _) => Text(
                          'Discovery error',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildPeerList(
              context,
              ref,
              peersAsync,
              dbPeersAsync,
              selectedPeerId,
              colorScheme,
              theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, dynamic>> peersAsync,
    AsyncValue<List<dynamic>> dbPeersAsync,
    String? selectedPeerId,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final discoveredPeers = peersAsync.valueOrNull ?? {};
    final dbPeers = dbPeersAsync.valueOrNull ?? [];
    final allPeers = <String, _PeerInfo>{};

    for (final entry in discoveredPeers.entries) {
      final peer = entry.value;
      allPeers[entry.key] = _PeerInfo(
        id: peer.deviceId,
        name: peer.deviceName,
        os: peer.os,
        isOnline: true,
        ip: peer.ipAddress,
        port: peer.port,
      );
    }
    for (final peer in dbPeers) {
      if (!allPeers.containsKey(peer.id)) {
        allPeers[peer.id] = _PeerInfo(
          id: peer.id,
          name: peer.deviceName,
          os: peer.os,
          isOnline: false,
          ip: peer.ipAddress,
          port: peer.port,
        );
      }
    }

    if (allPeers.isEmpty) {
      return _EmptyPeerState(colorScheme: colorScheme, theme: theme);
    }

    final sorted = allPeers.values.toList()
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final peer = sorted[index];
        return _PeerTile(
          peer: peer,
          isSelected: peer.id == selectedPeerId,
          onTap: () => onPeerSelected(peer.id, peer.name),
          colorScheme: colorScheme,
          theme: theme,
        );
      },
    );
  }
}

class _PeerInfo {
  final String id, name, os;
  final bool isOnline;
  final String? ip;
  final int? port;
  _PeerInfo({
    required this.id,
    required this.name,
    required this.os,
    required this.isOnline,
    this.ip,
    this.port,
  });
}

class _PeerTile extends StatelessWidget {
  final _PeerInfo peer;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _PeerTile({
    required this.peer,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.theme,
  });

  IconData _osIcon(String os) => switch (os) {
    'windows' => Icons.desktop_windows,
    'macos' => Icons.laptop_mac,
    'linux' => Icons.computer,
    'android' => Icons.phone_android,
    _ => Icons.devices,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: peer.isOnline
                      ? Colors.green.shade600
                      : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                _osIcon(peer.os),
                size: 20,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      peer.isOnline
                          ? '${peer.os} - ${peer.ip}'
                          : '${peer.os} (offline)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPeerState extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;
  const _EmptyPeerState({required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_other,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Scanning LAN...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Devices running LocalPulse\nwill appear here',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
