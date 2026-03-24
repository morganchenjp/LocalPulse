import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final serverStatus = ref.watch(serverStatusProvider);
    final localIp = ref.watch(localIpProvider).valueOrNull ?? '...';
    final port = ref.watch(serverPortProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // About section
          _sectionTitle('About', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lan_outlined, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('${AppConstants.appName} v${AppConstants.version}',
                        style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('LAN file sharing, messaging & clipboard sync',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Network section
          _sectionTitle('Network', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Status', serverStatus, theme, colorScheme),
                  const SizedBox(height: 8),
                  _infoRow('Local IP', localIp, theme, colorScheme),
                  const SizedBox(height: 8),
                  _infoRow('Port', '$port', theme, colorScheme),
                  const SizedBox(height: 8),
                  _infoRow('Protocol', 'v${AppConstants.protocolVersion}', theme, colorScheme),
                  const SizedBox(height: 8),
                  _infoRow('Service Type', AppConstants.serviceType, theme, colorScheme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // File Transfer section
          _sectionTitle('File Transfer', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Chunk Size', FileUtils.formatFileSize(AppConstants.fileChunkSize), theme, colorScheme),
                  const SizedBox(height: 8),
                  _infoRow('Download Dir', '~/LANShare/', theme, colorScheme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Device section
          _sectionTitle('Device', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Device ID', ref.watch(deviceIdProvider).substring(0, 8), theme, colorScheme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Flexible(
          child: Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
