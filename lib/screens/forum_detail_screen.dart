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
import 'forum_members_screen.dart';
import 'forum_post_compose_screen.dart';
import '../utils/talker.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/forum_attachments.dart';
import '../routes/app_routes.dart';

class ForumDetailScreen extends StatefulWidget {
  final String forumId;
  const ForumDetailScreen({super.key, required this.forumId});

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  Forum? _forum;
  ForumMember? _identity;
  List<ForumPost> _posts = [];
  List<ForumPost> _pinnedPosts = [];
  bool _isLoading = true;
  String? _error;
  bool _isMember = false;
  List<ForumMember> _members = const [];
  final Map<String, UserProfile?> _profileCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final fid = int.tryParse(widget.forumId);
      if (fid == null) throw Exception('Invalid forumId');

      final uid = AuthState.instance.uid;
      final password = AuthState.instance.password;

      final results = await Future.wait([
        TfApiClient.instance.getForumList(),
        TfApiClient.instance.getPostList(fid),
        if (uid != null && password != null)
          TfApiClient.instance.getMyMemberships(uid, password),
        if (uid != null && password != null)
          _fetchMembersSafe(uid, password, fid),
      ]);

      try {
        _forum = (results[0] as List<Forum>).firstWhere(
          (f) => f.id == widget.forumId,
        );
      } catch (_) {
        _forum = null;
      }

      final allPosts = results[1] as List<ForumPost>;
      _pinnedPosts = allPosts.where((p) => p.isPinned).toList();
      _posts = allPosts.where((p) => !p.isPinned).toList();
      if (results.length > 2 && results[2] is List<Map<String, int>>) {
        final memberships = results[2] as List<Map<String, int>>;
        _isMember = memberships.any(
          (m) => m['fid'].toString() == widget.forumId,
        );
      }

