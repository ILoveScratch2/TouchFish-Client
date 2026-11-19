import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// 手动粘贴一次性票据对话框
class ExternalAuthTicketDialog extends StatefulWidget {
  const ExternalAuthTicketDialog({super.key, this.onOpenAuthorizePage});

  /// 打开授权页
  final Future<bool> Function()? onOpenAuthorizePage;

  static Future<String?> show(
    BuildContext context, {
    Future<bool> Function()? onOpenAuthorizePage,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => ExternalAuthTicketDialog(
        onOpenAuthorizePage: onOpenAuthorizePage,
      ),
    );
  }

  @override
  State<ExternalAuthTicketDialog> createState() =>
      _ExternalAuthTicketDialogState();
}

class _ExternalAuthTicketDialogState extends State<ExternalAuthTicketDialog> {
  final TextEditingController _controller = TextEditingController();

  bool _openingAuthorizePage = false;
  bool _openAuthorizePageFailed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final l10n = AppLocalizations.of(context)!;
    String? text;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text?.trim();
    } catch (_) {
      text = null;
    }
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.externalAuthManualClipboardEmpty)),
      );
      return;
    }
    final value = text;
    setState(() => _controller.text = value);
  }

  Future<void> _openAuthorizePage() async {
    final opener = widget.onOpenAuthorizePage;
    if (opener == null) return;
    setState(() => _openingAuthorizePage = true);
    var opened = false;
    try {
      opened = await opener();
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _openingAuthorizePage = false;
      _openAuthorizePageFailed = !opened;
    });
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.externalAuthManualTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.onOpenAuthorizePage != null
                  ? l10n.externalAuthManualHintWithOpen
                  : l10n.externalAuthManualHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            // 票据只在授权页生成
            if (widget.onOpenAuthorizePage != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _openingAuthorizePage ? null : _openAuthorizePage,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.externalAuthManualOpenPage),
                ),
              ),
              if (_openAuthorizePageFailed) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.externalAuthManualOpenFailed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.externalAuthManualFieldLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.content_paste, size: 18),
                label: Text(l10n.externalAuthManualPaste),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: Text(l10n.externalAuthManualConfirm),
        ),
      ],
    );
  }
}
