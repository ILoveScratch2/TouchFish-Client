import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../routes/app_routes.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../widgets/account/profile_picture.dart';
import '../utils/talker.dart';
import '../services/notification_service.dart';
import '../widgets/forum_notification_sheet.dart';
import '../widgets/layout/responsive_sidebar.dart';
import '../services/draft_service.dart';
import '../services/snackbar_service.dart';
import '../widgets/forum_quick_strip.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/skeleton.dart';

/// 论坛区
/// 我是区！我是区！
/// 数学没救了！
class ForumScreen extends StatefulWidget {
  final bool isAside;

  const ForumScreen({super.key, this.isAside = false});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Forum>? _allForums;
  Set<String> _joinedIds = {};
  bool _isLoading = true;
  String? _error;
  final _notificationService = NotificationService.instance;

  GoRouter? _router;
  String? _lastLocation;
  bool _routerAttached = false;

  List<Forum> get _joinedForums =>
      _allForums?.where((f) => _joinedIds.contains(f.id)).toList() ?? [];
  List<Forum> get _exploreForums =>
      _allForums?.where((f) => !_joinedIds.contains(f.id)).toList() ?? [];

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
    _loadForums();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routerAttached) {
      _routerAttached = true;
      try {
        _router = GoRouter.of(context);
        _router!.routerDelegate.addListener(_onRouteChanged);
      } catch (e) {
        talker.debug('ForumScreen: attach router listener failed', e);
      }
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  /// 宽屏下详情页返回列表（location 回到 `/forum`）时刷新，补齐「加入论坛」
  /// 后 Joined/Explore 分栏的即时同步。
  void _onRouteChanged() {
    final router = _router;
    if (router == null) return;
    final loc = router.routerDelegate.currentConfiguration.uri.path;
    final returnedToList =
        loc == AppRoutes.forum && _lastLocation != AppRoutes.forum;
    _lastLocation = loc;
    if (returnedToList && mounted) _loadForums(showLoading: false);
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  void _showNotifications() {
    _notificationService.markForumRead();
    ResponsiveSidebar.show(
      context: context,
      builder: (ctx, close) => const ForumNotificationSheet(),
    );
  }

  /// 拉取论坛列表。
  ///
  /// [showLoading] 为假时保留当前列表（从详情返回、下拉刷新、建完论坛这些
  /// 刷新路径）：否则整块内容会被换成转圈，闪一下白屏还丢滚动位置。
  Future<void> _loadForums({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _isLoading = true;
      _error = null;
    });
    try {
      final uid = AuthState.instance.uid;
      final password = AuthState.instance.password;
      final results = await Future.wait([
        TfApiClient.instance.getForumList(),
        if (uid != null && password != null)
          TfApiClient.instance.getMyMemberships(uid, password),
      ]);
      if (mounted) {
        final memberships = results.length > 1
            ? results[1] as List<Map<String, int>>
            : <Map<String, int>>[];
        setState(() {
          _allForums = results[0] as List<Forum>;
          _joinedIds = memberships.map((m) => m['fid'].toString()).toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      talker.error('ForumScreen: getForumList failed', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// 打开论坛详情。
  ///
  /// 宽屏（[isAside]）用 `go` 切换右侧面板，返回列表时由路由监听刷新；
  /// 窄屏用 `push` 并 await，pop 后立即刷新。
  Future<void> _openForum(Forum forum) async {
    if (widget.isAside) {
      context.go('/forum/${forum.id}');
      return;
    }
    await context.push('/forum/${forum.id}');
    if (mounted) _loadForums(showLoading: false);
  }

  Future<void> _showCreateForumDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final nameController = TextEditingController();
    final introController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final draft = await DraftService.instance.loadDraft('forum_create', 'new');
    nameController.text = draft?['name'] as String? ?? '';
    introController.text = draft?['introduction'] as String? ?? '';
    if (!context.mounted) {
      nameController.dispose();
      introController.dispose();
      return;
    }
    var isSubmitting = false;
    final requestId =
        '${AuthState.instance.uid}-${DateTime.now().microsecondsSinceEpoch}';
    void saveDraft() {
      DraftService.instance.saveDraft('forum_create', 'new', {
        'name': nameController.text,
        'introduction': introController.text,
      });
    }

    nameController.addListener(saveDraft);
    introController.addListener(saveDraft);
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.forumCreateTitle),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.forumPostTitle,
                    hintText: l10n.forumCreateTitleHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.forumPostTitleRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: introController,
                  decoration: InputDecoration(
                    labelText: l10n.forumPostDescription,
                    hintText: l10n.forumCreateDescriptionHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final uid = AuthState.instance.uid;
                      final password = AuthState.instance.password;
                      if (uid == null || password == null) {
                        Navigator.pop(dialogContext, false);
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final name = nameController.text.trim();
                      final intro = introController.text.trim();
                      final success = await TfApiClient.instance.createForum(
                        uid,
                        password,
                        name,
                        intro.isNotEmpty ? intro : '',
                        requestId: requestId,
                      );
                      if (!dialogContext.mounted) return;
                      if (success) {
                        await DraftService.instance.clearDraft(
                          'forum_create',
                          'new',
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext, true);
                        if (!context.mounted) return;
                        TouchFishSnackbarService.instance.show(l10n.forumCreateSuccess);
                        _loadForums(showLoading: false);
                      } else {
                        setDialogState(() => isSubmitting = false);
                        TouchFishSnackbarService.instance.show(l10n.forumCreateFailed);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.forumPublish),
            ),
          ],
        ),
      ),
    );
    nameController.removeListener(saveDraft);
    introController.removeListener(saveDraft);
    nameController.dispose();
    introController.dispose();
  }

  Widget _notificationButton(AppLocalizations l10n) {
    return IconButton(
      tooltip: l10n.notificationTabNotifications,
      onPressed: _showNotifications,
      icon: _notificationService.forumUnreadCount > 0
          ? Badge(
              label: Text('${_notificationService.forumUnreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            )
          : const Icon(Icons.notifications_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return widget.isAside ? _buildAside(context, l10n) : _buildFullScreen(context, l10n);
  }

  Widget _buildFullScreen(BuildContext context, AppLocalizations l10n) {
    final isLoggedIn = AuthState.instance.isLoggedIn;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.forumTitle),
          actions: [
            IconButton(
              tooltip: l10n.forumSearchTitle,
              onPressed: () => context.push('/forum/search'),
              icon: const Icon(Icons.search),
            ),
            _notificationButton(l10n),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.forumTabJoined),
              Tab(text: l10n.forumTabExplore),
            ],
          ),
        ),
        floatingActionButton: isLoggedIn
            ? FloatingActionButton(
                onPressed: () => _showCreateForumDialog(context, l10n),
                child: const Icon(Icons.add),
              )
            : null,
        body: _buildBody(l10n),
      ),
    );
  }

  /// 宽屏两栏左侧的常驻列表：紧凑头部 + TabBar + 列表，不含大 AppBar / FAB。
  Widget _buildAside(BuildContext context, AppLocalizations l10n) {
    final isLoggedIn = AuthState.instance.isLoggedIn;
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.forumTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLoggedIn)
                IconButton(
                  tooltip: l10n.forumCreateTitle,
                  onPressed: () => _showCreateForumDialog(context, l10n),
                  icon: const Icon(Icons.add),
                ),
              IconButton(
                tooltip: l10n.forumSearchTitle,
                onPressed: () => context.push('/forum/search'),
                icon: const Icon(Icons.search),
              ),
              _notificationButton(l10n),
            ],
          ),
          TabBar(
            tabs: [
              Tab(text: l10n.forumTabJoined),
              Tab(text: l10n.forumTabExplore),
            ],
          ),
          // 版块横向速览
          if (!_isLoading && _error == null && _quickStripForums.length >= 3)
            ForumQuickStrip(
              forums: _quickStripForums,
              onOpen: _openForum,
            ),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  /// 速览条使用的版块
  List<Forum> get _quickStripForums =>
      _joinedForums.isNotEmpty ? _joinedForums : _exploreForums;

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const ListSkeleton();
    }
    if (_error != null) {
      return ErrorState(
        title: l10n.forumLoadFailed,
        onRetry: () => _loadForums(),
        retryLabel: l10n.retry,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadForums(showLoading: false),
      child: TabBarView(
        children: [
          _ForumListView(
            forums: _joinedForums,
            emptyMessage: l10n.forumNoJoined,
            onOpen: _openForum,
          ),
          _ForumListView(forums: _exploreForums, onOpen: _openForum),
        ],
      ),
    );
  }
}

class _ForumListView extends StatelessWidget {
  final List<Forum> forums;
  final String? emptyMessage;
  final ValueChanged<Forum> onOpen;

  const _ForumListView({
    required this.forums,
    this.emptyMessage,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (forums.isEmpty && emptyMessage != null) {
      return EmptyState(icon: Icons.forum_outlined, title: emptyMessage!);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: forums.length,
      itemBuilder: (context, index) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _ForumListTile(forum: forums[index], onOpen: onOpen),
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 4),
    );
  }
}

class _ForumListTile extends StatelessWidget {
  final Forum forum;
  final ValueChanged<Forum> onOpen;

  const _ForumListTile({required this.forum, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpen(forum),
        child: ListTile(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          leading: ProfilePictureWidget(
            avatarUrl: forum.avatarUrl,
            radius: 20,
            fallbackIcon: Icons.forum,
          ),
          title: Text(forum.name),
          subtitle: Text(
            forum.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