      if (results.length > 3 && results[3] is List<ForumMember>) {
        _members = results[3] as List<ForumMember>;
        _identity = uid != null
            ? _members.cast<ForumMember?>().firstWhere(
                (m) => m?.accountUid == uid.toString(),
                orElse: () => null,
              )
            : null;
      } else {
        _members = const [];
        _identity = null;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      talker.error('ForumDetailScreen: _loadData failed', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Try to fetch members; returns empty list if access is denied.
  Future<List<ForumMember>> _fetchMembersSafe(
    int uid,
    String password,
    int fid,
  ) async {
    try {
      return await TfApiClient.instance.getMembers(uid, password, fid);
    } catch (_) {
      return const [];
    }
  }

  void _refresh() => _loadData();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _forum == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _forum == null ? l10n.forumNotFound : l10n.forumPostLoadFailed,
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _refresh, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }
    final forum = _forum!;

    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      body: isWide
          ? _buildWideLayout(context, forum, l10n, colorScheme)
          : _buildNarrowLayout(context, forum, l10n, colorScheme),
      floatingActionButton: AuthState.instance.isLoggedIn
          ? FloatingActionButton(
              onPressed: () => _openComposePost(context),
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    Forum forum,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
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
                        if (!_isMember) _buildJoinCard(context, l10n),
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

  Widget _buildWideAppBar(
    BuildContext context,
    Forum forum,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      leading: BackButton(onPressed: () => _leaveForum(context)),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfilePictureWidget(
            avatarUrl: forum.avatarUrl,
            radius: 16,
            fallbackIcon: Icons.forum,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              forum.name,
              style: TextStyle(color: colorScheme.onPrimaryContainer),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
        if ((_identity?.role ?? 0) >= 50)
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => _showMemberList(context),
          ),
        _ForumActionMenu(
          forum: forum,
          identity: _identity,
          isMember: _isMember,
          onRefresh: _refresh,
          onEditForum: () => _handleEditForum(context),
          onPinPost: () => _handlePinPost(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    Forum forum,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          leading: BackButton(onPressed: () => _leaveForum(context)),
          flexibleSpace: FlexibleSpaceBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfilePictureWidget(
                  avatarUrl: forum.avatarUrl,
                  radius: 14,
                  fallbackIcon: Icons.forum,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    forum.name,
                    style: TextStyle(color: colorScheme.onPrimaryContainer),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            background: Container(color: colorScheme.surfaceContainerHighest),
          ),
          actions: [
            if ((_identity?.role ?? 0) >= 50)
              IconButton(
                icon: const Icon(Icons.people),
                onPressed: () => _showMemberList(context),
              ),
            _ForumActionMenu(
              forum: forum,
              identity: _identity,
              isMember: _isMember,
              onRefresh: _refresh,
              onEditForum: () => _handleEditForum(context),
              onPinPost: () => _handlePinPost(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        SliverToBoxAdapter(child: _buildDescriptionCard(context, forum, l10n)),
        if (!_isMember)
          SliverToBoxAdapter(child: _buildJoinCard(context, l10n)),
        if (_pinnedPosts.isNotEmpty)
          SliverToBoxAdapter(child: _buildPinnedPostsCard(context, l10n)),
        _buildPostListSliver(context, l10n),
      ],
    );
  }

  void _leaveForum(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.forum);
    }
  }

  Widget _buildDescriptionCard(
    BuildContext context,
    Forum forum,
    AppLocalizations l10n,
  ) {
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
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 16,
                top: 8,
              ),
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
          onPressed: () async {
            final uid = AuthState.instance.uid;
            final password = AuthState.instance.password;
            final fid = int.tryParse(widget.forumId);
            if (uid == null || password == null || fid == null) return;
            final ok = await TfApiClient.instance.joinForum(uid, password, fid);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? l10n.forumJoinSuccess : l10n.forumCreateFailed,
                  ),
                ),
              );
              if (ok) setState(() => _isMember = true);
            }
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
          children: _pinnedPosts
              .map(
                (post) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: _PostCard(
                    post: post,
                    onTap: () => _openPostDetail(context, post),
                    profileCache: _profileCache,
                  ),
                ),
              )
              .toList(),
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
      delegate: SliverChildBuilderDelegate((context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _PostCard(
            post: _posts[index],
            onTap: () => _openPostDetail(context, _posts[index]),
            profileCache: _profileCache,
          ),
        );
      }, childCount: _posts.length),
    );
  }

  void _showMemberList(BuildContext context) async {
    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => ForumMemberListSheet(
        forumId: widget.forumId,
        currentIdentity: _identity,
        members: _members,
      ),
    );
    if (mounted) _refresh();
  }

  void _openPostDetail(BuildContext context, ForumPost post) async {
    await context.push('/forum/${widget.forumId}/post/${post.id}');
    if (mounted) _refresh();
  }

  void _openComposePost(BuildContext context) async {
    final result = await ForumPostComposeSheet.show(
      context,
      forumId: widget.forumId,
    );
    if (result == true && mounted) {
      _refresh();
    }
  }

  void _handleEditForum(BuildContext context) async {
    if (_forum == null) return;
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: _forum!.name);
    final introController = TextEditingController(text: _forum!.description);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.forumEdit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.forumPostTitle,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: introController,
              decoration: InputDecoration(
                labelText: l10n.forumPostDescription,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    nameController.dispose();
    introController.dispose();
    if (confirmed != true || !mounted) return;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final fid = int.tryParse(widget.forumId);
    if (uid == null || password == null || fid == null) return;

    final ok = await TfApiClient.instance.editForum(
      uid,
      password,
      fid,
      forumName: nameController.text.trim(),
      introduction: introController.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l10n.forumEdit : l10n.forumCreateFailed)),
    );
    if (ok) _refresh();
  }

  void _handlePinPost(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final allPosts = [..._pinnedPosts, ..._posts];
    if (allPosts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.forumNoPosts)));
      return;
    }
    final selectedPid = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 16,
                left: 20,
                right: 16,
                bottom: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.forumPinPost,
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                itemCount: allPosts.length,
                itemBuilder: (_, i) => ListTile(
                  leading: allPosts[i].isPinned
                      ? Icon(
                          Icons.push_pin,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  title: Text(
                    allPosts[i].title.isNotEmpty
                        ? allPosts[i].title
                        : '(untitled)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    allPosts[i].content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(ctx, allPosts[i].id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (selectedPid == null || !mounted) return;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final fid = int.tryParse(widget.forumId);
    final pid = int.tryParse(selectedPid);
    if (uid == null || password == null || fid == null || pid == null) return;

    final ok = await TfApiClient.instance.pinPost(uid, password, fid, pid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l10n.forumPinPost : l10n.forumCreateFailed)),
    );
    if (ok) _refresh();
  }
}

class _ForumActionMenu extends StatelessWidget {
  final Forum forum;
  final ForumMember? identity;
  final bool isMember;
  final VoidCallback onRefresh;
  final VoidCallback onEditForum;
  final VoidCallback onPinPost;

