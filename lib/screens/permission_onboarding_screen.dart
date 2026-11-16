import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../services/permission_center.dart';
import '../services/update_preferences.dart';
import '../theme/tokens.dart';
import '../utils/talker.dart';

/// Welcome 之后的权限引导
class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> {
  static const List<TfPermissionKind> _kinds = [
    TfPermissionKind.notification,
    TfPermissionKind.camera,
    TfPermissionKind.microphone,
  ];

  final Map<TfPermissionKind, TfPermissionStatus> _statuses = {
    for (final kind in _kinds) kind: TfPermissionStatus.unknown,
  };
  final Set<TfPermissionKind> _selected = {TfPermissionKind.notification};

  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatuses());
  }

  Future<void> _loadStatuses() async {
    final entries = await Future.wait(
      _kinds.map(PermissionCenter.instance.statusOf),
    );
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _kinds.length; i++) {
        _statuses[_kinds[i]] = entries[i];
        // 已授权的项
        if (entries[i].isGranted) _selected.remove(_kinds[i]);
      }
      _loading = false;
    });
  }

  Future<void> _finish({required bool request}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await PermissionCenter.instance.markOnboardingHandled();

    if (request) {
      final targets = _kinds
          .where((kind) => _selected.contains(kind) && !_statuses[kind]!.isGranted)
          .toList();
      for (final kind in targets) {
        // 逐项申请
        final result = await PermissionCenter.instance.request(kind);
        talker.info('Onboarding permission $kind -> $result');
      }
    }

    if (!mounted) return;
    if (!UpdatePreferences.setupHandled) {
      context.go(AppRoutes.updateSetup);
      return;
    }
    context.go(AppRoutes.login);
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.permissionGuideTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => _finish(request: false),
            child: Text(l10n.permissionGuideSkip),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      TFSpace.xl,
                      TFSpace.lg,
                      TFSpace.xl,
                      TFSpace.lg,
                    ),
                    children: [
                      Text(
                        l10n.permissionGuideIntro,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: TFSpace.lg),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: TFSpace.huge),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        for (final kind in _kinds)
                          _PermissionRow(
                            icon: _iconOf(kind),
                            name: _nameOf(l10n, kind),
                            reason: _reasonOf(l10n, kind),
                            statusLabel: _statusLabel(l10n, _statuses[kind]!),
                            granted: _statuses[kind]!.isGranted,
                            selected: _selected.contains(kind),
                            enabled: !_submitting,
                            onChanged: (value) {
                              setState(() {
                                if (value) {
                                  _selected.add(kind);
                                } else {
                                  _selected.remove(kind);
                                }
                              });
                            },
                          ),
                      const SizedBox(height: TFSpace.sm),
                      Text(
                        l10n.permissionOnDemand,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TFSpace.xl,
                    TFSpace.sm,
                    TFSpace.xl,
                    TFSpace.xl,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_loading || _submitting)
                          ? null
                          : () => _finish(request: true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.permissionGuideConfirm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.name,
    required this.reason,
    required this.statusLabel,
    required this.granted,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String name;
  final String reason;
  final String statusLabel;
  final bool granted;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: TFSpace.sm),
      child: Card(
        margin: EdgeInsets.zero,
        child: SwitchListTile(
          secondary: Icon(icon),
          title: Text(name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: TFSpace.xxs),
              Text(reason),
              const SizedBox(height: TFSpace.xxs),
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: granted
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          value: granted || selected,
          onChanged: (granted || !enabled) ? null : onChanged,
        ),
      ),
    );
  }
}
