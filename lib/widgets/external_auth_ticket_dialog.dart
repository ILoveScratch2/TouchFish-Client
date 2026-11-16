import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// 手动粘贴一次性票据对话框
class ExternalAuthTicketDialog extends StatefulWidget {
  const ExternalAuthTicketDialog({super.key, this.onOpenAuthorizePage});

  /// 重新打开授权页
  final Future<void> Function()? onOpenAuthorizePage;

  static Future<String?> show(
    BuildContext context, {
    Future<void> Function()? onOpenAuthorizePage,
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final l10n = AppLocalizations.of(context)!;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.externalAuthManualClipboardEmpty)),
      );
      return;
    }
    setState(() => _controller.text = text);
  }

  Future<void> _openAuthorizePage() async {
    final opener = widget.onOpenAuthorizePage;
    if (opener == null) return;
    await opener();
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
              l10n.externalAuthManualHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: Text(l10n.externalAuthManualPaste),
                ),
                if (widget.onOpenAuthorizePage != null)
                  OutlinedButton.icon(
                    onPressed: _openAuthorizePage,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l10n.externalAuthManualOpenPage),
                  ),
              ],
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
