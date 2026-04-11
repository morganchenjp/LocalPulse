import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nicknameController;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: ref.read(nicknameProvider));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    final settings = await ref.read(settingsServiceProvider.future);
    final name = _nicknameController.text.trim();
    await settings.setNickname(name);
    ref.read(nicknameProvider.notifier).state = name.isEmpty ? settings.nickname : name;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(name.isEmpty
              ? 'Nickname reset to default (requires restart to update mDNS)'
              : 'Nickname saved (requires restart to update mDNS)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickDownloadDir() async {
    final result = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose download folder',
    );
    if (result == null) return;

    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setDownloadDir(result);
    ref.read(downloadDirProvider.notifier).state = result;
    FileUtils.setDownloadDirectory(result);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download folder set to: $result'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _resetDownloadDir() async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setDownloadDir('');
    final defaultDir = settings.downloadDir;
    ref.read(downloadDirProvider.notifier).state = defaultDir;
    FileUtils.setDownloadDirectory(null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download folder reset to default: $defaultDir'), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final serverStatus = ref.watch(serverStatusProvider);
    final localIp = ref.watch(localIpProvider).valueOrNull ?? '...';
    final port = ref.watch(serverPortProvider).valueOrNull ?? 0;
    final downloadDir = ref.watch(downloadDirProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // About
          _sectionTitle('About', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Image.asset('assets/logo.png', height: 24, width: 24),
                    const SizedBox(width: 8),
                    Text('${AppConstants.appName} v${AppConstants.version}',
                        style: theme.textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 4),
                  Text('LAN file sharing, messaging & clipboard sync',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Device
          _sectionTitle('Device', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nickname', style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          hintText: 'Device name shown to other peers',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _saveNickname(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _saveNickname,
                      child: const Text('Save'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _infoRow('Device ID',
                      ref.watch(deviceIdProvider).substring(0, 8),
                      theme, colorScheme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // File Transfer
          _sectionTitle('File Transfer', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Download Folder', style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.folder_outlined, size: 18,
                          color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(downloadDir,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    FilledButton.tonal(
                      onPressed: _pickDownloadDir,
                      child: const Text('Change'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _resetDownloadDir,
                      child: const Text('Reset'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _infoRow('Chunk Size',
                      FileUtils.formatFileSize(AppConstants.fileChunkSize),
                      theme, colorScheme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Network
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
                  _infoRow('Protocol', 'v${AppConstants.protocolVersion}',
                      theme, colorScheme),
                  const SizedBox(height: 8),
                  _infoRow('Service Type', AppConstants.serviceType,
                      theme, colorScheme),
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
      child: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Flexible(
          child: Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
