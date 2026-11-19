import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_update_flow.dart';
import '../services/app_update_service.dart';
import '../services/update_preferences.dart';
import 'changelog_view.dart';


class UpdateInfoCard extends StatefulWidget {
  const UpdateInfoCard({super.key});

  @override
  State<UpdateInfoCard> createState() => _UpdateInfoCardState();
}

class _UpdateInfoCardState extends State<UpdateInfoCard> {
  String? _currentVersion;
  VersionCheckResult? _result;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Web 端强制不检查更新
    if (!UpdatePreferences.isSupported) return;
    unawaited(_load());
  }

  /// 首屏静默拉一次：只更新展示，不弹任何提示。
  Future<void> _load() async {
    final service = AppUpdateService.instance;
    final current = await service.currentVersion();
    if (mounted) setState(() => _currentVersion = current);

    final result = await service.checkForUpdate();
    if (!mounted) return;
    setState(() => _result = result);
  }

  Future<void> _checkManually() async {
    if (_checking) return;
    setState(() => _checking = true);

    final result = await AppUpdateFlow.instance.checkQuietly();
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (result != null) _result = result;
    });

    if (result != null) {
      await AppUpdateFlow.instance.presentResult(context, result);
    }
  }

  String _latestValue(AppLocalizations l10n) {
    final result = _result;
    if (result == null) return l10n.aboutUpdateChecking;
    final latest = result.remoteVersion;
    if (latest == null) {
      return result.error != null
          ? l10n.aboutUpdateUnavailable
          : l10n.aboutUpdateChecking;
    }
    return l10n.aboutUpdateLatestValue(
      latest,
      result.hasUpdate ? l10n.aboutUpdateAvailable : l10n.aboutUpdateUpToDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!UpdatePreferences.isSupported) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final changelog = _result?.changelog.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(
                    theme,
                    label: l10n.updateSetupCurrentVersion,
                    value: _currentVersion ?? '—',
                  ),
                  const SizedBox(height: 6),
                  _row(
                    theme,
                    label: l10n.aboutLatestVersion,
                    value: _latestValue(l10n),
                  ),
                  if (changelog.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.aboutUpdateChangesTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ChangelogView(
                      markdown: changelog,
                      maxHeight: 140,
                      scrollable: false,
                      padding: const EdgeInsets.all(10),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => showChangelogDialog(
                          context,
                          markdown: changelog,
                          title: l10n.updateChangelogTitle,
                          subtitle: _latestValue(l10n),
                        ),
                        icon: const Icon(Icons.open_in_full_rounded, size: 16),
                        label: Text(l10n.updateChangelogViewFull),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l10n.aboutUpdateCheckNow),
              subtitle: Text(l10n.aboutUpdateCheckNowDescription),
              trailing: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _checking ? null : _checkManually,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, {required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
