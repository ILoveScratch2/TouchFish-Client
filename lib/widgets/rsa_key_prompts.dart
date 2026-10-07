import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_alert_dialog.dart';
import 'code_block.dart';

/// 首次连接 RSA 密钥保存提示的选择。
enum RsaFirstConnectChoice { save, dontSave, disconnect }
Future<RsaFirstConnectChoice> promptRsaFirstConnect(
  BuildContext context, {
  required String sha,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showTouchFishInfoDialog<RsaFirstConnectChoice>(
    context,
    title: l10n.rsaFirstConnectTitle,
    message: '',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RsaShaLine(label: l10n.rsaKeySha, sha: sha),
        const SizedBox(height: 16),
        Text(l10n.rsaFirstConnectMessage),
      ],
    ),
    actions: [
      TouchFishDialogAction<RsaFirstConnectChoice>(
        label: l10n.rsaDisconnectServer,
        result: RsaFirstConnectChoice.disconnect,
      ),
      TouchFishDialogAction<RsaFirstConnectChoice>(
        label: l10n.rsaDontSave,
        result: RsaFirstConnectChoice.dontSave,
      ),
      TouchFishDialogAction<RsaFirstConnectChoice>(
        label: l10n.rsaSaveKey,
        result: RsaFirstConnectChoice.save,
        isPrimary: true,
      ),
    ],
    barrierDismissible: false,
  );
  return choice ?? RsaFirstConnectChoice.dontSave;
}

/// 服务器 RSA 密钥变更警告。
Future<bool> promptRsaKeyChanged(
  BuildContext context, {
  required String newSha,
  required String oldSha,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showTouchFishErrorDialog<bool>(
    context,
    title: l10n.rsaKeyChangedTitle,
    message: '',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RsaShaLine(label: l10n.rsaNewKeySha, sha: newSha),
        const SizedBox(height: 8),
        _RsaShaLine(label: l10n.rsaOldKeySha, sha: oldSha),
        const SizedBox(height: 16),
        Text(
          l10n.rsaKeyChangedMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    ),
    actions: [
      TouchFishDialogAction<bool>(
        label: l10n.rsaReplaceKey,
        result: true,
      ),
      TouchFishDialogAction<bool>(
        label: l10n.rsaDisconnectServer,
        result: false,
        isPrimary: true,
      ),
    ],
    barrierDismissible: false,
  );
  return choice ?? false;
}

class _RsaShaLine extends StatelessWidget {
  final String label;
  final String sha;

  const _RsaShaLine({required this.label, required this.sha});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        CodeBlock(text: sha, fontSize: 11),
      ],
    );
  }
}
