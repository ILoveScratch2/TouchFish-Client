import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/optimized_image.dart';
import '../models/settings_service.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/forum_data_bus.dart';
import '../services/snackbar_service.dart';
import 'forum_members_screen.dart';
import 'forum_post_compose_screen.dart';
import '../utils/talker.dart';
import '../utils/wide_screen_helper.dart';
import '../widgets/app_alert_dialog.dart';
import '../theme/tokens.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/loading_indicator.dart';
import '../widgets/ui/tri_state_filter_chip.dart';
import '../widgets/forum_action_menu.dart';
import '../widgets/forum_post_card.dart';
import '../routes/app_routes.dart';

class ForumDetailScreen extends StatefulWidget {
  final String forumId;

  final bool isAside;

  /// 分栏时右栏正在看的那篇帖子 id（没打开帖子为 null）。
  ///
  /// 左栏常驻不重建（`context.go` 只是换路由）
  final String? openPostId;

  const ForumDetailScreen({
    super.key,
    required this.forumId,
    this.isAside = false,
    this.openPostId,
  });

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  Forum? _forum;
  ForumMember? _identity;
  List<ForumPost> _posts = [];

  /// 帖子列表筛选：是否有附件 / 是否我发布。默认不限。
  TriStateFilter _filterAttachment = TriStateFilter.any;
  TriStateFilter _filterMine = TriStateFilter.any;
  List<ForumPost> _pinnedPosts = [];
  bool _isLoading = true;
  String? _error;
  bool _isMember = false;
  List<ForumMember> _members = const [];
  final Map<String, UserProfile?> _profileCache = {};
  final ScrollController _scrollController = ScrollController();
  final PageController _pinnedPageController = PageController();
  int _pinnedPage = 0;
  bool _showBackToBottom = false;
  Timer? _refreshDebounce;
  static const int _postPageSize = 30;

  /// 页面级读一次
  bool _enableMarkdown = true;
  bool _hasMorePosts = false;
  int? _nextBeforePid;
  bool _isLoadingMore = false;
  bool _loadMoreFailed = false;

