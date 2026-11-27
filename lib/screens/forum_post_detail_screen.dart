import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../models/support_ticket.dart';
import '../widgets/support/ticket_compose_sheet.dart';
import '../models/forum_model.dart';
import '../models/user_profile.dart';
import '../theme/tokens.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/markdown_renderer.dart';
import '../widgets/sticker_text_renderer.dart';
import '../widgets/ui/skeleton.dart';
import '../models/settings_service.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/forum_data_bus.dart';
import '../services/snackbar_service.dart';
import 'forum_post_compose_screen.dart';
import '../utils/talker.dart';
import '../utils/clipboard_utils.dart';
import '../widgets/mention_text_field.dart';
import '../widgets/forum_attachments.dart';
import '../widgets/layout/forum_post_pane_scope.dart';
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
  String _lastCommentText = '';
  int _draftRevision = 0;
  int _loadSequence = 0;
  bool _showBackToBottom = false;
  bool _enableMarkdown = true;

  String get _commentDraftId => '${widget.forumId}/${widget.postId}';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _enableMarkdown = SettingsService.instance.getValue<bool>(
      'enableMarkdownRendering',
      true,
    );
    SettingsService.instance.addListener(_onSettingsChanged);
    ForumDataBus.instance.change.addListener(_onForumDataChanged);
    _loadData();
    _loadMentionUsers();
    _commentController.addListener(_scheduleCommentDraftSave);
    unawaited(_restoreCommentDraft());
  }

  void _onSettingsChanged() {
    final next = SettingsService.instance.getValue<bool>(
      'enableMarkdownRendering',
      true,
    );
    if (next != _enableMarkdown && mounted) {
      setState(() => _enableMarkdown = next);
    }
  }

  /// 本篇帖子的评论发生变化后重载
  void _onForumDataChanged() {
    if (!mounted || _isDeletingPost) return;
    if (ForumDataBus.instance.change.value.postId != widget.postId) return;
    unawaited(_loadData(showLoading: false));
  }

  /// 只换路径参数（换帖子 / 换论坛）时 Flutter 会复用同一个 State，
  /// 那样页面会停在上一个帖子的数据上，这里按新参数重新加载。
  @override
  void didUpdateWidget(covariant ForumPostDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId == widget.postId &&
        oldWidget.forumId == widget.forumId) {
      return;
    }
    _flushCommentDraft('${oldWidget.forumId}/${oldWidget.postId}');
    _draftRevision++;
    _lastCommentText = '';
    _commentController.clear();
    _post = null;
    _postAuthor = null;
    _commentDataList = [];
    _forum = null;
    _currentForumRole = -1;
    _isSendingComment = false;
    _isDeletingPost = false;
    _deletingCommentIds.clear();
    _loadData();
    _loadMentionUsers();
    unawaited(_restoreCommentDraft());
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.pixels >= pos.maxScrollExtent - 100;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final showBackToBottom = !_isNearBottom;
    if (_showBackToBottom != showBackToBottom && mounted) {
      setState(() => _showBackToBottom = showBackToBottom);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _scheduleCommentDraftSave() {
    final text = _commentController.text;
    if (text == _lastCommentText) return;
    _lastCommentText = text;
    _draftRevision++;
    _draftTimer?.cancel();
    final draftId = _commentDraftId;
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_saveCommentDraft(draftId, text));
    });
  }

  Future<void> _restoreCommentDraft() async {
    final revision = _draftRevision;
    try {
      final draft = await DraftService.instance.loadDraft(
        'forum_comment',
        _commentDraftId,
      );
      if (!mounted || revision != _draftRevision) return;
      final text = draft?['content'] as String? ?? '';
      _lastCommentText = text;
      _commentController.text = text;
    } catch (e) {
      talker.error('ForumPostDetail: restore comment draft failed', e);
    }
  }

  void _flushCommentDraft(String draftId) {
    if (_draftTimer?.isActive != true) return;
    _draftTimer?.cancel();
    unawaited(_saveCommentDraft(draftId, _commentController.text));
  }

  Future<void> _saveCommentDraft(String draftId, String text) async {
    try {
      await DraftService.instance.saveDraft('forum_comment', draftId, {
        'content': text,
      });
    } catch (e) {
      talker.error('ForumPostDetail: save comment draft failed', e);
    }
  }

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

  Future<void> _loadData({bool showLoading = true}) async {
    if (!mounted) return;
    final sequence = ++_loadSequence;
    if (showLoading) setState(() => _isLoading = true);
    try {
      final fid = int.tryParse(widget.forumId);
      final pid = int.tryParse(widget.postId);
      if (fid == null || pid == null) throw Exception('Invalid IDs');
      final api = TfApiClient.instance;
      final uid = AuthState.instance.uid;
      final password = AuthState.instance.password;
      final (post, forums, memberships, comments) = await (
        api.getPost(fid, pid),
        api.getForumList(),
        uid != null && password != null
            ? api.getMyMemberships(uid, password)
            : Future.value(const <Map<String, int>>[]),
        api.getAllComments(fid, pid),
      ).wait;
      if (!mounted || sequence != _loadSequence) return;

      final forum = forums.cast<Forum?>().firstWhere(
        (forum) => forum?.id == fid.toString(),
        orElse: () => null,
      );
      final role = memberships
          .where((membership) => membership['fid'] == fid)
          .map((membership) => membership['role'] ?? -1)
          .fold(-1, (current, role) => role > current ? role : current);
      final postAuthorUid = int.tryParse(post?.authorUid ?? '');
      final authorUids = <int>{
        ?postAuthorUid,
        for (final comment in comments)
          if (int.tryParse(comment.authorUid) case final int uid) uid,
      };
      final authors = await api.getUsersByUids(authorUids);
      final commentData = [
        for (final comment in comments)
          _CommentData(comment)..author = authors[int.tryParse(comment.authorUid)],
      ];
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        _post = post;
        _forum = forum;
        _currentForumRole = role;
        _postAuthor = authors[postAuthorUid];
        _commentDataList = commentData;
        _isLoading = false;
      });
    } catch (e) {
      talker.error('ForumPostDetail: _loadData failed', e);
      if (mounted && sequence == _loadSequence) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    ForumDataBus.instance.change.removeListener(_onForumDataChanged);
    _flushCommentDraft(_commentDraftId);
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 分屏里的整屏查看 / 恢复分栏按钮
  List<Widget> _buildFullScreenActions(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final scope = ForumPostPaneScope.maybeOf(context);
    if (scope == null) return const [];
    return [
      IconButton(
        tooltip: scope.fullScreen
            ? l10n.forumPostRestoreSplitView
            : l10n.forumPostFullScreen,
        onPressed: scope.toggleFullScreen,
        icon: Icon(scope.fullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leavePost),
          actions: _buildFullScreenActions(context, l10n),
        ),
        body: const _PostDetailSkeleton(),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leavePost),
          actions: _buildFullScreenActions(context, l10n),
        ),
        body: Center(child: Text(l10n.forumPostNotFound)),
      );
    }
    final post = _post!;
    final author = _postAuthor;
    // 来自页面级缓存
    final enableMarkdown = _enableMarkdown;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leavePost),
        title: Text(post.title.isNotEmpty ? post.title : l10n.forumPostDetail),
        actions: [
          ..._buildFullScreenActions(context, l10n),
          // 举报入口
          // 帖子详情
          IconButton(
            tooltip: l10n.ticketReport,
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => showTicketComposeSheet(
              context,
              type: TicketType.report,
              targetType: 'post',
              targetId: '${widget.forumId}:${widget.postId}',
              initialTitle: l10n.ticketReport,
            ),
          ),
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
          _PaneEnterAnimation(
            child: CustomScrollView(
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
          if (_showBackToBottom)
            Positioned(
              bottom: bottomPadding + 88,
              right: 4,
              child: FloatingActionButton.small(
                heroTag: 'forum-post-back-to-bottom',
                tooltip: l10n.chatBackToBottom,
                onPressed: _scrollToBottom,
                child: const Icon(Icons.arrow_downward),
              ),
            ),
        ],
      ),
    );
  }

  /// nodel
  /// a very important note
  /// 使用 MediaQuery.textScaler 放大正文不可行
  /// Markdown 的列表项文字渲染在嵌套的 Text.rich 整树放大会导致列表项比段落多一次
  static const double _kPostContentScale = 1.2;

  TextStyle? _postBodyTextStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    if (base == null) return null;
    return base.copyWith(
      fontSize: (base.fontSize ?? 16) * _kPostContentScale,
    );
  }

  Widget _buildPostContent(
    BuildContext context,
    ForumPost post,
    bool enableMarkdown,
  ) {
    if (_stickerTestPattern.hasMatch(post.content)) {
      return StickerTextRenderer(
        text: post.content,
        style: _postBodyTextStyle(context),
      );
    }
    if (enableMarkdown) {
      return MarkdownRenderer(
        data: post.content,
        selectable: true,
        contentScale: _kPostContentScale,
      );
    }
    return SelectableText(
      post.content,
      style: _postBodyTextStyle(context),
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
        // 正文比评论大一号
        _buildPostContent(context, post, enableMarkdown),
        if (post.attachments.isNotEmpty)
          ForumAttachmentsRow(attachments: post.attachments),
        const SizedBox(height: 8),
      ],
    );
  }

  void _copyPostContent() {
    if (_post == null) return;

    final buffer = StringBuffer();

    // 添加标题
    if (_post!.title.isNotEmpty) {
      buffer.writeln(_post!.title);
      buffer.writeln();
    }

    // 添加内容
    buffer.writeln(_post!.content);

    // 添加来源标记
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln(AppLocalizations.of(context)!.forumPostCopySource);

    // 复制到剪贴板
    _copyText(buffer.toString());
  }

  /// 系统分享
  Future<void> _sharePost() async {
    final post = _post;
    if (post == null) return;
    final l10n = AppLocalizations.of(context)!;

    final buffer = StringBuffer();
    if (post.title.isNotEmpty) {
      buffer.writeln(post.title);
      buffer.writeln();
    }
    buffer.writeln(post.content);
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln(l10n.forumPostCopySource);

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: post.title.isEmpty ? null : post.title,
        ),
      );
    } catch (e) {
      talker.error('share post failed', e);
      if (!mounted) return;
      TouchFishSnackbarService.instance.showError(l10n.forumPostShareFailed);
    }
  }

  Future<void> _copyText(String text) async {
    final l10n = AppLocalizations.of(context)!;
    final copied = await copyTextToClipboard(text);
    if (!mounted) return;
    TouchFishSnackbarService.instance.show(
      copied ? l10n.forumPostCopied : l10n.copyFailedText,
      type: copied ? SnackbarType.info : SnackbarType.error,
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
            onPressed: _copyPostContent,
            icon: const Icon(Icons.content_copy_outlined, size: 18),
            label: Text(l10n.forumCopyPost),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _sharePost,
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
                    StickerTextRenderer(
                      text: comment.content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else if (enableMarkdown)
                    MarkdownRenderer(data: comment.content, selectable: true)
                  else
                    SelectableText(
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
              onPressed: _isSendingComment ? null : _openExpandedEditor,
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
    final draftId = _commentDraftId;
    final result = await ForumPostComposeSheet.show(
      context,
      forumId: widget.forumId,
      initialContent: _commentController.text,
      isReply: true,
      postId: widget.postId,
      onContentChanged: (text) {
        if (!mounted || draftId != _commentDraftId) return;
        _commentController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
    );
    if (!mounted || result != true || draftId != _commentDraftId) return;
    _draftTimer?.cancel();
    _lastCommentText = '';
    _commentController.clear();
  }

  Future<void> _submitComment() async {
    if (_isSendingComment) return;
    final draftId = _commentDraftId;
    final enteredText = _commentController.text;
    final text = enteredText.trim();
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
      if (!mounted || draftId != _commentDraftId) return;
      if (success) {
        if (_commentController.text == enteredText) {
          _commentController.clear();
        }
        TouchFishSnackbarService.instance.show(l10n.forumCommentSuccess);
        ForumDataBus.instance.notifyPostsChanged(postId: widget.postId);
      } else {
        TouchFishSnackbarService.instance.show(l10n.forumCommentFailed);
      }
    } catch (e) {
      talker.error('_submitComment failed', e);
      if (mounted && draftId == _commentDraftId) {
        TouchFishSnackbarService.instance.show(l10n.forumCommentFailed);
      }
    } finally {
      if (mounted && draftId == _commentDraftId) {
        setState(() => _isSendingComment = false);
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
      TouchFishSnackbarService.instance.show(l10n.forumPostDeleteSuccess);
      ForumDataBus.instance.notifyPostsChanged();
      _leavePost();
    } else {
      setState(() => _isDeletingPost = false);
      TouchFishSnackbarService.instance.show(l10n.forumPostDeleteFailed);
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
    TouchFishSnackbarService.instance.show(
      success ? l10n.forumCommentDeleteSuccess : l10n.forumCommentDeleteFailed,
    );
    if (success) ForumDataBus.instance.notifyPostsChanged(postId: widget.postId);
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) return _formatDateTime(date);
    if (diff.inDays > 0) return l10n.forumTimeDaysAgo(diff.inDays);
    if (diff.inHours > 0) return l10n.forumTimeHoursAgo(diff.inHours);
    if (diff.inMinutes > 0) return l10n.forumTimeMinutesAgo(diff.inMinutes);
    return l10n.forumTimeJustNow;
  }
}

/// 帖子详情
class _PostDetailSkeleton extends StatelessWidget {
  const _PostDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ListView(
      padding: const EdgeInsets.all(TFSpace.lg),
      children: [
        Row(
          children: [
            const SkeletonBox(
              width: TFSize.avatarMd,
              height: TFSize.avatarMd,
              borderRadius: TFRadius.pillRadius,
            ),
            const SizedBox(width: TFSpace.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 12),
                SizedBox(height: TFSpace.sm),
                SkeletonBox(width: 80, height: 10),
              ],
            ),
          ],
        ),
        const SizedBox(height: TFSpace.xxl),
        const SkeletonBox(width: double.infinity, height: 22),
        const SizedBox(height: TFSpace.md),
        const SkeletonBox(width: double.infinity, height: 14),
        const SizedBox(height: TFSpace.sm),
        const SkeletonBox(width: double.infinity, height: 14),
        const SizedBox(height: TFSpace.sm),
        SkeletonBox(width: (width * 0.6).clamp(120.0, width), height: 14),
        const SizedBox(height: TFSpace.xxl),
        const SkeletonBox(width: double.infinity, height: 56),
      ],
    );
  }
}

class _PaneEnterAnimation extends StatefulWidget {  final Widget child;

  const _PaneEnterAnimation({required this.child});

  @override
  State<_PaneEnterAnimation> createState() => _PaneEnterAnimationState();
}

class _PaneEnterAnimationState extends State<_PaneEnterAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.035, 0),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}


