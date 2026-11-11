import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// 审核驳回的理由输入
class ReviewReasonField extends StatefulWidget {
  final TextEditingController controller;

  const ReviewReasonField({super.key, required this.controller});

  @override
  State<ReviewReasonField> createState() => _ReviewReasonFieldState();
}

class _ReviewReasonFieldState extends State<ReviewReasonField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // 选中的预设要在输入框被手动改动后取消高亮
    if (mounted) setState(() {});
  }

  void _applyPreset(String value) {
    if (widget.controller.text.trim() == value) {
      widget.controller.clear();
    } else {
      widget.controller.text = value;
      widget.controller.selection = TextSelection.collapsed(
        offset: value.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final presets = [
      l10n.reviewReasonPresetIncomplete,
      l10n.reviewReasonPresetOffTopic,
      l10n.reviewReasonPresetDuplicate,
      l10n.reviewReasonPresetInappropriate,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: TFSpace.sm,
          runSpacing: TFSpace.xs,
          children: [
            for (final preset in presets)
              ChoiceChip(
                label: Text(preset),
                selected: widget.controller.text.trim() == preset,
                onSelected: (_) => _applyPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: TFSpace.md),
        TextField(
          controller: widget.controller,
          maxLines: 3,
          minLines: 2,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: l10n.reviewReasonHint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
