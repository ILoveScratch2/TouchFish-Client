import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../l10n/app_localizations.dart';

class SignatureEditorWidget extends StatefulWidget {
  final String? currentSignature;
  final Function(String) onUpdate;

  const SignatureEditorWidget({
    super.key,
    this.currentSignature,
    required this.onUpdate,
  });

  @override
  State<SignatureEditorWidget> createState() => _SignatureEditorWidgetState();
}

class _SignatureEditorWidgetState extends State<SignatureEditorWidget> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentSignature ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reset to original if canceled
        _controller.text = widget.currentSignature ?? '';
      }
    });
  }

  void _saveSignature() {
    widget.onUpdate(_controller.text);
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Symbols.edit, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.accountEditSignature,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 3,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: l10n.accountSignaturePlaceholder,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _toggleEdit,
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveSignature,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _toggleEdit,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Symbols.edit, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.currentSignature?.isNotEmpty == true
                    ? widget.currentSignature!
                    : l10n.accountCreateSignature,
                style: TextStyle(
                  color: widget.currentSignature?.isEmpty ?? true
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const Icon(Symbols.keyboard_arrow_up, size: 20),
          ],
        ),
      ),
    );
  }
}
