import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/markdown_renderer.dart';
import '../models/settings_service.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import 'forum_post_compose_screen.dart';
import '../utils/talker.dart';

const double _kPostDetailMaxWidth = 680;

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
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final fid = int.tryParse(widget.forumId);
      final pid = int.tryParse(widget.postId);
      if (fid == null || pid == null) throw Exception('Invalid IDs');
      final posts = await TfApiClient.instance.getPostList(fid);
      try {
        _post = posts.firstWhere((p) => p.id == widget.postId);
      } catch (_) {
        _post = null;
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
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.forumPostNotFound)),
      );
    }
    final post = _post!;
    final author = _postAuthor;
    final enableMarkdown =
        SettingsService.instance.getValue<bool>('enableMarkdownRendering', true);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(post.title.isNotEmpty ? post.title : l10n.forumPostDetail),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kPostDetailMaxWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildPostBody(
                          context, post, author, enableMarkdown, l10n),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kPostDetailMaxWidth),
                    child: _buildActionButtons(context, l10n),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _kPostDetailMaxWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            l10n.forumComments(_commentDataList.length),
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cd = _commentDataList[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: _kPostDetailMaxWidth),
                          child: _buildCommentCard(
                              context, cd, enableMarkdown),
                        ),
                      );
                    },
                    childCount: _commentDataList.length,
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: bottomPadding + 80),
              ),
            ],
          ),
          Positioned(
            bottom: bottomPadding + 16,
            left: 16,
            right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kPostDetailMaxWidth),
                child: _buildQuickReplyBar(context, l10n),
              ),
            ),
          ),
        ],
      ),
    );
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
        const SizedBox(height: 12),
        if (enableMarkdown)
          MarkdownRenderer(data: post.content)
        else
          Text(
            post.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
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
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRelativeTime(comment.createdAt),
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (enableMarkdown)
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
              child: TextField(
                controller: _commentController,
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
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
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
    );
    if (result == true) {
      _commentController.clear();
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
      final success = await TfApiClient.instance.addComment(uid, password, fid, pid, text);
      if (!mounted) return;
      setState(() => _isSendingComment = false);
      if (success) {
        _commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.forumCommentSuccess)),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.forumCommentFailed), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      talker.error('_submitComment failed', e);
      if (mounted) {
        setState(() => _isSendingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.forumCommentFailed), behavior: SnackBarBehavior.floating),
        );
      }
    }
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
