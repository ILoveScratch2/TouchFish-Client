import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../services/draft_service.dart';
import '../theme/tokens.dart';
import '../utils/haptics.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/skeleton.dart';
import 'forum_post_compose_screen.dart';

/// 草稿箱
class DraftBoxScreen extends StatefulWidget {
  const DraftBoxScreen({super.key});

  @override
  State<DraftBoxScreen> createState() => _DraftBoxScreenState();
}

class _DraftBoxScreenState extends State<DraftBoxScreen> {
  List<DraftRecord>? _drafts;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final drafts = await DraftService.instance.listDrafts(type: 'forum');
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openDraft(DraftRecord draft) async {
    final changed = await ForumPostComposeSheet.show(
      context,
      forumId: draft.id,
    );
    if (changed == true) await _load();
  }

  Future<void> _deleteDraft(DraftRecord draft) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.draftsDelete),
        content: Text(l10n.draftsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    Haptics.heavy();
    await DraftService.instance.clearDraft(draft.type, draft.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.draftsTitle)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) return const ListSkeleton(itemCount: 6);

    if (_error != null) {
      return ErrorState(
        title: l10n.commonFailedOperation,
        description: _error,
        onRetry: _load,
        retryLabel: l10n.retry,
      );
    }

    final drafts = _drafts ?? const <DraftRecord>[];
    if (drafts.isEmpty) {
      return EmptyState(
        icon: Symbols.draft,
        title: l10n.draftsEmpty,
        description: l10n.draftsEmptyHint,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: TFSpace.sm),
        itemCount: drafts.length,
        itemBuilder: (context, index) => _DraftTile(
          draft: drafts[index],
          onTap: () => _openDraft(drafts[index]),
          onDelete: () => _deleteDraft(drafts[index]),
        ),
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  final DraftRecord draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftTile({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final rawTitle = draft.title;
    final firstLine = draft.content.split('\n').first.trim();
    final title = rawTitle.isNotEmpty
        ? rawTitle
        : (firstLine.isNotEmpty ? firstLine : l10n.draftsTitle);
    final preview = rawTitle.isNotEmpty ? draft.content : '';

    final updatedAt = draft.updatedAt;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: TFSpace.md,
        vertical: TFSpace.xs,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(TFSpace.card),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.draft, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: TFSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: TFSpace.xs),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: TFSpace.sm),
                    Wrap(
                      spacing: TFSpace.sm,
                      runSpacing: TFSpace.xs,
                      children: [
                        if (updatedAt != null)
                          _MetaChip(
                            icon: Symbols.schedule,
                            label: l10n.draftsUpdatedAt(
                              DateFormat('MM/dd HH:mm').format(updatedAt),
                            ),
                          ),
                        if (draft.attachments.isNotEmpty)
                          _MetaChip(
                            icon: Symbols.attach_file,
                            label: l10n.draftsAttachmentCount(
                              draft.attachments.length,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l10n.draftsDelete,
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.draftsDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: TFSize.iconXs, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: TFSpace.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