  int _listSeq = 0;

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
  }

  /// 右栏操作后同步
  void _onForumDataChanged() => _scheduleRefresh();

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _refreshPostsOnly();
    });
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

  /// 换论坛时 Flutter 会复用同一个 State
  ///
  @override
  void didUpdateWidget(covariant ForumDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forumId != widget.forumId) {
      _loadData();
      return;
    }
    // 分栏下关或换
    if (oldWidget.openPostId != widget.openPostId &&
        oldWidget.openPostId != null) {
      _scheduleRefresh();
    }
    if (oldWidget.isAside == widget.isAside) return;

    // 旧布局还挂着
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : null;
    if (offset == null || offset <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset.clamp(0.0, max));
    });
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.pixels >= pos.maxScrollExtent - 100;
  }

  String _errorText(AppLocalizations l10n) =>
      _error != null ? l10n.forumPostLoadFailed : l10n.forumNotFound;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final showBackToBottom = !_isNearBottom;
    if (_showBackToBottom != showBackToBottom && mounted) {
      setState(() => _showBackToBottom = showBackToBottom);
    }
    if (_isNearBottom && _hasMorePosts && !_isLoadingMore && !_loadMoreFailed) {
      unawaited(_loadMorePosts());
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;
    final fid = int.tryParse(widget.forumId);
    if (fid == null) return;
    final beforePid = _nextBeforePid;
    if (beforePid == null) {
      talker.warning(
        'ForumDetailScreen: has_more without next_before_pid, stopping',
      );
      if (mounted) setState(() => _hasMorePosts = false);
      return;
    }
    setState(() {
      _isLoadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final page = await TfApiClient.instance.getPostList(
        fid,
        beforePid: beforePid,
        limit: _postPageSize,
      );
      if (!mounted || widget.forumId != fid.toString()) return;
      final known = _posts.map((post) => post.id).toSet();
      setState(() {
        if (_pinnedPosts.isEmpty) {
          final pinnedFromPage = page.posts.where((post) => post.isPinned);
          if (pinnedFromPage.isNotEmpty) {
            _pinnedPosts = pinnedFromPage.toList();
          }
        }
        _posts = [
          ..._posts,
          ...page.posts.where(
            (post) => !post.isPinned && !known.contains(post.id),
          ),
        ]..sort(ForumPost.compareNewestFirst);
        _hasMorePosts = page.hasMore;
        _nextBeforePid = page.nextBeforePid;
      });
    } catch (e) {
      talker.error('ForumDetailScreen: load more posts failed', e);
      if (mounted) setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
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

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    ForumDataBus.instance.change.removeListener(_onForumDataChanged);
    _refreshDebounce?.cancel();
    _scrollController.dispose();
    _pinnedPageController.dispose();
    super.dispose();
  }

  /// 拉取论坛帖子列表。
  Future<void> _loadData({bool showLoading = true}) async {
    _listSeq++;
    setState(() {
      if (showLoading) _isLoading = true;
      _error = null;
    });
    try {
      final fid = int.tryParse(widget.forumId);
      if (fid == null) throw Exception('Invalid forumId');

      final uid = AuthState.instance.uid;
      final password = AuthState.instance.password;

      final results = await Future.wait([
        TfApiClient.instance.getForumList(throwOnError: true),
        TfApiClient.instance.getPostList(fid, limit: _postPageSize),
        if (uid != null && password != null)
          TfApiClient.instance.getMyMemberships(uid, password),
      ]);

      try {
        _forum = (results[0] as List<Forum>).firstWhere(
          (f) => f.id == widget.forumId,
        );
      } catch (_) {
        _forum = null;
      }

      final postPage =
          results[1]
              as ({
                List<ForumPost> posts,
                bool hasMore,
                int? nextBeforePid,
                int? pinnedPid,
              });
      final split = await _resolvePinned(
        fid,
        postPage.posts,
        postPage.pinnedPid,
      );
      _pinnedPosts = split.pinned;
      _posts = split.normal;
      _hasMorePosts = postPage.hasMore;
      _nextBeforePid = postPage.nextBeforePid;
      _isLoadingMore = false;
      _loadMoreFailed = false;

      // 自己在版块里的角色
      //不在成员表里 = 未加入
      //0 成员 / 50 管理员 / 100 版主
      var myRole = -1;
      if (results.length > 2 && results[2] is List<Map<String, int>>) {
        for (final membership in results[2] as List<Map<String, int>>) {
          if (membership['fid'].toString() != widget.forumId) continue;
          final role = membership['role'] ?? -1;
          if (role > myRole) myRole = role;
        }
        _isMember = myRole >= 0;
      }

      _members = const [];
      _identity = null;
      if (myRole >= 50 && uid != null && password != null) {
        unawaited(
          _fetchMembersSafe(uid, password, fid).then((members) {
            if (!mounted || widget.forumId != fid.toString()) return;
            setState(() {
              _members = members;
              _identity = members.cast<ForumMember?>().firstWhere(
                (m) => m?.accountUid == uid.toString(),
                orElse: () => null,
              );
            });
          }),
        );
      }

      await _prefetchProfiles([
        ...split.pinned,
        ...split.normal,
      ]).timeout(const Duration(milliseconds: 900), onTimeout: () {});
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      talker.error('ForumDetailScreen: _loadData failed', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'loadFailed';
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

  /// 后台刷新：保留当前内容，不整块换成 loading（见 [_loadData]）。
  void _refresh() => _loadData(showLoading: false);

  /// 整页一次性拉回
  Future<void> _prefetchProfiles(List<ForumPost> posts) async {
    final uids = <int>{};
    for (final post in posts) {
      final authorUid = int.tryParse(post.authorUid);
      if (authorUid != null) uids.add(authorUid);
      final commentUid = int.tryParse(post.lastCommentUid ?? '');
      if (commentUid != null) uids.add(commentUid);
    }
    if (uids.isEmpty) return;
    try {
      final profiles = await TfApiClient.instance.getUsersByUids(uids);
      profiles.forEach((uid, profile) {
        if (profile != null) _profileCache['$uid'] = profile;
      });
    } catch (e) {
      talker.error('ForumDetailScreen: prefetch profiles failed', e);
    }
  }

  Future<({List<ForumPost> pinned, List<ForumPost> normal})> _resolvePinned(
    int fid,
    List<ForumPost> posts,
    int? pinnedPid,
  ) async {
    final split = ForumPost.splitPinned(posts, pinnedPid);
    final missingPinnedPid = split.missingPinnedPid;
    if (missingPinnedPid == null) {
      return (pinned: split.pinned, normal: split.normal);
    }
    final fetched = await TfApiClient.instance.getPost(fid, missingPinnedPid);
    if (fetched == null) {
      return (pinned: split.pinned, normal: split.normal);
    }
    return (
      pinned: [fetched.copyWith(isPinned: true)],
      normal: split.normal.where((post) => post.id != fetched.id).toList(),
    );
  }

  /// 只刷新帖子列表
  Future<void> _refreshPostsOnly() async {
    final fid = int.tryParse(widget.forumId);
    if (fid == null) return;
    // 已经翻过页时保持深度
    final loaded = _posts.length + _pinnedPosts.length;
    final limit = loaded > _postPageSize
        ? (loaded > 100 ? 100 : loaded)
        : _postPageSize;
    final seq = ++_listSeq;
    try {
      final page = await TfApiClient.instance.getPostList(fid, limit: limit);
      if (!mounted || widget.forumId != fid.toString()) return;
      final split = await _resolvePinned(fid, page.posts, page.pinnedPid);
      // 期间又发起了更新的刷新（或整页加载），丢弃本次结果
      if (seq != _listSeq || !mounted || widget.forumId != fid.toString()) {
        return;
      }
      await _prefetchProfiles([...split.pinned, ...split.normal]);
      if (seq != _listSeq || !mounted) return;
      setState(() {
        _pinnedPosts = split.pinned;
        _posts = split.normal;
        _hasMorePosts = page.hasMore;
        _nextBeforePid = page.nextBeforePid;
        _isLoadingMore = false;
        _loadMoreFailed = false;
      });
    } catch (e) {
      talker.error('ForumDetailScreen: refresh posts failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isAside) {
      return Scaffold(body: _buildAsideLayout(context, l10n));
    }

    if (_isLoading) {
      return Scaffold(appBar: AppBar(), body: const LoadingIndicator());
    }

    if (_error != null || _forum == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorText(l10n)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => _loadData(), child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }
    final forum = _forum!;

    final isWide = WideScreenHelper.isExpanded(context);

    return Scaffold(
      body: Stack(
        children: [
          isWide
              ? _buildWideLayout(context, forum, l10n, colorScheme)
              : _buildNarrowLayout(context, forum, l10n, colorScheme),
          if (_showBackToBottom)
            Positioned(
              right: 12,
              bottom: 84,
              child: FloatingActionButton.small(
                heroTag: 'forum-detail-back-to-bottom',
                tooltip: l10n.chatBackToBottom,
                onPressed: _scrollToBottom,
                child: const Icon(Icons.arrow_downward),
              ),
            ),
        ],
      ),
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
                Flexible(
                  flex: 3,
                  child: RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (_pinnedPosts.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildPinnedPostsCard(context, l10n),
                          ),
                        SliverToBoxAdapter(
                          child: _buildPostFilterBar(context, l10n),
                        ),
                        _buildPostListSliver(context, l10n),
                      ],
                    ),
                  ),
                ),
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

  Widget _buildAsideLayout(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final forum = _forum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BackButton(onPressed: () => context.go(AppRoutes.forum)),
            if (forum != null) ...[
              ProfilePictureWidget(
                avatarUrl: forum.avatarUrl,
                radius: 14,
                fallbackIcon: Icons.forum,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                forum?.name ?? l10n.forumTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (forum != null && (_identity?.role ?? 0) >= 50)
              IconButton(
                onPressed: () => _showMemberList(context),
                icon: const Icon(Icons.people),
              ),
            if (AuthState.instance.isLoggedIn)
              IconButton(
                tooltip: l10n.forumComposePost,
                onPressed: () => _openComposePost(context),
                icon: const Icon(Icons.edit),
              ),
            if (forum != null)
              ForumActionMenu(
                forum: forum,
                identity: _identity,
                isMember: _isMember,
                onRefresh: _refresh,
                onEditForum: () => _handleEditForum(context),
                onPinPost: () => _handlePinPost(context),
              ),
          ],
        ),
        Expanded(child: _buildAsideBody(context, l10n)),
      ],
    );
  }

  Widget _buildAsideBody(BuildContext context, AppLocalizations l10n) {
    final forum = _forum;
    // 只有还没有数据才整块换
    if (forum == null) {
      if (_isLoading) return const Center(child: LoadingIndicator());
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorText(l10n)),
            const SizedBox(height: 8),
            // 错误页重试仍走带loading的整块刷新
            TextButton(onPressed: () => _loadData(), child: Text(l10n.retry)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildDescriptionCard(context, forum, l10n, expanded: false),
          ),
          if (!_isMember)
            SliverToBoxAdapter(child: _buildJoinCard(context, l10n)),
          if (_pinnedPosts.isNotEmpty)
            SliverToBoxAdapter(child: _buildPinnedPostsCard(context, l10n)),
          SliverToBoxAdapter(child: _buildPostFilterBar(context, l10n)),
          _buildPostListSliver(context, l10n),
        ],
      ),
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
              style: TextStyle(color: colorScheme.onSurface),
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
        ForumActionMenu(
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
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          leading: BackButton(onPressed: () => _leaveForum(context)),
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1,
            title: Text(
              forum.name,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (forum.avatarUrl != null)
                  OptimizedImage(
                    provider: NetworkImage(forum.avatarUrl!),
                    fit: BoxFit.cover,
                  )
                else
                  ColoredBox(color: colorScheme.surfaceContainerHighest),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.36),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if ((_identity?.role ?? 0) >= 50)
              IconButton(
                icon: const Icon(Icons.people),
                onPressed: () => _showMemberList(context),
              ),
            ForumActionMenu(
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
    AppLocalizations l10n, {
    bool expanded = true,
  }) {
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
          initiallyExpanded: expanded,
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
              TouchFishSnackbarService.instance.show(
                ok ? l10n.forumJoinSuccess : l10n.forumCreateFailed,
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
    if (_pinnedPosts.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final activePage = _pinnedPage.clamp(0, _pinnedPosts.length - 1);
    final carouselHeight = (MediaQuery.sizeOf(context).height * 0.42).clamp(
      300.0,
      420.0,
    );

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
              height: carouselHeight,
              child: PageView.builder(
                controller: _pinnedPageController,
                itemCount: _pinnedPosts.length,
                onPageChanged: (value) => setState(() => _pinnedPage = value),
                itemBuilder: (context, index) {
                  final post = _pinnedPosts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SingleChildScrollView(
                      child: ForumPostCard(
                        post: post,
                        onTap: () => _openPostDetail(context, post),
                        profileCache: _profileCache,
                        enableMarkdown: _enableMarkdown,
                        selected: post.id == widget.openPostId,
                        canDelete: _canManagePost(post),
                        onDelete: () => _confirmDeletePost(post),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_pinnedPosts.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: TFSpace.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pinnedPosts.length; i++)
                      AnimatedContainer(
                        duration: TFMotion.fast,
                        curve: TFMotion.standard,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == activePage ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == activePage
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: TFRadius.pillRadius,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 应用筛选后的帖
  List<ForumPost> get _visiblePosts {
    final myUid = AuthState.instance.uid?.toString();
    return _posts
        .where((post) {
          return passesTriState(
                _filterAttachment,
                post.attachments.isNotEmpty,
              ) &&
              passesTriState(
                _filterMine,
                myUid != null && post.authorUid == myUid,
              );
        })
        .toList(growable: false);
  }

  Widget _buildPostFilterBar(BuildContext context, AppLocalizations l10n) {
    // 一条帖子都没有时不占位置
    if (_posts.isEmpty) return const SizedBox.shrink();
    final enabled = _posts.length >= 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(TFSpace.lg, TFSpace.sm, TFSpace.lg, 0),
      child: Wrap(
        spacing: TFSpace.sm,
        runSpacing: TFSpace.xs,
        children: [
          TriStateFilterChip(
            label: l10n.forumFilterWithAttachment,
            value: _filterAttachment,
            enabled: enabled,
            onChanged: (value) => setState(() => _filterAttachment = value),
          ),
          TriStateFilterChip(
            label: l10n.forumFilterMine,
            value: _filterMine,
            enabled: enabled,
            onChanged: (value) => setState(() => _filterMine = value),
          ),
        ],
      ),
    );
  }

  Widget _buildPostListSliver(BuildContext context, AppLocalizations l10n) {
    final filteredPosts = _visiblePosts;
    if (_posts.isNotEmpty && filteredPosts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TFSpace.xxl),
          child: EmptyState(
            compact: true,
            icon: Icons.filter_alt_off_outlined,
            title: l10n.forumFilterNoMatch,
          ),
        ),
      );
    }
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

    final posts = _visiblePosts;
    final itemCount = posts.length + (_hasMorePosts ? 1 : 0);
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index >= posts.length) {
          // 分页加载指示失败时换成可点的重试：失败不会产生新的滚动事件
          if (_loadMoreFailed) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: TextButton.icon(
                  onPressed: _isLoadingMore ? null : _loadMorePosts,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(AppLocalizations.of(context)!.retry),
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ForumPostCard(
            post: posts[index],
            onTap: () => _openPostDetail(context, posts[index]),
            profileCache: _profileCache,
            enableMarkdown: _enableMarkdown,
            selected: posts[index].id == widget.openPostId,
            canDelete: _canManagePost(posts[index]),
            onDelete: () => _confirmDeletePost(posts[index]),
          ),
        );
      }, childCount: itemCount),
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

  bool _canManagePost(ForumPost post) {
    final uid = AuthState.instance.uid?.toString();
    if (uid == null) return false;
    return uid == post.authorUid ||
        uid == _forum?.createdByUid ||
        (_identity?.role ?? 0) >= 50 ||
        AuthState.instance.currentUser?.hasAdminAccess == true;
  }

  Future<void> _confirmDeletePost(ForumPost post) async {
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
    final fid = int.tryParse(post.forumId);
    final pid = int.tryParse(post.id);
    if (uid == null || password == null || fid == null || pid == null) return;
    final success = await TfApiClient.instance.removePost(
      uid,
      password,
      fid,
      pid,
    );
    if (!mounted) return;
    TouchFishSnackbarService.instance.show(
      success ? l10n.forumPostDeleteSuccess : l10n.forumPostDeleteFailed,
    );
    if (success) _refresh();
  }

  void _openPostDetail(BuildContext context, ForumPost post) async {
    final path = '/forum/${widget.forumId}/post/${post.id}';
    // 分屏
    if (WideScreenHelper.forumTwoPane(context)) {
      context.go(path);
      return;
    }
    await context.push(path);
    if (mounted) _refresh();
  }

  void _openComposePost(BuildContext context) async {
    await ForumPostComposeSheet.show(context, forumId: widget.forumId);
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
    final nameText = nameController.text.trim();
    final introText = introController.text.trim();
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
      forumName: nameText,
      introduction: introText,
    );
    if (!mounted) return;
    TouchFishSnackbarService.instance.show(
      ok ? l10n.forumEdit : l10n.forumCreateFailed,
    );
    if (ok) _refresh();
  }

  void _handlePinPost(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final allPosts = [..._pinnedPosts, ..._posts];
    if (allPosts.isEmpty) {
      TouchFishSnackbarService.instance.show(l10n.forumNoPosts);
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
    TouchFishSnackbarService.instance.show(
      ok ? l10n.forumPinPost : l10n.forumCreateFailed,
    );
    if (ok) _refresh();
  }
}
