import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../models/file_attachment.dart';
import '../theme/tokens.dart';
import 'file_attachment_view.dart';

/// 帖子附件区
class ForumAttachmentsRow extends StatefulWidget {
  final List<FileAttachment> attachments;

  /// 折叠态是否仍然展示一行类型统计
  final bool showSummaryWhenCollapsed;

  const ForumAttachmentsRow({
    super.key,
    required this.attachments,
    this.showSummaryWhenCollapsed = true,
  });

  @override
  State<ForumAttachmentsRow> createState() => _ForumAttachmentsRowState();
}

class _ForumAttachmentsRowState extends State<ForumAttachmentsRow> {
  bool? _expandedOverride;

  /// 附件不多时直接展开，免去一次无意义的点击
  bool get _expanded =>
      _expandedOverride ?? widget.attachments.length <= _autoExpandThreshold;

  static const int _autoExpandThreshold = 3;

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final attachments = widget.attachments;
    final visible = _expanded ? attachments : const <FileAttachment>[];

    final imageCount = attachments.where((a) => a.isImage).length;
    final videoCount = attachments.where((a) => a.isVideo).length;
    final otherCount = attachments.length - imageCount - videoCount;

    return Padding(
      padding: const EdgeInsets.only(top: TFSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Symbols.attach_file,
                size: TFSize.iconSm,
                color: colorScheme.primary,
              ),
              const SizedBox(width: TFSpace.sm - 2),
              Text(
                l10n.forumAttachments,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: TFSpace.sm),
              if (!_expanded && widget.showSummaryWhenCollapsed)
                _AttachmentSummary(
                  imageCount: imageCount,
                  videoCount: videoCount,
                  otherCount: otherCount,
                ),
              const Spacer(),
              Text(
                '${attachments.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: TFSpace.sm),
            ...visible.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: TFSpace.sm),
                child: attachment.isImage
                    ? FileAttachmentView(attachment: attachment)
                    : FileAttachmentView(
                        attachment: attachment,
                        compact: true,
                      ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expandedOverride = !_expanded),
              icon: Icon(
                _expanded ? Symbols.expand_less : Symbols.expand_more,
                size: TFSize.iconSm,
              ),
              label: Text(
                _expanded
                    ? l10n.chatInputCollapse
                    : '${l10n.chatListExpand} (${attachments.length})',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 折叠态的类型统计：图标 + 数量，不依赖文案即可跨语言表达
class _AttachmentSummary extends StatelessWidget {
  final int imageCount;
  final int videoCount;
  final int otherCount;

  const _AttachmentSummary({
    required this.imageCount,
    required this.videoCount,
    required this.otherCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    Widget item(IconData icon, int count) {
      if (count <= 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(right: TFSpace.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: TFSize.iconXs + 2, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: TFSpace.xxs),
            Text('$count', style: textStyle),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(Icons.image_outlined, imageCount),
        item(Icons.videocam_outlined, videoCount),
        item(Icons.insert_drive_file_outlined, otherCount),
      ],
    );
  }
}
