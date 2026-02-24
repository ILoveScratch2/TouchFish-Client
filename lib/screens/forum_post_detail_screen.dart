import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/markdown_renderer.dart';
import '../models/settings_service.dart';
import 'forum_post_compose_screen.dart';

const double _kPostDetailMaxWidth = 680;

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
  late ForumPost? _post;
  late List<ForumComment> _comments;
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final allPosts = ForumDemoData.getDemoPosts(widget.forumId);
    try {
      _post = allPosts.firstWhere((p) => p.id == widget.postId);
    } catch (_) {
      _post = null;
    }
    _comments = ForumDemoData.getDemoComments(widget.postId);
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

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.forumPostNotFound)),
      );
    }
    final post = _post!;
    final author = UserProfileDemoData.getDemoProfile(post.authorUid);
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
                            l10n.forumComments(_comments.length),
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
              if (_comments.isEmpty)
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
                      final comment = _comments[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: _kPostDetailMaxWidth),
                          child: _buildCommentCard(
                              context, comment, enableMarkdown),
                        ),
                      );
                    },
                    childCount: _comments.length,
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
    UserProfile author,
    bool enableMarkdown,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/user/${post.authorUid}'),
          child: Row(
            children: [
              ProfilePictureWidget(
                avatarUrl: author.avatar,
                radius: 20,
                fallbackText: author.username,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.username,
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
            label: Text(l10n.forumComments(_comments.length)),
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
    ForumComment comment,
    bool enableMarkdown,
  ) {
    final commentAuthor =
        UserProfileDemoData.getDemoProfile(comment.authorUid);
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
                avatarUrl: commentAuthor.avatar,
                radius: 16,
                fallbackText: commentAuthor.username,
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
                        commentAuthor.username,
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
    final currentUser = UserProfileDemoData.getDemoProfile('1');

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
                avatarUrl: currentUser.avatar,
                radius: 16,
                fallbackText: currentUser.username,
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
              onPressed: _submitComment,
              icon: Icon(Icons.send, size: 20, color: colorScheme.primary),
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

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.forumCommentSuccess)),
    );
    _commentController.clear();
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
