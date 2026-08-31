import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/snackbar_service.dart';

/// ~~词元~~Token 管理
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
  bool _isLoading = true;
  bool _isRemoving = false;

  bool get _isAdminMode => widget.targetUid != null;

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    setState(() => _isLoading = true);
    final result = await TfApiClient.instance.listAuthTokens(
      targetUid: widget.targetUid,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  String _deviceLabel(AppLocalizations l10n, TfAuthTokenInfo token) {
    final ua = token.ua.trim();
    if (ua.isEmpty) return l10n.sessionDevicesUnknownDevice;
    if (ua.length <= _maxUaLength) return ua;
    return '${ua.substring(0, _maxUaLength)}…';
  }

  IconData _deviceIcon(TfAuthTokenInfo token) {
    final ua = token.ua.toLowerCase();
    if (ua.contains('mozilla')) return Icons.public;
    if (ua.contains('windows')) return Icons.desktop_windows;
    if (ua.contains('macos') ||
        ua.contains('mac os') ||
        ua.contains('darwin')) {
      return Icons.laptop_mac;
    }
    if (ua.contains('linux')) return Icons.computer;
    if (ua.contains('android')) return Icons.android;
    if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ios')) {
      return Icons.phone_iphone;
    }
    return Icons.devices_other_outlined;
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

  Future<void> _confirmRemove(TfAuthTokenInfo token) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionDevicesRemoveConfirmTitle),
        content: Text(l10n.sessionDevicesRemoveConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionDevicesRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRemoving = true);
    final result = await TfApiClient.instance.revokeAuthToken(
      token.jti,
      targetUid: widget.targetUid,
    );
    if (!mounted) return;
    setState(() => _isRemoving = false);

    if (result == true) {
      TouchFishSnackbarService.instance.show(l10n.sessionDevicesRemoveSuccess);
      await _loadTokens();
    } else {
      TouchFishSnackbarService.instance.show(l10n.sessionDevicesRemoveFailed);
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

  Widget _buildBody(AppLocalizations l10n) {
    final result = _result;

    if (result == null) {
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
              onPressed: _loadTokens,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final tokens = result.tokens;
    if (tokens.isEmpty) {
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
            Text(l10n.sessionDevicesEmpty),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildUsageBar(l10n, result),
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
                  _deviceIcon(token),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l10n.sessionDevicesCurrent,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (token.ip.isNotEmpty)
                      Text('${l10n.sessionDevicesIpLabel} ${token.ip}'),
                    Text(
                      '${l10n.sessionDevicesIssuedAtLabel} '
                      '${_formatTime(token.issuedAt)} · '
                      '${l10n.sessionDevicesExpiresAtLabel} '
                      '${_formatTime(token.expiresAt)}',
                    ),
                  ],
                ),
                trailing: IconButton(
                  tooltip: l10n.sessionDevicesRemove,
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: isCurrent || _isRemoving
                      ? null
                      : () => _confirmRemove(token),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isAdminMode && widget.targetUsername != null
        ? '${l10n.sessionDevicesTitle} · ${widget.targetUsername}'
        : l10n.sessionDevicesTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadTokens,
            tooltip: l10n.retry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(l10n),
    );
  }
}