  const _ForumActionMenu({
    required this.forum,
    required this.identity,
    required this.isMember,
    required this.onRefresh,
    required this.onEditForum,
    required this.onPinPost,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = (identity?.role ?? 0) >= 100;

    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
        if ((identity?.role ?? 0) >= 50) ...[
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Text(l10n.forumEdit),
              ],
            ),
            onTap: onEditForum,
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.push_pin,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(l10n.forumPinPost),
              ],
            ),
            onTap: onPinPost,
          ),
        ],
        if (isAdmin)
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(Icons.delete, color: Colors.red),
                const SizedBox(width: 12),
                Text(
                  l10n.forumDelete,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
            onTap: () => _handleDelete(context, l10n),
          )
        else if (isMember)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_remove,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.forumLeave,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
            onTap: () => _handleLeave(context, l10n),
          ),
      ],
    );
  }

  void _handleDelete(BuildContext context, AppLocalizations l10n) {
    showTouchFishErrorDialog<bool>(
      context,
      title: l10n.forumDelete,
      message: l10n.forumDeleteHint,
      icon: Icons.delete_outline_rounded,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.forumDelete,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    ).then((confirmed) async {
      if (confirmed == true && context.mounted) {
        final uid = AuthState.instance.uid;
        final password = AuthState.instance.password;
        final fid = int.tryParse(forum.id);
        if (uid == null || password == null || fid == null) return;
        final success = await TfApiClient.instance.removeForum(
          uid,
          password,
          fid,
        );
        if (!context.mounted) return;
        if (success) {
          context.pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.forumDeleteSuccess)));
          onRefresh();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.forumDeleteFailed),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  void _handleLeave(BuildContext context, AppLocalizations l10n) {
    showTouchFishErrorDialog<bool>(
      context,
      title: l10n.forumLeave,
      message: l10n.forumLeaveHint,
      icon: Icons.exit_to_app_rounded,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.forumLeave,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    ).then((confirmed) async {
      if (confirmed == true && context.mounted) {
        final uid = AuthState.instance.uid;
        final password = AuthState.instance.password;
        final fid = int.tryParse(forum.id);
        if (uid == null || password == null || fid == null) return;
        await TfApiClient.instance.leaveForumApi(uid, password, fid);
        onRefresh();
      }
    });
  }
}

class _PostCard extends StatefulWidget {
  final ForumPost post;
  final VoidCallback? onTap;
  final Map<String, UserProfile?>? profileCache;

  const _PostCard({required this.post, this.onTap, this.profileCache});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  UserProfile? _author;
  List<ForumComment>? _comments;
  UserProfile? _featuredCommentAuthor;
  bool _loaded = false;

  ForumPost get post => widget.post;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.authorUid != widget.post.authorUid) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final fid = int.tryParse(post.forumId);
    final pid = int.tryParse(post.id);
    final authorUid = post.authorUid;
    final cache = widget.profileCache;

    UserProfile? author;
    List<ForumComment>? comments;
    UserProfile? featuredAuthor;

    if (cache != null && cache.containsKey(authorUid)) {
      author = cache[authorUid];
    } else {
      final uid = int.tryParse(authorUid);
      if (uid != null) {
        author = await TfApiClient.instance.getUserByUid(uid);
        cache?[authorUid] = author;
      }
    }
    if (fid != null && pid != null) {
      comments = await TfApiClient.instance.getAllComments(fid, pid);
      if (comments.isNotEmpty) {
        final lastCommentUid = comments.last.authorUid;
        if (cache != null && cache.containsKey(lastCommentUid)) {
          featuredAuthor = cache[lastCommentUid];
        } else {
          final uid = int.tryParse(lastCommentUid);
          if (uid != null) {
            featuredAuthor = await TfApiClient.instance.getUserByUid(uid);
            cache?[lastCommentUid] = featuredAuthor;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _author = author;
        _comments = comments;
        _featuredCommentAuthor = featuredAuthor;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enableMarkdown = SettingsService.instance.getValue<bool>(
      'enableMarkdownRendering',
      true,
    );
    final author = _author;
    final comments = _comments;
    final commentCount = comments?.length ?? 0;
    final featuredComment = comments?.isNotEmpty == true
        ? comments!.last
        : null;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfilePictureWidget(
                    avatarUrl: author?.avatar,
                    radius: 16,
                    fallbackText: author?.username ?? post.authorUid,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author?.username ?? 'UID:${post.authorUid}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          _formatDate(post.createdAt),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
              const SizedBox(height: 8),
              if (_loaded)
                Row(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$commentCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '...',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              if (featuredComment != null)
                _buildCommentPreview(context, featuredComment, commentCount),
              if (post.attachments.isNotEmpty)
                ForumAttachmentsRow(attachments: post.attachments),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentPreview(
    BuildContext context,
    ForumComment comment,
    int commentCount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final commentAuthor = _featuredCommentAuthor;
    final displayName = commentAuthor?.username ?? 'UID:${comment.authorUid}';

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
              l10n.forumComments(commentCount),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ProfilePictureWidget(
                  avatarUrl: commentAuthor?.avatar,
                  radius: 12,
                  fallbackText: displayName,
                ),
                const SizedBox(width: 8),
                Text(
                  displayName,
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
