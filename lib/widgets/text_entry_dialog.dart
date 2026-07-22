import 'package:flutter/material.dart';

class TextEntryDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String cancelLabel;
  final String confirmLabel;
  final IconData icon;
  final String initialValue;
  final int maxLines;
  final bool allowEmpty;

  const TextEntryDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.icon,
    this.initialValue = '',
    this.maxLines = 1,
    this.allowEmpty = false,
  });

  @override
  State<TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<TextEntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty || widget.allowEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(widget.icon),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
