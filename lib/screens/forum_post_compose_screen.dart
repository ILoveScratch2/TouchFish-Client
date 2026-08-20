import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../services/clipboard_attachment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/snackbar_service.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/mention_text_field.dart';
import '../utils/talker.dart';
import '../models/file_attachment.dart';
import '../services/draft_service.dart';
import '../widgets/file_attachment_view.dart';
import '../widgets/stickers/sticker_picker.dart';

class ForumPostComposeSheet extends StatefulWidget {
  final String forumId;
  final String? initialContent;
  final bool isReply;
  final String? postId;
  final ValueChanged<String>? onContentChanged;

  const ForumPostComposeSheet({
    super.key,
    required this.forumId,
    this.initialContent,
    this.isReply = false,
    this.postId,
    this.onContentChanged,
  });
  static Future<bool?> show(
    BuildContext context, {
    required String forumId,
    String? initialContent,
    bool isReply = false,
    String? postId,
    ValueChanged<String>? onContentChanged,
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
        postId: postId,
        onContentChanged: onContentChanged,
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
  final List<MentionUser> _mentionUsers = [];

  final _currentUser =
      AuthState.instance.currentUser ?? UserProfileDemoData.getDemoProfile('1');
  bool _isSubmitting = false;
  bool _isUploadingAttachment = false;
  final List<FileAttachment> _attachments = [];
  late final FocusNode _clipboardFocusNode;
  Timer? _draftTimer;
  bool _didSubmit = false;

  String get _draftType => widget.isReply ? 'forum_comment' : 'forum_post';
  String get _draftId =>
      widget.isReply ? '${widget.forumId}/${widget.postId}' : widget.forumId;

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
    _clipboardFocusNode = FocusNode(onKeyEvent: _handleForumKeyEvent);
    _titleController.addListener(_scheduleDraftSave);
    _contentController.addListener(_scheduleDraftSave);
    if (widget.onContentChanged != null) {
      _contentController.addListener(_reportContentChange);
    }
    unawaited(_restoreDraft());
    _loadMentionUsers();
  }

  Future<void> _restoreDraft() async {
    final draft = await DraftService.instance.loadDraft(_draftType, _draftId);
    if (!mounted || draft == null) return;
    if (_titleController.text.isEmpty) {
      _titleController.text = draft['title'] as String? ?? '';
    }
    if (_contentController.text.isEmpty) {
      _contentController.text = draft['content'] as String? ?? '';
    }
    final attachments = draft['attachments'];
    if (!widget.isReply && attachments is List) {
      setState(() {
        _attachments
          ..clear()
          ..addAll(
            attachments.whereType<Map>().map(
              (item) => FileAttachment.fromMap(Map<String, dynamic>.from(item)),
            ),
          );
      });
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  void _reportContentChange() {
    widget.onContentChanged?.call(_contentController.text);
  }

  Future<void> _saveDraft() =>
      DraftService.instance.saveDraft(_draftType, _draftId, {
        'title': _titleController.text,
        'content': _contentController.text,
        'attachments': _attachments
            .map(
              (file) => {
                'hash': file.hash,
                'file_name': file.fileName,
                if (file.fileSize != null) 'size': file.fileSize,
                if (file.mimeType != null) 'mime_type': file.mimeType,
              },
            )
            .toList(),
      });

  Future<void> _loadMentionUsers() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final rows = await TfApiClient.instance.getMentionCandidates(uid, password);
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _mentionUsers
        ..clear()
        ..addAll(
          rows.map((row) {
            final candidateUid = (row['uid'] as num).toInt();
            return MentionUser(
              id: candidateUid.toString(),
              username: row['username'] as String? ?? 'User $candidateUid',
              avatarUrl: '$baseUrl/avatar/get_avatar/user/$candidateUid',
            );
          }),
        );
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (!_didSubmit) unawaited(_saveDraft());
    if (widget.onContentChanged != null) {
      _contentController.removeListener(_reportContentChange);
    }
    _clipboardFocusNode.dispose();
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
                    onPressed: (_isSubmitting || _isUploadingAttachment)
                        ? null
                        : _submit,
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
                                style: Theme.of(context).textTheme.titleMedium,
                                decoration: InputDecoration(
                                  hintText: l10n.forumPostTitle,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 8,
                                  ),
                                ),
                                validator: (value) {
                                  if (_contentController.text.trim().isEmpty &&
                                      (value == null || value.trim().isEmpty)) {
                                    return l10n.forumPostTitleRequired;
                                  }
                                  return null;
                                },
                              ),
                            if (!widget.isReply) const Divider(height: 1),
                            if (!widget.isReply) const SizedBox(height: 4),
                            // Content field
                            MentionTextField(
                              focusNode: _clipboardFocusNode,
                              controller: _contentController,
                              mentionUsers: _mentionUsers,
                              style: Theme.of(context).textTheme.bodyLarge,
                              maxLines: null,
                              minLines: 6,
                              decoration: InputDecoration(
                                hintText: l10n.forumPostContent,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            if (!widget.isReply && _attachments.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ..._attachments.map(
                                (attachment) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: FileAttachmentView(
                                          attachment: attachment,
                                          allowAutomaticPreview: false,
                                          compact: true,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : () {
                                                setState(
                                                  () => _attachments.remove(
                                                    attachment,
                                                  ),
                                                );
                                                _scheduleDraftSave();
                                              },
                                        icon: const Icon(Icons.close),
                                        tooltip: l10n.forumAttachmentRemove,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
                      if (!widget.isReply)
                        IconButton(
                          onPressed: _isUploadingAttachment
                              ? null
                              : _pickAttachments,
                          icon: _isUploadingAttachment
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.attach_file, size: 20),
                          tooltip: l10n.forumComposeAttachFile,
                        ),
                      IconButton(
                        onPressed: () => _insertMarkdown('*', '*'),
                        icon: const Icon(Icons.format_italic, size: 20),
                        tooltip: l10n.forumMdItalic,
                      ),
                      IconButton(
                        onPressed: () => _insertMarkdown('~~', '~~'),
                        icon: const Icon(Icons.format_strikethrough, size: 20),
                        tooltip: l10n.forumMdStrikethrough,
                      ),
                      IconButton(
                        onPressed: () => _insertMarkdownPrefix('## '),
                        icon: const Icon(Icons.title, size: 20),
                        tooltip: l10n.forumMdHeading,
                      ),
                      IconButton(
                        onPressed: () => _insertMarkdownPrefix('- '),
                        icon: const Icon(Icons.format_list_bulleted, size: 20),
                        tooltip: l10n.forumMdList,
                      ),
                      IconButton(
                        onPressed: () => _insertMarkdownPrefix('> '),
                        icon: const Icon(Icons.format_quote, size: 20),
                        tooltip: l10n.forumMdQuote,
                      ),
                      IconButton(
                        onPressed: () => _insertMarkdown('`', '`'),
                        icon: const Icon(Icons.code, size: 20),
                        tooltip: l10n.forumMdCode,
                      ),
                      IconButton(
                        onPressed: () => _insertMarkdown('[', '](url)'),
                        icon: const Icon(Icons.link, size: 20),
                        tooltip: l10n.forumMdLink,
                      ),
                      IconButton(
                        onPressed: _openStickerPanel,
                        icon: const Icon(Icons.sticky_note_2_outlined, size: 20),
                        tooltip: l10n.stickerMarketTitle,
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

  void _openStickerPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: StickerPickerPanel(
            onPick: (pack, sticker) {
              _insertText(':${pack.prefix}+${sticker.slug}:');
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _insertText(String value) {
    final sel = _contentController.selection;
    final start = sel.start < 0 ? _contentController.text.length : sel.start;
    final end = sel.end < 0 ? _contentController.text.length : sel.end;
    _contentController.value = _contentController.value.copyWith(
      text: _contentController.text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
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
      selection: TextSelection.collapsed(offset: sel.start + prefix.length),
    );
  }

  KeyEventResult _handleForumKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.keyV) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final controlOrMeta = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (!controlOrMeta ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    // Ctrl+V detected with no modifiers besides Ctrl/Meta.
    _handleClipboardPasteForForum();
    return KeyEventResult.handled;
  }

  Future<void> _handleClipboardPasteForForum() async {
    final service = ClipboardAttachmentService.instance;
    final files = await service.checkAndReadFiles();
    if (files.isEmpty) {
      // Clipboard only has text – insert it manually.
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        try {
          final reader = await clipboard.read();
          final text = await reader.readValue(Formats.plainText);
          if (text != null && text.isNotEmpty && mounted) {
            final value = _contentController.value;
            final selection = value.selection;
            final start =
                selection.isValid ? selection.start : value.text.length;
            final end =
                selection.isValid ? selection.end : value.text.length;
            _contentController.value = value.copyWith(
              text: value.text.replaceRange(start, end, text),
              selection: TextSelection.collapsed(offset: start + text.length),
              composing: TextRange.empty,
            );
          }
        } catch (_) {}
      }
      return;
    }
    await _uploadClipboardFiles(files);
  }

  Future<void> _uploadClipboardFiles(
      List<ClipboardFileData> files) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    setState(() => _isUploadingAttachment = true);
    try {
      for (final file in files) {
        final maxSize = await TfApiClient.instance.getMaxFileSize();
        if (maxSize != null && file.bytes.length > maxSize) {
          if (mounted) {
            TouchFishSnackbarService.instance.show(
              AppLocalizations.of(context)!
                  .storageFileTooLarge((maxSize / (1024 * 1024)).round()),
            );
          }
          continue;
        }
        final uploaded = await TfApiClient.instance.uploadFile(
          uid,
          password,
          file.fileName,
          base64Encode(file.bytes),
        );
        final hash =
            (uploaded?['hash'] ?? uploaded?['file_hash'])?.toString();
        if (hash == null || hash.isEmpty || !mounted) continue;
        setState(() {
          _attachments.add(
            FileAttachment(
              hash: hash,
              fileName: file.fileName,
              fileSize: file.fileSize,
              mimeType: lookupMimeType(file.fileName),
            ),
          );
        });
        _scheduleDraftSave();
      }
    } catch (error, stackTrace) {
      talker.error('Forum clipboard upload failed', error, stackTrace);
      if (mounted) {
        TouchFishSnackbarService.instance.show(
          AppLocalizations.of(context)!.forumAttachmentFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    setState(() => _isUploadingAttachment = true);
    try {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final maxSize = await TfApiClient.instance.getMaxFileSize();
        if (maxSize != null && bytes.length > maxSize) {
          if (mounted) {
            TouchFishSnackbarService.instance.show(
              AppLocalizations.of(
                context,
              )!.storageFileTooLarge((maxSize / (1024 * 1024)).round()),
            );
          }
          continue;
        }
        final uploaded = await TfApiClient.instance.uploadFile(
          uid,
          password,
          file.name,
          base64Encode(bytes),
        );
        final hash = (uploaded?['hash'] ?? uploaded?['file_hash'])?.toString();
        if (hash == null || hash.isEmpty || !mounted) continue;
        setState(() {
          _attachments.add(
            FileAttachment(
              hash: hash,
              fileName: file.name,
              fileSize: file.size,
              mimeType: lookupMimeType(file.name),
            ),
          );
        });
        _scheduleDraftSave();
      }
    } catch (error, stackTrace) {
      talker.error('Forum attachment upload failed', error, stackTrace);
      if (mounted) {
        TouchFishSnackbarService.instance.show(
          AppLocalizations.of(context)!.forumAttachmentFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingAttachment) return;
    final hasContent = _contentController.text.trim().isNotEmpty;
    final hasTitle = widget.isReply || _titleController.text.trim().isNotEmpty;
    if (!hasContent && !hasTitle) {
      TouchFishSnackbarService.instance.show(l10n.forumPostContentRequired);
      return;
    }

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final fid = int.tryParse(widget.forumId);
    if (uid == null || password == null || fid == null) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bool success;
      if (widget.isReply) {
        final pid = int.tryParse(widget.postId ?? '');
        if (pid == null) {
          Navigator.pop(context, false);
          return;
        }
        success = await TfApiClient.instance.addComment(
          uid,
          password,
          fid,
          pid,
          _contentController.text.trim(),
        );
      } else {
        success = await TfApiClient.instance.sendPost(
          uid,
          password,
          fid,
          _titleController.text.trim(),
          _contentController.text.trim(),
          attachmentHashes: _attachments.map((file) => file.hash).toList(),
        );
      }
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (success) {
        _didSubmit = true;
        await DraftService.instance.clearDraft(_draftType, _draftId);
        if (!mounted) return;
        TouchFishSnackbarService.instance.show(
          widget.isReply
              ? l10n.forumCommentSuccess
              : l10n.forumPostSuccess,
        );
        Navigator.pop(context, true);
      } else {
        TouchFishSnackbarService.instance.show(
          l10n.forumPostFailed,
        );
      }
    } catch (e) {
      talker.error('_submit post failed', e);
      if (mounted) {
        setState(() => _isSubmitting = false);
        TouchFishSnackbarService.instance.show(
          l10n.forumPostFailed,
        );
      }
    }
  }
}
