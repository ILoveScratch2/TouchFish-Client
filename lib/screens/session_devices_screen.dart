import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/device_identity_service.dart';
import '../services/snackbar_service.dart';
import '../utils/time_ago.dart';

/// ~~词元~~会话与设备管理
class SessionDevicesScreen extends StatefulWidget {
  const SessionDevicesScreen({super.key, this.targetUid, this.targetUsername});

  final int? targetUid;
  final String? targetUsername;

  @override
  State<SessionDevicesScreen> createState() => _SessionDevicesScreenState();
}

class _SessionDevicesScreenState extends State<SessionDevicesScreen> {
  static const int _maxUaLength = 60;

  TfTokenListResult? _result;
  TfDeviceListResult? _devices;
  bool _isLoading = true;
  bool _isBusy = false;

  bool get _isAdminMode => widget.targetUid != null;

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      TfApiClient.instance.listSessions(targetUid: widget.targetUid),
      TfApiClient.instance.listDevices(targetUid: widget.targetUid),
    ]);
    if (!mounted) return;
    setState(() {
      _result = results[0] as TfTokenListResult?;
      _devices = results[1] as TfDeviceListResult?;
      _isLoading = false;
    });
  }

  String _deviceLabel(AppLocalizations l10n, TfAuthTokenInfo token) {
    if (token.label.isNotEmpty) return token.label;
    if (token.deviceName.isNotEmpty) return token.deviceName;
    final ua = token.ua.trim();
    if (ua.isEmpty) return l10n.sessionDevicesUnknownDevice;
    if (ua.length <= _maxUaLength) return ua;
    return '${ua.substring(0, _maxUaLength)}…';
  }

  IconData _platformIcon(int platform, String ua) {
    if (platform != 0) {
      switch (platform) {
        case DevicePlatform.windows:
          return Icons.desktop_windows;
        case DevicePlatform.macos:
          return Icons.laptop_mac;
        case DevicePlatform.linux:
          return Icons.computer;
        case DevicePlatform.android:
          return Icons.android;
        case DevicePlatform.ios:
          return Icons.phone_iphone;
        case DevicePlatform.web:
          return Icons.public;
        default:
          return Icons.devices_other_outlined;
      }
    }
    // 降级到 UA
    final normalized = ua.toLowerCase();
    if (normalized.contains('mozilla')) return Icons.public;
    if (normalized.contains('windows')) return Icons.desktop_windows;
    if (normalized.contains('macos') ||
        normalized.contains('mac os') ||
        normalized.contains('darwin')) {
      return Icons.laptop_mac;
    }
    if (normalized.contains('linux')) return Icons.computer;
    if (normalized.contains('android')) return Icons.android;
    if (normalized.contains('iphone') ||
        normalized.contains('ipad') ||
        normalized.contains('ios')) {
      return Icons.phone_iphone;
    }
    return Icons.devices_other_outlined;
  }

  String _platformLabel(AppLocalizations l10n, int platform, String ua) {
    switch (platform) {
      case DevicePlatform.windows:
        return l10n.sessionDevicesPlatformWindows;
      case DevicePlatform.macos:
        return l10n.sessionDevicesPlatformMacos;
      case DevicePlatform.linux:
        return l10n.sessionDevicesPlatformLinux;
      case DevicePlatform.android:
        return l10n.sessionDevicesPlatformAndroid;
      case DevicePlatform.ios:
        return l10n.sessionDevicesPlatformIos;
      case DevicePlatform.web:
        return l10n.sessionDevicesPlatformWeb;
    }
    final normalized = ua.toLowerCase();
    if (normalized.contains('windows')) {
      return l10n.sessionDevicesPlatformWindows;
    }
    if (normalized.contains('macos') || normalized.contains('mac os')) {
      return l10n.sessionDevicesPlatformMacos;
    }
    if (normalized.contains('linux')) {
      return l10n.sessionDevicesPlatformLinux;
    }
    if (normalized.contains('android')) {
      return l10n.sessionDevicesPlatformAndroid;
    }
    if (normalized.contains('iphone') ||
        normalized.contains('ipad') ||
        normalized.contains('ios')) {
      return l10n.sessionDevicesPlatformIos;
    }
    if (normalized.contains('mozilla')) {
      return l10n.sessionDevicesPlatformWeb;
    }
    return l10n.sessionDevicesUnknownPlatform;
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return '—';
    return _dateFormat.format(
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
    );
  }

  String _maxPerUserLabel(AppLocalizations l10n) {
    final max = _result?.maxPerUser ?? 0;
    if (max <= 0) return l10n.sessionDevicesUnlimited;
    return max.toString();
  }

  void _showSnack(String message) {
    TouchFishSnackbarService.instance.show(message);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmRemove(TfAuthTokenInfo token) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      context,
      title: l10n.sessionDevicesRemoveConfirmTitle,
      message: l10n.sessionDevicesRemoveConfirmMessage,
      confirmLabel: l10n.sessionDevicesRemove,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final result = await TfApiClient.instance.revokeSession(
      token.sessionId,
      targetUid: widget.targetUid,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result == true) {
      _showSnack(l10n.sessionDevicesRemoveSuccess);
      await _load();
    } else {
      _showSnack(l10n.sessionDevicesRemoveFailed);
    }
  }

  Future<void> _confirmRevokeDevice(TfDeviceInfo device) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      context,
      title: l10n.sessionDevicesRemoveConfirmTitle,
      message: l10n.sessionDevicesRemoveConfirmMessage,
      confirmLabel: l10n.sessionDevicesRemove,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final result = await TfApiClient.instance.revokeDevice(
      device.deviceId,
      targetUid: widget.targetUid,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result == true) {
      _showSnack(l10n.sessionDevicesRemoveSuccess);
      await _load();
    } else {
      _showSnack(l10n.sessionDevicesRemoveFailed);
    }
  }

  Future<void> _confirmRevokeAllOthers() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      context,
      title: l10n.sessionDevicesRevokeAllOthersConfirmTitle,
      message: l10n.sessionDevicesRevokeAllOthersConfirmMessage,
      confirmLabel: l10n.sessionDevicesRevokeAllOthers,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final result = await TfApiClient.instance.revokeAllOtherSessions(
      targetUid: widget.targetUid,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result == true) {
      _showSnack(l10n.sessionDevicesRevokeAllOthersSuccess);
      await _load();
    } else {
      _showSnack(l10n.sessionDevicesRevokeAllOthersFailed);
    }
  }

  Future<void> _renameDevice(TfDeviceInfo device) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: device.label);

    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionDevicesRenameTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.sessionDevicesRenameLabel,
            hintText: l10n.sessionDevicesRenameHint,
            helperText: l10n.sessionDevicesRenameHelper,
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (newLabel == null || !mounted) return;

    setState(() => _isBusy = true);
    final result = await TfApiClient.instance.updateDeviceLabel(
      device.deviceId,
      newLabel,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result == true) {
      _showSnack(l10n.sessionDevicesRenameSuccess);
      await _load();
    } else {
      _showSnack(l10n.sessionDevicesRenameFailed);
    }
  }

  Future<void> _renameSessionDevice(TfAuthTokenInfo token) async {
    if (token.deviceId.isEmpty) {
      await _renameBySession(token);
      return;
    }
    final device = (_devices?.devices ?? const <TfDeviceInfo>[]).firstWhere(
      (d) => d.deviceId == token.deviceId,
      orElse: () => TfDeviceInfo(
        deviceId: token.deviceId,
        deviceName: token.deviceName,
        label: token.label,
        platform: token.platform,
      ),
    );
    await _renameDevice(device);
  }

  /// 服务器不支持设备接口时的降级：按会话重命名。
  Future<void> _renameBySession(TfAuthTokenInfo token) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: token.label);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionDevicesRenameTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.sessionDevicesRenameLabel,
            hintText: l10n.sessionDevicesRenameHint,
            helperText: l10n.sessionDevicesRenameHelper,
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (newLabel == null || !mounted) return;

    setState(() => _isBusy = true);
    final result = await TfApiClient.instance.renameSession(
      token.sessionId,
      newLabel,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result == true) {
      _showSnack(l10n.sessionDevicesRenameSuccess);
      await _load();
    } else {
      _showSnack(l10n.sessionDevicesRenameFailed);
    }
  }

  Widget _buildUsageBar(AppLocalizations l10n, TfTokenListResult result) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '${l10n.sessionDevicesCountLabel} ${result.tokens.length}'
            ' / ${_maxPerUserLabel(l10n)}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBadge(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        l10n.sessionDevicesCurrent,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildSessionsTab(AppLocalizations l10n) {
    final result = _result;
    if (result == null) return _buildUnsupported(l10n);
    final tokens = result.tokens;
    if (tokens.isEmpty) {
      return _buildEmpty(l10n, l10n.sessionDevicesEmpty);
    }

    final hasOthers = tokens.any((token) => !token.isCurrent);

    return Column(
      children: [
        _buildUsageBar(l10n, result),
        if (hasOthers)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _isBusy ? null : _confirmRevokeAllOthers,
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.sessionDevicesRevokeAllOthers),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: tokens.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final token = tokens[index];
              final isCurrent = token.isCurrent;
              return ListTile(
                leading: Icon(
                  _platformIcon(token.platform, token.ua),
                  size: 28,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _deviceLabel(l10n, token),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      _buildCurrentBadge(l10n),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _platformLabel(l10n, token.platform, token.ua),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (token.ip.isNotEmpty)
                      Text('${l10n.sessionDevicesIpLabel} ${token.ip}'),
                    if (token.location.isNotEmpty)
                      Text(
                        '${l10n.sessionDevicesLocation}: ${token.location}',
                      ),
                    Text(
                      '${l10n.sessionDevicesIssuedAtLabel} '
                      '${_formatTime(token.issuedAt)} · '
                      '${l10n.sessionDevicesLastSeen} '
                      '${formatTimeAgo(l10n, token.lastSeen)}',
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.sessionDevicesRename,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _isBusy
                          ? null
                          : () => _renameSessionDevice(token),
                    ),
                    IconButton(
                      tooltip: l10n.sessionDevicesRemove,
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: isCurrent || _isBusy
                          ? null
                          : () => _confirmRemove(token),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, int> _sessionCountByDevice() {
    final counts = <String, int>{};
    for (final token in _result?.tokens ?? const <TfAuthTokenInfo>[]) {
      if (token.deviceId.isEmpty) continue;
      counts[token.deviceId] = (counts[token.deviceId] ?? 0) + 1;
    }
    return counts;
  }

  bool _isCurrentDevice(TfDeviceInfo device) {
    return (_result?.tokens ?? const <TfAuthTokenInfo>[])
        .any((token) => token.isCurrent && token.deviceId == device.deviceId);
  }

  Widget _buildDevicesTab(AppLocalizations l10n) {
    final devices = _devices?.devices ?? const <TfDeviceInfo>[];
    if (devices.isEmpty) {
      return _buildEmpty(l10n, l10n.sessionDevicesEmpty);
    }
    final counts = _sessionCountByDevice();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: devices.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final device = devices[index];
        final isCurrent = _isCurrentDevice(device);
        final count = counts[device.deviceId] ?? 0;
        return ListTile(
          leading: Icon(_platformIcon(device.platform, ''), size: 28),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  device.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                _buildCurrentBadge(l10n),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _platformLabel(l10n, device.platform, ''),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${l10n.sessionDevicesSessionCount}: $count · '
                '${l10n.sessionDevicesLastSeen} '
                '${formatTimeAgo(l10n, device.lastSeen)}',
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.sessionDevicesRename,
                icon: const Icon(Icons.edit_outlined),
                onPressed: _isBusy ? null : () => _renameDevice(device),
              ),
              IconButton(
                tooltip: l10n.sessionDevicesRemove,
                icon: const Icon(Icons.logout_rounded),
                onPressed: isCurrent || _isBusy
                    ? null
                    : () => _confirmRevokeDevice(device),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildUnsupported(AppLocalizations l10n) {
    // 请求失败：服务器不支持 JWT/设备管理，或网络异常
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(l10n.sessionDevicesUnsupported),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.devices_other_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isAdminMode && widget.targetUsername != null
        ? '${l10n.sessionDevicesTitle} · ${widget.targetUsername}'
        : l10n.sessionDevicesTitle;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _load,
              tooltip: l10n.retry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.sessionDevicesTabDevices),
              Tab(text: l10n.sessionDevicesTabSessions),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildDevicesTab(l10n),
                  _buildSessionsTab(l10n),
                ],
              ),
      ),
    );
  }
}
