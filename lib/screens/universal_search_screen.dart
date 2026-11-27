import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/api_error.dart';
import '../models/group_join_policy.dart';
import '../models/local_message_search_result.dart';
import '../models/search_result.dart';
import '../routes/app_routes.dart';
import '../services/api/api_error_localization.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/chat_data_service.dart';
import '../services/feature_flags.dart';
import '../services/snackbar_service.dart';
import '../utils/search_query.dart';
import '../utils/talker.dart';
import '../widgets/optimized_image.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/tf_search_field.dart';
import '../widgets/ui/load_more_footer.dart';
import '../widgets/ui/refreshable.dart';

/// 用户搜索的结果上限
const int _kUserSearchLimit = 20;

/// 统一搜索页
class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  int _minLength = 2;
  String _query = '';
  bool _searching = false;

  /// 本地消息库扫描是否仍在进行
  bool _localSearching = false;
  String? _baseUrl;

  /// 请求序号
  int _requestToken = 0;
  String? _userErrorText;
  String? _groupErrorText;
  String? _localErrorText;

  List<UserSearchEntry> _users = const [];
  List<GroupSearchEntry> _groups = const [];
  bool _groupsHasMore = false;
  bool _loadingMoreGroups = false;
  List<LocalMessageSearchResult> _local = const [];

  @override
  void initState() {
    super.initState();
    FeatureFlags.instance.addListener(_onFlagsChanged);
    unawaited(_initConfig());
  }

  void _onFlagsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initConfig() async {
    try {
      final baseUrl = await TfApiClient.instance.getBaseUrl();
      if (!mounted) return;
      setState(() => _baseUrl = baseUrl);
      final config = await TfApiClient.instance.fetchServerInfo();
      if (config == null || !mounted) return;
      final query = TfSearchQuery.parse(_controller.text);
      final wasTooShort = _isTooShort(query);
      setState(() {
        _minLength = config.minSearchLength > 0 ? config.minSearchLength : 1;
      });
      if (query.raw.isNotEmpty && wasTooShort != _isTooShort(query)) {
        unawaited(_refresh());
      }
    } catch (e) {
      talker.debug('UniversalSearch: init failed', e);
    }
  }

  @override
  void dispose() {
    FeatureFlags.instance.removeListener(_onFlagsChanged);
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    final parsed = TfSearchQuery.parse(raw);
    final canSearch = parsed.raw.isNotEmpty && !_isTooShort(parsed);
    ++_requestToken;
    setState(() {
      _clearResults(parsed.raw);
      _searching = canSearch;
      _localSearching = canSearch;
      _loadingMoreGroups = false;
      _groupsHasMore = false;
      _userErrorText = null;
      _groupErrorText = null;
      _localErrorText = null;
    });
    if (!canSearch) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search(parsed));
    });
  }

  bool _isTooShort(TfSearchQuery query) =>
      !query.isIdentifier && query.raw.runes.length < _minLength;

  void _clearResults(String query) {
    _query = query;
    _users = const [];
    _groups = const [];
    _local = const [];
  }

  Future<void> _search(TfSearchQuery parsed) async {
    final query = parsed.raw;
    final canSearch = query.isNotEmpty && !_isTooShort(parsed);
    final token = ++_requestToken;
    setState(() {
      if (!canSearch || query != _query) _clearResults(query);
      _searching = canSearch;
      _localSearching = canSearch;
      _loadingMoreGroups = false;
      _groupsHasMore = false;
      _userErrorText = null;
      _groupErrorText = null;
      _localErrorText = null;
    });
    if (!canSearch) return;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final localSearch = _searchLocal(query, token);
    final userSearchAllowed =
        parsed.allowsUserSearch &&
        (parsed.uid != null || query.runes.length >= _minLength);
    final usersFuture = (uid == null || password == null || !userSearchAllowed)
        ? Future<List<UserSearchEntry>>.value(const [])
        : TfApiClient.instance.searchUsers(
            uid,
            password,
            query,
            limit: _kUserSearchLimit,
          );
    final groupsFuture =
        (!FeatureFlags.instance.groupChat ||
            uid == null ||
            password == null ||
            !parsed.allowsGroupSearch)
        ? Future<GroupSearchPage>.value(
            const GroupSearchPage(groups: [], hasMore: false),
          )
        : TfApiClient.instance.searchGroups(uid, password, query);

    final ((users, userError), (groupPage, groupError)) = await (
      _readRemoteResult(usersFuture),
      _readRemoteResult(groupsFuture),
    ).wait;
    if (!mounted || token != _requestToken) return;

    setState(() {
      _users = users ?? const [];
      _groups = groupPage?.groups ?? const [];
      _groupsHasMore = groupPage?.hasMore == true && _groups.isNotEmpty;
      _userErrorText = userError;
      _groupErrorText = groupError;
      _searching = false;
    });

    await localSearch;
  }

  Future<(T?, String?)> _readRemoteResult<T>(Future<T> request) async {
    try {
      return (await request, null);
    } on ApiErrorException catch (e) {
      return (null, mounted ? localizeApiError(context, e.error) : null);
    } catch (e) {
      talker.error('UniversalSearch: server search failed', e);
      return (
        null,
        mounted ? AppLocalizations.of(context)!.commonLoadFailed : null,
      );
    }
  }

  Future<void> _searchLocal(String query, int token) async {
    try {
      final results = await ChatDataService.instance.searchAllRoomsMessages(
        query,
      );
      if (!mounted || token != _requestToken) return;
      setState(() => _local = results);
    } catch (e) {
      talker.error('UniversalSearch: local search failed', e);
      if (mounted && token == _requestToken) {
        setState(() {
          _local = const [];
          _localErrorText = AppLocalizations.of(context)!.commonLoadFailed;
        });
      }
    } finally {
      if (mounted && token == _requestToken) {
        setState(() => _localSearching = false);
      }
    }
  }

  Future<void> _refresh() {
    _debounce?.cancel();
    return _search(TfSearchQuery.parse(_controller.text));
  }

  Future<void> _loadMoreGroups() async {
    if (_searching || _loadingMoreGroups || !_groupsHasMore) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final token = _requestToken;
    setState(() => _loadingMoreGroups = true);
    try {
      final page = await TfApiClient.instance.searchGroups(
        uid,
        password,
        _query,
        offset: _groups.length,
      );
      if (!mounted || token != _requestToken) return;
      setState(() {
        _groups = [..._groups, ...page.groups];
        _groupsHasMore = page.hasMore && page.groups.isNotEmpty;
        _loadingMoreGroups = false;
      });
    } on ApiErrorException catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() => _loadingMoreGroups = false);
      TouchFishSnackbarService.instance.show(
        localizeApiError(context, e.error),
        type: SnackbarType.error,
      );
    } catch (e) {
      talker.error('UniversalSearch: load more groups failed', e);
      if (!mounted || token != _requestToken) return;
      setState(() => _loadingMoreGroups = false);
      TouchFishSnackbarService.instance.show(
        AppLocalizations.of(context)!.commonFailedOperation,
        type: SnackbarType.error,
      );
    }
  }

  ImageProvider? _avatarProvider(String kind, int id) {
    if (_baseUrl == null) return null;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return resizedImageProvider(
      NetworkImage('$_baseUrl/avatar/get_avatar/$kind/$id'),
      dpr,
      width: 48,
      height: 48,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final showGroups = FeatureFlags.instance.groupChat;

    return DefaultTabController(
      length: showGroups ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.searchTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.searchTabUsers),
              if (showGroups) Tab(text: l10n.searchTabGroups),
              Tab(text: l10n.searchTabMessages),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TFSearchField(
                controller: _controller,
                hintText: l10n.searchHint,
                autofocus: true,
                debounce: Duration.zero,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => unawaited(_refresh()),
                onClear: () => _onQueryChanged(''),
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUsersTab(l10n, colorScheme),
                  if (showGroups) _buildGroupsTab(l10n, colorScheme),
                  _buildLocalTab(l10n, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_users.isEmpty) {
      return PullToRefresh.content(
        onRefresh: _refresh,
        child: _emptyIfSettled(l10n, errorText: _userErrorText),
      );
    }
    final truncated = _users.length >= _kUserSearchLimit;
    return PullToRefresh.list(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _users.length + (truncated ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                l10n.searchUsersTruncated(_users.length),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final user = _users[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: _avatarProvider('user', user.uid),
              onBackgroundImageError: _baseUrl != null ? (_, _) {} : null,
              child: _baseUrl == null
                  ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
                  : null,
            ),
            title: Text(
              user.uid == AuthState.instance.uid
                  ? '${user.username} (${l10n.commonMe})'
                  : user.username,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: user.sign.isEmpty
                ? null
                : Text(
                    user.sign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
            onTap: () => context.push('/user/${user.uid}'),
          );
        },
      ),
    );
  }

  Widget _buildGroupsTab(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_groups.isEmpty) {
      return PullToRefresh.content(
        onRefresh: _refresh,
        child: _emptyIfSettled(l10n, errorText: _groupErrorText),
      );
    }
    return PullToRefresh.list(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            unawaited(_loadMoreGroups());
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _groups.length + (_groupsHasMore ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
          itemBuilder: (context, index) {
            if (index >= _groups.length) {
              return LoadMoreFooter(
                loading: _loadingMoreGroups,
                hasMore: _groupsHasMore,
              );
            }
            final group = _groups[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: _avatarProvider('group', group.gid),
                onBackgroundImageError: _baseUrl != null ? (_, _) {} : null,
                child: _baseUrl == null
                    ? Icon(Icons.groups, color: colorScheme.onPrimaryContainer)
                    : null,
              ),
              title: Text(
                group.groupname,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _badge(colorScheme, _groupJoinLabel(l10n, group)),
                      const SizedBox(width: 8),
                      Text(
                        l10n.searchGroupMemberCount(group.memberCount),
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (group.introduction.isNotEmpty)
                    Text(
                      group.introduction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
              onTap: () => context.push(
                '/group/${group.gid}',
                extra: <String, dynamic>{
                  'initialData': {'groupname': group.groupname},
                  'groupName': group.groupname,
                },
              ),
            );
          },
        ),
      ),
    );
  }

  String _groupJoinLabel(AppLocalizations l10n, GroupSearchEntry group) {
    switch (group.joinPolicy) {
      case TfJoinPolicy.open:
        return l10n.searchGroupJoinDirect;
      case TfJoinPolicy.approval:
        return l10n.searchGroupNeedReview;
      case TfJoinPolicy.invite:
      case TfJoinPolicy.adminInvite:
      default:
        return l10n.searchGroupInviteOnly;
    }
  }

  Widget _badge(ColorScheme colorScheme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: colorScheme.onSecondaryContainer),
      ),
    );
  }

  Widget _buildLocalTab(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_local.isEmpty) {
      return PullToRefresh.content(
        onRefresh: _refresh,
        child: _emptyIfSettled(
          l10n,
          serverBacked: false,
          errorText: _localErrorText,
        ),
      );
    }
    return PullToRefresh.list(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _local.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
        itemBuilder: (context, index) {
          final result = _local[index];
          final roomName = ChatDataService.instance.displayNameForRoom(
            result.roomId,
            result.roomId,
          );
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.chat, color: colorScheme.onPrimaryContainer),
            ),
            title: Text(
              roomName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              result.message.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => context.push(
              AppRoutes.chatMessagePath(result.roomId, result.message),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyIfSettled(
    AppLocalizations l10n, {
    bool serverBacked = true,
    String? errorText,
  }) {
    if (errorText != null && _query.isNotEmpty) {
      return ErrorState(
        title: l10n.commonLoadFailed,
        description: errorText == l10n.commonLoadFailed ? null : errorText,
        onRetry: _refresh,
        retryLabel: l10n.retry,
      );
    }
    final settled = serverBacked ? !_searching : !_localSearching;
    if (!settled) {
      return EmptyState(
        icon: Icons.hourglass_empty,
        title: l10n.searchInProgress,
      );
    }
    final IconData icon;
    final String message;
    if (_query.isEmpty) {
      message = l10n.searchStartHint;
      icon = Icons.search;
    } else if (_isTooShort(TfSearchQuery.parse(_query))) {
      message = l10n.searchMinLengthHint(_minLength);
      icon = Icons.keyboard;
    } else {
      message = l10n.searchNoResults;
      icon = Icons.search_off;
    }
    return EmptyState(icon: icon, title: message);
  }
}
