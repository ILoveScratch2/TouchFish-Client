import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/markdown_renderer.dart';
import '../widgets/sticker_text_renderer.dart';
import '../models/settings_service.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import 'forum_post_compose_screen.dart';
import '../utils/talker.dart';
import '../widgets/mention_text_field.dart';
import '../widgets/forum_attachments.dart';
import '../services/draft_service.dart';
import '../widgets/app_alert_dialog.dart';

const double _kPostDetailMaxWidth = 680;
final _stickerTestPattern = RegExp(r':[A-Za-z0-9_]+\+[A-Za-z0-9_-]+:');

class _CommentData {
  final ForumComment comment;
  UserProfile? author;
  _CommentData(this.comment);
}

class ForumPostDetailScreen extends StatefulWidget {
  final String forumId;
  final String postId;

  const ForumPostDetailScreen({
    super.key,
    required this.forumId,
    required this.postId,
  });

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  ForumPost? _post;
  UserProfile? _postAuthor;
  List<_CommentData> _commentDataList = [];
  bool _isLoading = true;
  bool _isSendingComment = false;
  bool _isDeletingPost = false;
  final Set<String> _deletingCommentIds = {};
  Forum? _forum;
  int _currentForumRole = -1;
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MentionUser> _mentionUsers = [];
  Timer? _draftTimer;

