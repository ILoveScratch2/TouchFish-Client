import 'package:disk_space_2/disk_space_2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../l10n/app_localizations.dart';
import '../screens/storage_management_screen.dart';
import '../services/chat_data_service.dart';
import '../services/local_message_store.dart';
import '../services/media_proxy_service.dart';
import '../utils/sticker_cache.dart';
import 'app_alert_dialog.dart';
import 'sheet_scaffold.dart';

class LocalStorageSettings extends StatefulWidget {
  const LocalStorageSettings({super.key});

  @override
  State<LocalStorageSettings> createState() => _LocalStorageSettingsState();
}

class _LocalStorageSettingsState extends State<LocalStorageSettings> {
  double? _freeMiB;
  double? _totalMiB;
  int _databaseBytes = 0;
  int _mediaCacheBytes = 0;
  int _stickerCacheBytes = 0;
  String? _databasePath;
  bool _loading = true;
  bool _working = false;

  bool get _isDesktop =>
      !kIsWeb &&
      const {
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (!kIsWeb) {
        _freeMiB = await DiskSpace.getFreeDiskSpace;
        _totalMiB = await DiskSpace.getTotalDiskSpace;
      }
      _databaseBytes = await LocalMessageStore.instance.databaseSize();
      _databasePath = await LocalMessageStore.instance.databasePath();
      _mediaCacheBytes = await MediaProxyService.instance.cacheSize();
      _stickerCacheBytes = await StickerCache.instance.sizeBytes;
    } catch (_) {
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
  }

  Future<void> _clearStickerCache() async {
    setState(() => _working = true);
    await StickerCache.instance.clear();
    if (!mounted) return;
    setState(() {
      _working = false;
      _stickerCacheBytes = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.settingsCacheCleared),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearMediaCache() async {
    setState(() => _working = true);
    await MediaProxyService.instance.clearCache();
    if (!mounted) return;
    setState(() {
      _working = false;
      _mediaCacheBytes = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.settingsCacheCleared),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetMessages() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.settingsResetLocalMessages,
      message: l10n.settingsResetLocalMessagesConfirm,
      icon: Icons.delete_sweep_outlined,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.settingsResetLocalMessages,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    await ChatDataService.instance.clearLocalMessageDatabase();
    if (!mounted) return;
    setState(() {
      _working = false;
      _databaseBytes = 0;
    });
  }

  Future<void> _showChatStorage() async {
    final stats = await LocalMessageStore.instance.roomStats();
    if (!mounted) return;
    final roomNames = {
      for (final room in ChatDataService.instance.rooms) room.id: room.name,
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: AppLocalizations.of(sheetContext)!.settingsChatStorage,
        heightFactor: 0.92,
        child: stats.isEmpty
            ? Center(
                child: Text(
                  AppLocalizations.of(sheetContext)!.settingsNoLocalMessages,
                ),
              )
            : ListView.separated(
                itemCount: stats.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = stats.entries.elementAt(index);
                  return ListTile(
                    leading: const Icon(Icons.forum_outlined),
                    title: Text(roomNames[entry.key] ?? entry.key),
                    subtitle: Text(
                      AppLocalizations.of(context)!.settingsLocalMessageCount(
                        entry.value.messages,
                        _formatBytes(entry.value.bytes),
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: AppLocalizations.of(
                        context,
                      )!.settingsClearLocalMessages,
                      onPressed: () async {
                        await LocalMessageStore.instance.deleteRoom(entry.key);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        await _load();
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final totalBytes = ((_totalMiB ?? 0) * 1024 * 1024).round();
    final freeBytes = ((_freeMiB ?? 0) * 1024 * 1024).round();
    final usedBytes = (totalBytes - freeBytes).clamp(0, totalBytes);
    final usedRatio = totalBytes > 0 ? usedBytes / totalBytes : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (usedRatio != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l10n.settingsStorageUsed),
                    const Spacer(),
                    Text(
                      '${(usedRatio * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: usedRatio, minHeight: 8),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${_formatBytes(usedBytes)} / ${_formatBytes(totalBytes)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      '${l10n.settingsStorageFree}: ${_formatBytes(freeBytes)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              l10n.settingsStorageUnavailable,
              style: theme.textTheme.bodySmall,
            ),
          ),
        const Divider(height: 1),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          minLeadingWidth: 48,
          leading: const Icon(Icons.forum_outlined),
          title: Text(l10n.settingsChatStorage),
          subtitle: Text(l10n.settingsChatStorageDescription),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showChatStorage,
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          minLeadingWidth: 48,
          leading: const Icon(Icons.cloud_outlined),
          title: Text(l10n.settingsCloudFiles),
          subtitle: Text(l10n.settingsCloudFilesDescription),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StorageManagementScreen(),
            ),
          ),
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l10n.settingsAppCache,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          minLeadingWidth: 48,
          leading: const Icon(Icons.cached),
          title: Text(l10n.settingsMediaCache),
          subtitle: Text(_formatBytes(_mediaCacheBytes)),
          trailing: TextButton(
            onPressed: _working ? null : _clearMediaCache,
            child: Text(l10n.settingsClearCache),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          minLeadingWidth: 48,
          leading: const Icon(Icons.sticky_note_2_outlined),
          title: Text(l10n.settingsClearStickerCache),
          subtitle: Text(_formatBytes(_stickerCacheBytes)),
          trailing: TextButton(
            onPressed: _working ? null : _clearStickerCache,
            child: Text(l10n.settingsClearCache),
          ),
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l10n.settingsLocalDatabase,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_isDesktop && _databasePath != null)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            minLeadingWidth: 48,
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(l10n.settingsOpenDatabaseFolder),
            subtitle: Text(
              _databasePath!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => OpenFile.open(_databasePath),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          minLeadingWidth: 48,
          leading: const Icon(Icons.storage_outlined),
          title: Text(l10n.settingsLocalDatabaseSize),
          subtitle: Text(_formatBytes(_databaseBytes)),
          trailing: TextButton(
            onPressed: _working ? null : _resetMessages,
            child: Text(l10n.settingsResetLocalMessages),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
