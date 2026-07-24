import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../models/file_attachment.dart';
import 'file_attachment_view.dart';

class ForumAttachmentsRow extends StatefulWidget {
  final List<FileAttachment> attachments;

  const ForumAttachmentsRow({super.key, required this.attachments});

  @override
  State<ForumAttachmentsRow> createState() => _ForumAttachmentsRowState();
}

class _ForumAttachmentsRowState extends State<ForumAttachmentsRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final visible = _expanded ? widget.attachments : const <FileAttachment>[];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Symbols.attach_file, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                l10n.forumAttachments,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.attachments.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...visible.map(
            (attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FileAttachmentView(attachment: attachment, compact: true),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Symbols.expand_less : Symbols.expand_more,
                size: 20,
              ),
              label: Text(
                _expanded
                    ? l10n.chatInputCollapse
                    : '${l10n.chatListExpand} (${widget.attachments.length})',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
