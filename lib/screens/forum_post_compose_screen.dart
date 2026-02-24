import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';

class ForumPostComposeSheet extends StatefulWidget {
  final String forumId;
  final String? initialContent;
  final bool isReply;

  const ForumPostComposeSheet({
    super.key,
    required this.forumId,
    this.initialContent,
    this.isReply = false,
  });
  static Future<bool?> show(
    BuildContext context, {
    required String forumId,
    String? initialContent,
    bool isReply = false,
  }) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => ForumPostComposeSheet(
        forumId: forumId,
        initialContent: initialContent,
        isReply: isReply,
      ),
    );
  }

  @override
  State<ForumPostComposeSheet> createState() => _ForumPostComposeSheetState();
}

class _ForumPostComposeSheetState extends State<ForumPostComposeSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _currentUser = UserProfileDemoData.getDemoProfile('1');

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width > 600;
    final viewInsets = MediaQuery.of(context).viewInsets;

    Widget content = Material(
      color: colorScheme.surface,
      borderRadius: isWide ? BorderRadius.circular(16) : null,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isWide ? 600 : double.infinity,
          maxHeight: isWide ? screenSize.height * 0.8 : double.infinity,
        ),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Column(
          mainAxisSize: isWide ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isReply
                          ? l10n.forumComposeReply
                          : l10n.forumComposePost,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(l10n.forumPublish),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                        child: ProfilePictureWidget(
                          avatarUrl: _currentUser.avatar,
                          radius: 20,
                          fallbackText: _currentUser.username,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title field (hidden for reply mode)
                            if (!widget.isReply)
                              TextFormField(
                                controller: _titleController,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                                decoration: InputDecoration(
                                  hintText: l10n.forumPostTitle,
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 8,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.forumPostTitleRequired;
                                  }
                                  return null;
                                },
                              ),
                            if (!widget.isReply)
                              const Divider(height: 1),
                            if (!widget.isReply)
                              const SizedBox(height: 4),
                            // Content field
                            TextFormField(
                              controller: _contentController,
                              style: Theme.of(context).textTheme.bodyLarge,
                              maxLines: null,
                              minLines: 6,
                              decoration: InputDecoration(
                                hintText: l10n.forumPostContent,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 8,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.forumPostContentRequired;
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildMarkdownToolbar(context, l10n),
          ],
        ),
      ),
    );

    if (isWide) {
      return Center(child: content);
    }
    return content;
  }
  Widget _buildMarkdownToolbar(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _insertMarkdown('**', '**'),
                        icon: const Icon(Icons.format_bold, size: 20),
                        tooltip: l10n.forumMdBold,
                      ),
                      IconButton(
                        onPressed: () => _insertMarkdown('*', '*'),
                        icon: const Icon(Icons.format_italic, size: 20),
                        tooltip: l10n.forumMdItalic,
                      ),
                      IconButton(
                        onPressed: () =>
                            _insertMarkdown('~~', '~~'),
                        icon:
                            const Icon(Icons.format_strikethrough, size: 20),
                        tooltip: l10n.forumMdStrikethrough,
                      ),
                      IconButton(
                        onPressed: () =>
                            _insertMarkdownPrefix('## '),
                        icon: const Icon(Icons.title, size: 20),
                        tooltip: l10n.forumMdHeading,
                      ),
                      IconButton(
                        onPressed: () => _insertMarkdownPrefix('- '),
                        icon: const Icon(Icons.format_list_bulleted, size: 20),
                        tooltip: l10n.forumMdList,
                      ),
                      IconButton(
                        onPressed: () =>
                            _insertMarkdownPrefix('> '),
                        icon: const Icon(Icons.format_quote, size: 20),
                        tooltip: l10n.forumMdQuote,
                      ),
                      IconButton(
                        onPressed: () => _insertMarkdown('`', '`'),
                        icon: const Icon(Icons.code, size: 20),
                        tooltip: l10n.forumMdCode,
                      ),
                      IconButton(
                        onPressed: () =>
                            _insertMarkdown('[', '](url)'),
                        icon: const Icon(Icons.link, size: 20),
                        tooltip: l10n.forumMdLink,
                      ),
                    ],
                  ),
                ),
              ),
              // Markdown hint label
              Text(
                l10n.forumPostContentMarkdown,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _insertMarkdown(String prefix, String suffix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) return;

    final selected = sel.isCollapsed ? '' : text.substring(sel.start, sel.end);
    final newText = '$prefix$selected$suffix';
    _contentController.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, newText),
      selection: TextSelection.collapsed(
        offset: sel.start + prefix.length + selected.length,
      ),
    );
  }

  void _insertMarkdownPrefix(String prefix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) return;

    int lineStart = sel.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    _contentController.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(
        offset: sel.start + prefix.length,
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isReply ? l10n.forumCommentSuccess : l10n.forumPostSuccess,
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }
}
