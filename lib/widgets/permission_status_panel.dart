import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../services/permission_center.dart';
import '../theme/tokens.dart';

class PermissionStatusPanel extends StatefulWidget {
  const PermissionStatusPanel({super.key});

  @override
  State<PermissionStatusPanel> createState() => _PermissionStatusPanelState();
}

class _PermissionStatusPanelState extends State<PermissionStatusPanel>
    with WidgetsBindingObserver {
  static const List<TfPermissionKind> _kinds = [
    TfPermissionKind.notification,
    TfPermissionKind.batteryOptimization,
    TfPermissionKind.camera,
    TfPermissionKind.microphone,
  ];

  final Map<TfPermissionKind, TfPermissionStatus> _statuses = {
    for (final kind in _kinds) kind: TfPermissionStatus.unknown,
  };
  bool _loading = true;
  TfPermissionKind? _busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置返回后状态可能已变化
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final entries = await Future.wait(
      _kinds.map(PermissionCenter.instance.statusOf),
    );
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _kinds.length; i++) {
        _statuses[_kinds[i]] = entries[i];
      }
      _loading = false;
    });
  }

  Future<void> _handleTap(TfPermissionKind kind) async {
    if (_busy != null) return;
    final status = _statuses[kind] ?? TfPermissionStatus.unknown;
    if (status.isGranted) return;

    if (kind == TfPermissionKind.batteryOptimization) {
      await context.push(AppRoutes.batteryPermission);
      if (mounted) await _refresh();
      return;
    }

    if (status.needsSystemSettings || status == TfPermissionStatus.restricted) {
      await PermissionCenter.instance.openSystemSettings();
      return;
    }

    setState(() => _busy = kind);
    await PermissionCenter.instance.request(kind);
    if (!mounted) return;
    setState(() => _busy = null);
    await _refresh();
  }

  String _nameOf(AppLocalizations l10n, TfPermissionKind kind) {
    switch (kind) {
      case TfPermissionKind.notification:
        return l10n.permissionNameNotification;
      case TfPermissionKind.batteryOptimization:
        return l10n.permissionNameBattery;
      case TfPermissionKind.camera:
        return l10n.permissionNameCamera;
      case TfPermissionKind.microphone:
        return l10n.permissionNameMicrophone;
    }
  }

  String _reasonOf(AppLocalizations l10n, TfPermissionKind kind) {
    switch (kind) {
      case TfPermissionKind.notification:
        return l10n.permissionReasonNotification;
      case TfPermissionKind.batteryOptimization:
        return l10n.permissionReasonBattery;
      case TfPermissionKind.camera:
        return l10n.permissionReasonCamera;
      case TfPermissionKind.microphone:
        return l10n.permissionReasonMicrophone;
    }
  }

  IconData _iconOf(TfPermissionKind kind) {
    switch (kind) {
      case TfPermissionKind.notification:
        return Icons.notifications_active_outlined;
      case TfPermissionKind.batteryOptimization:
        return Icons.battery_saver_outlined;
      case TfPermissionKind.camera:
        return Icons.photo_camera_outlined;
      case TfPermissionKind.microphone:
        return Icons.mic_none_rounded;
    }
  }

  String _statusLabel(AppLocalizations l10n, TfPermissionStatus status) {
    switch (status) {
      case TfPermissionStatus.granted:
        return l10n.permissionStatusGranted;
      case TfPermissionStatus.denied:
        return l10n.permissionStatusDenied;
      case TfPermissionStatus.permanentlyDenied:
        return l10n.permissionStatusPermanentlyDenied;
      case TfPermissionStatus.restricted:
        return l10n.permissionStatusRestricted;
      case TfPermissionStatus.notApplicable:
        return l10n.permissionStatusNotApplicable;
      case TfPermissionStatus.unknown:
        return l10n.permissionStatusUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: TFSpace.sm),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(l10n.permissionStatusTitle),
              subtitle: Text(l10n.permissionStatusDesc),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: TFSpace.lg),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              for (final kind in _kinds) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(_iconOf(kind), size: 20),
                  title: Text(_nameOf(l10n, kind)),
                  subtitle: Text(_reasonOf(l10n, kind)),
                  trailing: _trailing(context, l10n, kind),
                  onTap: () => unawaited(_handleTap(kind)),
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _trailing(
    BuildContext context,
    AppLocalizations l10n,
    TfPermissionKind kind,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = _statuses[kind] ?? TfPermissionStatus.unknown;
    final granted = status.isGranted;
    final needsSettings =
        status.needsSystemSettings || status == TfPermissionStatus.restricted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_busy == kind)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Text(
            _statusLabel(l10n, status),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: granted
                  ? colorScheme.primary
                  : needsSettings
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        if (!granted) ...[
          const SizedBox(width: TFSpace.xs),
          Icon(
            needsSettings ? Icons.settings_outlined : Icons.chevron_right,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}
