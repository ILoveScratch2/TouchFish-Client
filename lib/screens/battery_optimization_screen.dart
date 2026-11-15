import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/permission_center.dart';
import '../services/snackbar_service.dart';
import '../theme/tokens.dart';
import '../utils/talker.dart';

/// 电池优化豁免
class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  State<BatteryOptimizationScreen> createState() =>
      _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen> {
  bool _dontAskAgain = false;
  bool _working = false;
  TfPermissionStatus _status = TfPermissionStatus.unknown;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshStatus());
  }

  Future<void> _refreshStatus() async {
    final status = await PermissionCenter.instance.statusOf(
      TfPermissionKind.batteryOptimization,
    );
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _request() async {
    if (_working) return;
    setState(() => _working = true);
    final result = await PermissionCenter.instance.request(
      TfPermissionKind.batteryOptimization,
    );
    if (!mounted) return;
    setState(() {
      _status = result;
      _working = false;
    });
    final l10n = AppLocalizations.of(context)!;
    TouchFishSnackbarService.instance.show(
      result.isGranted
          ? l10n.permissionBatteryGranted
          : l10n.permissionBatteryStillOn,
    );
    if (result.isGranted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _dismiss() async {
    if (_dontAskAgain) {
      await PermissionCenter.instance.muteBatteryPrompt();
      talker.info('Battery optimization prompt muted by user.');
    }
    if (!mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final granted = _status.isGranted;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.permissionBatteryTitle),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TFSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    granted
                        ? Icons.battery_saver_rounded
                        : Icons.battery_alert_rounded,
                    size: 56,
                    color: granted ? colorScheme.primary : colorScheme.error,
                  ),
                  const SizedBox(height: TFSpace.lg),
                  Text(
                    l10n.permissionBatteryTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: TFSpace.md),
                  Text(
                    granted
                        ? l10n.permissionBatteryGranted
                        : l10n.permissionBatteryMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  if (!granted) ...[
                    const SizedBox(height: TFSpace.lg),
                    Card(
                      margin: EdgeInsets.zero,
                      child: CheckboxListTile(
                        value: _dontAskAgain,
                        onChanged: _working
                            ? null
                            : (value) => setState(
                                () => _dontAskAgain = value ?? false,
                              ),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(l10n.permissionBatteryDontAskAgain),
                      ),
                    ),
                    const SizedBox(height: TFSpace.xl),
                    FilledButton(
                      onPressed: _working ? null : _request,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _working
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.confirm),
                      ),
                    ),
                    const SizedBox(height: TFSpace.sm),
                    TextButton(
                      onPressed: _working ? null : _dismiss,
                      child: Text(l10n.cancel),
                    ),
                  ] else
                    const SizedBox(height: TFSpace.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
