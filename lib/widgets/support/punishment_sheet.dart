import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/support_ticket.dart';
import '../../services/api/tf_api_client.dart';
import '../../services/auth_state.dart';
import '../../services/snackbar_service.dart';
import '../../theme/tokens.dart';
import '../sheet_scaffold.dart';

/// 处罚弹层
Future<void> showPunishmentSheet(
  BuildContext context, {
  required int targetUid,
  required String targetName,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) =>
        _PunishmentSheet(targetUid: targetUid, targetName: targetName),
  );
}

class _PunishmentSheet extends StatefulWidget {
  final int targetUid;
  final String targetName;

  const _PunishmentSheet({required this.targetUid, required this.targetName});

  @override
  State<_PunishmentSheet> createState() => _PunishmentSheetState();
}

class _PunishmentSheetState extends State<_PunishmentSheet> {
  final TextEditingController _reasonController = TextEditingController();
  List<Punishment> _records = const [];
  PunishmentKind _kind = PunishmentKind.warn;
  int? _durationSeconds = 7 * 24 * 3600;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final list = await TfApiClient.instance.listPunishments(
      uid,
      password,
      targetUid: widget.targetUid,
    );
    if (!mounted) return;
    setState(() {
      _records = list;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      // 理由必填
      TouchFishSnackbarService.instance.show(
        l10n.punishmentReasonRequired,
      );
      return;
    }

    setState(() => _working = true);
    final error = await TfApiClient.instance.createPunishment(
      uid,
      password,
      targetUid: widget.targetUid,
      kind: _kind,
      reason: reason,
      durationSeconds: _durationSeconds,
    );
    if (!mounted) return;
    setState(() => _working = false);

    if (error != null) {
      TouchFishSnackbarService.instance.show(l10n.punishmentCreateFailed);
      return;
    }
    _reasonController.clear();
    TouchFishSnackbarService.instance.show(l10n.punishmentCreateSuccess);
    await _load();
  }

  Future<void> _revoke(Punishment record) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    setState(() => _working = true);
    await TfApiClient.instance.revokePunishment(uid, password, record.id);
    if (!mounted) return;
    setState(() => _working = false);
    await _load();
  }

  String _kindLabel(AppLocalizations l10n, PunishmentKind kind) {
    switch (kind) {
      case PunishmentKind.warn:
        return l10n.punishmentKindWarn;
      case PunishmentKind.mute:
        return l10n.punishmentKindMute;
      case PunishmentKind.ban:
        return l10n.punishmentKindBan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SheetScaffold(
      titleText: '${l10n.punishmentTitle} · ${widget.targetName}',
      onClose: () => Navigator.pop(context),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: TFSpace.xl,
          right: TFSpace.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + TFSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: TFSpace.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TFSpace.lg),
                child: Text(
                  l10n.punishmentEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final record in _records)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '${_kindLabel(l10n, record.kind)} · '
                    '${record.isPermanent ? l10n.punishmentDurationPermanent : _formatDate(record.expiresAt!)}',
                  ),
                  subtitle: Text(
                    record.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: record.active
                      ? TextButton(
                          onPressed: _working ? null : () => _revoke(record),
                          child: Text(l10n.punishmentRevoke),
                        )
                      : Text(
                          l10n.punishmentInactive,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
            const Divider(),
            const SizedBox(height: TFSpace.md),
            Text(l10n.punishmentKindLabel, style: theme.textTheme.labelMedium),
            const SizedBox(height: TFSpace.sm),
            Wrap(
              spacing: TFSpace.sm,
              children: [
                for (final kind in PunishmentKind.values)
                  ChoiceChip(
                    label: Text(_kindLabel(l10n, kind)),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: TFSpace.lg),
            Text(
              l10n.punishmentDurationLabel,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: TFSpace.sm),
            Wrap(
              spacing: TFSpace.sm,
              children: [
                _durationChip(l10n, 24 * 3600, '1d'),
                _durationChip(l10n, 7 * 24 * 3600, '7d'),
                _durationChip(l10n, 30 * 24 * 3600, '30d'),
                ChoiceChip(
                  label: Text(l10n.punishmentDurationPermanent),
                  selected: _durationSeconds == null,
                  onSelected: (_) => setState(() => _durationSeconds = null),
                ),
              ],
            ),
            const SizedBox(height: TFSpace.lg),
            TextField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l10n.punishmentReasonLabel,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: TFSpace.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _working ? null : _submit,
                child: Text(l10n.punishmentCreate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationChip(AppLocalizations l10n, int seconds, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _durationSeconds == seconds,
      onSelected: (_) => setState(() => _durationSeconds = seconds),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}