  String get _commentDraftId => '${widget.forumId}/${widget.postId}';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadMentionUsers();
    _commentController.addListener(_scheduleCommentDraftSave);
    unawaited(_restoreCommentDraft());
  }

  void _scheduleCommentDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _saveCommentDraft);
  }

  Future<void> _restoreCommentDraft() async {
    final draft = await DraftService.instance.loadDraft(
      'forum_comment',
      _commentDraftId,
    );
    if (!mounted || _commentController.text.isNotEmpty) return;
    final text = draft?['content'] as String? ?? '';
    if (text.isNotEmpty) _commentController.text = text;
  }

  Future<void> _saveCommentDraft() => DraftService.instance.saveDraft(
    'forum_comment',
    _commentDraftId,
    {'content': _commentController.text},
  );

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final fid = int.tryParse(widget.forumId);
      final pid = int.tryParse(widget.postId);
      if (fid == null || pid == null) throw Exception('Invalid IDs');
      _post = await TfApiClient.instance.getPost(fid, pid);
      final forums = await TfApiClient.instance.getForumList();
      _forum = forums.cast<Forum?>().firstWhere(
        (forum) => forum?.id == widget.forumId,
        orElse: () => null,
      );
      final uid = AuthState.instance.uid;
      final password = AuthState.instance.password;
      if (uid != null && password != null) {
        final memberships = await TfApiClient.instance.getMyMemberships(
          uid,
          password,
        );
        _currentForumRole = memberships
            .where((membership) => membership['fid'] == fid)
            .map((membership) => membership['role'] ?? -1)
            .fold(-1, (current, role) => role > current ? role : current);
      }

      if (_post != null) {
        final authorUid = int.tryParse(_post!.authorUid);
        if (authorUid != null) {
          _postAuthor = await TfApiClient.instance.getUserByUid(authorUid);
        }
      }

      final comments = await TfApiClient.instance.getAllComments(fid, pid);
      _commentDataList = comments.map((c) => _CommentData(c)).toList();

      // Fetch comment authors in parallel
      final authorFutures = _commentDataList.map((cd) async {
        final uid = int.tryParse(cd.comment.authorUid);
        if (uid != null) {
          cd.author = await TfApiClient.instance.getUserByUid(uid);
        }
      });
      await Future.wait(authorFutures);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      talker.error('ForumPostDetail: _loadData failed', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    unawaited(_saveCommentDraft());
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: _leavePost)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: _leavePost)),
        body: Center(child: Text(l10n.forumPostNotFound)),
      );
    }
    final post = _post!;
    final author = _postAuthor;
    final enableMarkdown = SettingsService.instance.getValue<bool>(
      'enableMarkdownRendering',
      true,
    );
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leavePost),
        title: Text(post.title.isNotEmpty ? post.title : l10n.forumPostDetail),
        actions: [
          if (_canDeletePost(post))
            IconButton(
              tooltip: l10n.forumPostDelete,
              onPressed: _isDeletingPost ? null : _deletePost,
              icon: _isDeletingPost
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kPostDetailMaxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildPostBody(
                        context,
                        post,
                        author,
                        enableMarkdown,
                        l10n,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kPostDetailMaxWidth,
                    ),
                    child: _buildActionButtons(context, l10n),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kPostDetailMaxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            l10n.forumComments(_commentDataList.length),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: Divider()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_commentDataList.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 40,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.forumNoComments,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final cd = _commentDataList[index];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _kPostDetailMaxWidth,
                        ),
                        child: _buildCommentCard(context, cd, enableMarkdown),
                      ),
                    );
                  }, childCount: _commentDataList.length),
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 80)),
            ],
          ),
          Positioned(
            bottom: bottomPadding + 16,
            left: 16,
            right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _kPostDetailMaxWidth,
                ),
                child: _buildQuickReplyBar(context, l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _leavePost() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/forum/${widget.forumId}');
    }
  }

  Widget _buildPostBody(
    BuildContext context,
    ForumPost post,
    UserProfile? author,
    bool enableMarkdown,
    AppLocalizations l10n,
  ) {
    final displayName = author?.username ?? 'UID:${post.authorUid}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/user/${post.authorUid}'),
          child: Row(
            children: [
              ProfilePictureWidget(
                avatarUrl: author?.avatar,
                radius: 20,
                fallbackText: displayName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _formatDateTime(post.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.isPinned)
                Chip(
                  label: Text(l10n.forumPinnedPosts),
                  avatar: const Icon(Icons.push_pin, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        if (post.title.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            post.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 12),
        if (_stickerTestPattern.hasMatch(post.content))
          StickerTextRenderer(text: post.content, style: Theme.of(context).textTheme.bodyLarge)
        else if (enableMarkdown)
          MarkdownRenderer(data: post.content)
        else
          Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
        if (post.attachments.isNotEmpty)
          ForumAttachmentsRow(attachments: post.attachments),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          FilledButton.tonalIcon(
            onPressed: () {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            icon: const Icon(Icons.comment_outlined, size: 18),
            label: Text(l10n.forumComments(_commentDataList.length)),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.share_outlined, size: 18),
            label: Text(l10n.forumShare),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(
    BuildContext context,
    _CommentData cd,
    bool enableMarkdown,
  ) {
    final comment = cd.comment;
    final commentAuthor = cd.author;
    final displayName = commentAuthor?.username ?? 'UID:${comment.authorUid}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => context.push('/user/${comment.authorUid}'),
              child: ProfilePictureWidget(
                avatarUrl: commentAuthor?.avatar,
                radius: 16,
                fallbackText: displayName,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_canDeleteComment(comment)) ...[
                        const Spacer(),
                        IconButton(
                          tooltip: AppLocalizations.of(
                            context,
                          )!.forumCommentDelete,
                          visualDensity: VisualDensity.compact,
                          onPressed: _deletingCommentIds.contains(comment.id)
                              ? null
                              : () => _deleteComment(comment),
                          icon: _deletingCommentIds.contains(comment.id)
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        _formatRelativeTime(comment.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_stickerTestPattern.hasMatch(comment.content))
                    StickerTextRenderer(text: comment.content, style: Theme.of(context).textTheme.bodyMedium)
                  else if (enableMarkdown)
                    MarkdownRenderer(data: comment.content)
                  else
                    Text(
                      comment.content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplyBar(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = AuthState.instance.currentUser;

    return Material(
      elevation: 2,
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ProfilePictureWidget(
                avatarUrl: currentUser?.avatar,
                radius: 16,
                fallbackText: currentUser?.username ?? '?',
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: MentionTextField(
                controller: _commentController,
                mentionUsers: _mentionUsers,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(fontSize: 14),
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: l10n.forumCommentPlaceholder,
                  border: InputBorder.none,
                  isDense: true,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _openExpandedEditor,
              icon: const Icon(Icons.open_in_new, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.forumExpandEditor,
            ),
            IconButton(
              onPressed: _isSendingComment ? null : _submitComment,
              icon: _isSendingComment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send, size: 20, color: colorScheme.primary),
              visualDensity: VisualDensity.compact,
              tooltip: l10n.forumCommentSend,
            ),
          ],
        ),
      ),
    );
  }

  void _openExpandedEditor() async {
    final result = await ForumPostComposeSheet.show(
      context,
      forumId: widget.forumId,
      initialContent: _commentController.text,
      isReply: true,
      postId: widget.postId,
      onContentChanged: (text) {
        _commentController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
    );
    if (result == true) {
      _commentController.clear();
      await _loadData();
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final fid = int.tryParse(widget.forumId);
    final pid = int.tryParse(widget.postId);
    if (fid == null || pid == null) return;

    setState(() => _isSendingComment = true);
    try {
      final success = await TfApiClient.instance.addComment(
        uid,
        password,
        fid,
        pid,
        text,
      );
      if (!mounted) return;
      setState(() => _isSendingComment = false);
      if (success) {
        _commentController.clear();
        await DraftService.instance.clearDraft(
          'forum_comment',
          _commentDraftId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.forumCommentSuccess)));
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.forumCommentFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      talker.error('_submitComment failed', e);
      if (mounted) {
        setState(() => _isSendingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.forumCommentFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool get _hasForumModerationAccess =>
      _currentForumRole >= 50 ||
      AuthState.instance.currentUser?.hasAdminAccess == true;

  bool _canDeletePost(ForumPost post) {
    final uid = AuthState.instance.uid?.toString();
    return uid != null &&
        (uid == post.authorUid ||
            uid == _forum?.createdByUid ||
            _hasForumModerationAccess);
  }

  bool _canDeleteComment(ForumComment comment) {
    final uid = AuthState.instance.uid?.toString();
    return uid != null &&
        (uid == comment.authorUid || _hasForumModerationAccess);
  }

  Future<void> _deletePost() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTouchFishInfoDialog<bool>(
      context,
      title: l10n.forumPostDelete,
      message: l10n.forumPostDeleteHint,
      actions: [
        TouchFishDialogAction(label: l10n.cancel, result: false),
        TouchFishDialogAction(
          label: l10n.forumPostDelete,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final fid = int.tryParse(widget.forumId);
    final pid = int.tryParse(widget.postId);
    if (uid == null || password == null || fid == null || pid == null) return;
    setState(() => _isDeletingPost = true);
    final success = await TfApiClient.instance.removePost(
      uid,
      password,
      fid,
      pid,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.forumPostDeleteSuccess)));
      _leavePost();
    } else {
      setState(() => _isDeletingPost = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.forumPostDeleteFailed)));
    }
  }

  Future<void> _deleteComment(ForumComment comment) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTouchFishInfoDialog<bool>(
      context,
      title: l10n.forumCommentDelete,
      message: l10n.forumCommentDeleteHint,
      actions: [
        TouchFishDialogAction(label: l10n.cancel, result: false),
        TouchFishDialogAction(
          label: l10n.forumCommentDelete,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final fid = int.tryParse(widget.forumId);
    final pid = int.tryParse(widget.postId);
    if (uid == null || password == null || fid == null || pid == null) return;
    setState(() => _deletingCommentIds.add(comment.id));
    final success = await TfApiClient.instance.removeComment(
      uid,
      password,
      fid,
      pid,
      comment.id,
    );
    if (!mounted) return;
    setState(() {
      _deletingCommentIds.remove(comment.id);
      if (success) {
        _commentDataList.removeWhere((item) => item.comment.id == comment.id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? l10n.forumCommentDeleteSuccess
              : l10n.forumCommentDeleteFailed,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}y';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}
