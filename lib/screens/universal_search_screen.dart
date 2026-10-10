import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/api_error.dart';
import '../models/local_message_search_result.dart';
import '../models/search_result.dart';
import '../services/api/api_error_localization.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/chat_data_service.dart';
import '../services/feature_flags.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';
import '../widgets/optimized_image.dart';

/// 统一搜索页：用户 / 群组 / 本地消息三个 tab，共用一个关键词输入框。
///
/// 用户与群组走服务端 secret 接口（/user/search、/group/search）；
/// 本地消息走 [ChatDataService.searchAllRoomsMessages]。
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
  String? _baseUrl;

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
      _baseUrl = await TfApiClient.instance.getBaseUrl();
      final config = await TfApiClient.instance.fetchServerInfo();
      if (config != null && mounted) {
        setState(() => _minLength = config.minSearchLength > 0 ? config.minSearchLength : 1);
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
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search(raw));
    });
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _query = '';
          _users = const [];
          _groups = const [];
          _local = const [];
          _groupsHasMore = false;
          _searching = false;
        });
      }
      return;
    }
    if (query.length < _minLength) {
      if (mounted) {
        setState(() {
          _query = query;
          _users = const [];
          _groups = const [];
          _local = const [];
          _groupsHasMore = false;
          _searching = false;
        });
      }
      return;
    }

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;

    if (mounted) setState(() => _searching = true);

    final localFuture = ChatDataService.instance.searchAllRoomsMessages(query);
    final usersFuture = (uid == null || password == null)
        ? Future<List<UserSearchEntry>>.value(const [])
        : TfApiClient.instance.searchUsers(uid, password, query);
    final groupsFuture = (!FeatureFlags.instance.groupChat ||
            uid == null ||
            password == null)
        ? Future<GroupSearchPage>.value(
            const GroupSearchPage(groups: [], hasMore: false),
          )
        : TfApiClient.instance.searchGroups(uid, password, query);

    // 服务端搜索失败（限流／关键词过短／网络）时仍保留本地消息结果，仅提示错误。
    ApiError? serverError;
    var serverFailed = false;
    var users = const <UserSearchEntry>[];
    var groupPage = const GroupSearchPage(groups: [], hasMore: false);
    try {
      final serverResults = await Future.wait<Object>([
        usersFuture,
        groupsFuture,
      ]);
      users = serverResults[0] as List<UserSearchEntry>;
      groupPage = serverResults[1] as GroupSearchPage;
    } on ApiErrorException catch (e) {
      serverError = e.error;
    } catch (e) {
      talker.error('UniversalSearch: server search failed', e);
      serverFailed = true;
    }

    final local = await localFuture;
    if (!mounted) return;

    // 结果过期（用户已改了关键词）时丢弃
    if (_controller.text.trim() != query) return;

    setState(() {
      _query = query;
      _users = users;
      _groups = groupPage.groups;
      _groupsHasMore = groupPage.hasMore;
      _local = local;
      _searching = false;
    });

    if (serverError != null) {
      TouchFishSnackbarService.instance.show(
        localizeApiError(context, serverError),
        type: SnackbarType.error,
      );
    } else if (serverFailed) {
      TouchFishSnackbarService.instance.show(
        AppLocalizations.of(context)!.commonFailedOperation,
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _loadMoreGroups() async {
    if (_loadingMoreGroups || !_groupsHasMore) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    setState(() => _loadingMoreGroups = true);
    try {
      final page = await TfApiClient.instance.searchGroups(
        uid,
        password,
        _query,
        offset: _groups.length,
      );
      if (!mounted) return;
      setState(() {
        _groups = [..._groups, ...page.groups];
        _groupsHasMore = page.hasMore;
        _loadingMoreGroups = false;
      });
    } on ApiErrorException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMoreGroups = false);
      TouchFishSnackbarService.instance.show(
        localizeApiError(context, e.error),
        type: SnackbarType.error,
      );
    } catch (e) {
      talker.error('UniversalSearch: load more groups failed', e);
      if (!mounted) return;
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
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
    if (_users.isEmpty) return _emptyIfSettled(l10n, colorScheme);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: _avatarProvider('user', user.uid),
            onBackgroundImageError: (_, _) {},
            child: _baseUrl == null
                ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
                : null,
          ),
          title: Text(
            user.username,
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
    );
  }

  Widget _buildGroupsTab(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_groups.isEmpty) return _emptyIfSettled(l10n, colorScheme);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          unawaited(_loadMoreGroups());
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _groups.length + (_groupsHasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
        itemBuilder: (context, index) {
          if (index >= _groups.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
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
              onBackgroundImageError: (_, _) {},
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
    );
  }

  String _groupJoinLabel(AppLocalizations l10n, GroupSearchEntry group) {
    if (group.allowDirectJoin) return l10n.searchGroupJoinDirect;
    if (group.requireReview) return l10n.searchGroupNeedReview;
    return l10n.searchGroupInviteOnly;
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
    if (_local.isEmpty) return _emptyIfSettled(l10n, colorScheme);
    return ListView.separated(
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          onTap: () => context.push('/chat/${result.roomId}'),
        );
      },
    );
  }

  Widget _emptyIfSettled(AppLocalizations l10n, ColorScheme colorScheme) {
    final String message;
    IconData icon;
    if (_query.isEmpty) {
      message = l10n.searchStartHint;
      icon = Icons.search;
    } else if (_query.length < _minLength) {
      message = l10n.searchMinLengthHint(_minLength);
      icon = Icons.keyboard;
    } else {
      message = l10n.searchNoResults;
      icon = Icons.search_off;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
