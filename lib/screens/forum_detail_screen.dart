import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/markdown_renderer.dart';
import '../models/settings_service.dart';
import 'forum_members_screen.dart';
import 'forum_post_compose_screen.dart';

class ForumDetailScreen extends StatefulWidget {
  final String forumId;
  const ForumDetailScreen({super.key, required this.forumId});

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  late Forum? _forum;
  late ForumMember? _identity;
  late List<ForumPost> _posts;
  late List<ForumPost> _pinnedPosts;
  static const String _currentUserUid = '1';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final forums = ForumDemoData.getDemoForums();
    try {
      _forum = forums.firstWhere((f) => f.id == widget.forumId);
    } catch (_) {
      _forum = null;
    }
    _identity = ForumDemoData.getDemoIdentity(widget.forumId, _currentUserUid);
    final allPosts = ForumDemoData.getDemoPosts(widget.forumId);
    _pinnedPosts = allPosts.where((p) => p.isPinned).toList();
    _posts = allPosts.where((p) => !p.isPinned).toList();
  }

  void _refresh() {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_forum == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.forumNotFound)),
      );
    }
    final forum = _forum!;

    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      body: isWide
          ? _buildWideLayout(context, forum, l10n, colorScheme)
          : _buildNarrowLayout(context, forum, l10n, colorScheme),
      floatingActionButton: _identity != null
          ? FloatingActionButton(
              onPressed: () => _openComposePost(context),
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  Widget _buildWideLayout(BuildContext context, Forum forum, AppLocalizations l10n, ColorScheme colorScheme) {
    return Column(
      children: [
        _buildWideAppBar(context, forum, l10n, colorScheme),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: posts
                Flexible(
                  flex: 3,
                  child: CustomScrollView(
                    slivers: [
                      if (_pinnedPosts.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _buildPinnedPostsCard(context, l10n),
                        ),
                      _buildPostListSliver(context, l10n),
                    ],
                  ),
                ),
                // Right: description + join
                Flexible(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildDescriptionCard(context, forum, l10n),
                        if (_identity == null && forum.isCommunity)
                          _buildJoinCard(context, l10n),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideAppBar(BuildContext context, Forum forum, AppLocalizations l10n, ColorScheme colorScheme) {
    return AppBar(
      leading: BackButton(onPressed: () => context.pop()),
      title: Text(
        forum.name,
        style: TextStyle(color: colorScheme.onPrimaryContainer),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.tertiaryContainer,
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.people),
          onPressed: () => _showMemberList(context),
        ),
        _ForumActionMenu(
          forum: forum,
          identity: _identity,
          onRefresh: _refresh,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, Forum forum, AppLocalizations l10n, ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          leading: BackButton(onPressed: () => context.pop()),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              forum.name,
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
            background: Container(
              color: colorScheme.surfaceContainerHighest,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () => _showMemberList(context),
            ),
            _ForumActionMenu(
              forum: forum,
              identity: _identity,
              onRefresh: _refresh,
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        SliverToBoxAdapter(
          child: _buildDescriptionCard(context, forum, l10n),
        ),
        if (_identity == null && forum.isCommunity)
          SliverToBoxAdapter(
            child: _buildJoinCard(context, l10n),
          ),
        if (_pinnedPosts.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildPinnedPostsCard(context, l10n),
          ),
        _buildPostListSliver(context, l10n),
      ],
    );
  }

  Widget _buildDescriptionCard(BuildContext context, Forum forum, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          title: Text(l10n.forumDescription),
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.only(left: 24, right: 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 8),
              child: Text(
                forum.description,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.tonalIcon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.forumJoinSuccess)),
            );
            _refresh();
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.forumJoin),
        ),
      ),
    );
  }

  Widget _buildPinnedPostsCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.push_pin),
          title: Text(l10n.forumPinnedPosts),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          children: [
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: _pinnedPosts.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      child: _PostCard(
                        post: _pinnedPosts[index],
                        onTap: () => _openPostDetail(context, _pinnedPosts[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostListSliver(BuildContext context, AppLocalizations l10n) {
    if (_posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              l10n.forumNoPosts,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _PostCard(
              post: _posts[index],
              onTap: () => _openPostDetail(context, _posts[index]),
            ),
          );
        },
        childCount: _posts.length,
      ),
    );
  }

  void _showMemberList(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => ForumMemberListSheet(
        forumId: widget.forumId,
        currentIdentity: _identity,
      ),
    );
  }

  void _openPostDetail(BuildContext context, ForumPost post) {
    context.push('/forum/${widget.forumId}/post/${post.id}');
  }

  void _openComposePost(BuildContext context) {
    ForumPostComposeSheet.show(
      context,
      forumId: widget.forumId,
    );
  }
}

class _ForumActionMenu extends StatelessWidget {
  final Forum forum;
  final ForumMember? identity;
  final VoidCallback onRefresh;

  const _ForumActionMenu({
    required this.forum,
    required this.identity,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = (identity?.role ?? 0) >= 100;

    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
        if ((identity?.role ?? 0) >= 50)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.edit, color: Theme.of(context).colorScheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Text(l10n.forumEdit),
              ],
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.forumEdit)),
              );
            },
          ),
        if (isAdmin)
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(Icons.delete, color: Colors.red),
                const SizedBox(width: 12),
                Text(l10n.forumDelete, style: const TextStyle(color: Colors.red)),
              ],
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.forumDelete),
                  content: Text(l10n.forumDeleteHint),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: Text(l10n.forumDelete),
                    ),
                  ],
                ),
              );
            },
          )
        else if (identity != null)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.exit_to_app, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Text(
                  l10n.forumLeave,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.forumLeave),
                  content: Text(l10n.forumLeaveHint),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: Text(l10n.forumLeave),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback? onTap;

  const _PostCard({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final author = UserProfileDemoData.getDemoProfile(post.authorUid);
    final enableMarkdown = SettingsService.instance.getValue<bool>('enableMarkdownRendering', true);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author row
              Row(
                children: [
                  ProfilePictureWidget(
                    avatarUrl: author.avatar,
                    radius: 16,
                    fallbackText: author.username,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author.username,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          _formatDate(post.createdAt),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.isPinned)
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
              if (post.title.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (enableMarkdown)
                MarkdownRenderer(
                  data: post.content.length > 200
                      ? '${post.content.substring(0, 200)}...'
                      : post.content,
                )
              else
                Text(
                  post.content.length > 200
                      ? '${post.content.substring(0, 200)}...'
                      : post.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              // Comment count
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ForumDemoData.getCommentCount(post.id)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              _buildCommentPreview(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentPreview(BuildContext context) {
    final comment = ForumDemoData.getFeaturedComment(post.id);
    if (comment == null) return const SizedBox.shrink();
    final commentAuthor = UserProfileDemoData.getDemoProfile(comment.authorUid);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.forumComments(ForumDemoData.getCommentCount(post.id)),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ProfilePictureWidget(
                  avatarUrl: commentAuthor.avatar,
                  radius: 12,
                  fallbackText: commentAuthor.username,
                ),
                const SizedBox(width: 8),
                Text(
                  commentAuthor.username,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comment.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
