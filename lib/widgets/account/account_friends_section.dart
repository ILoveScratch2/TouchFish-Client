import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../models/chat_model.dart';
import '../../models/user_profile.dart';
import '../../services/api/tf_api_client.dart';
import '../../services/auth_state.dart';
import '../../services/chat_data_service.dart';
import '../../services/presence_service.dart';
import '../../services/snackbar_service.dart';
import '../../utils/talker.dart';
import '../account/online_avatar_badge.dart';
import '../account/profile_picture.dart';
import '../sheet_scaffold.dart';
import '../ui/empty_state.dart';
import '../ui/loading_indicator.dart';
import '../ui/refreshable.dart';

class AccountFriendsSection extends StatefulWidget {
  const AccountFriendsSection({super.key});

  @override
  State<AccountFriendsSection> createState() => _AccountFriendsSectionState();
}

class _AccountFriendsSectionState extends State<AccountFriendsSection> {
  List<int>? _blockedUids;
  final Map<int, UserProfile?> _blockedProfiles = {};
  bool _loadingBlocked = false;

  /// 拉黑列表这次没拉到
  bool _blockedFailed = false;
  bool _friendsRequested = false;

  @override
  void initState() {
    super.initState();
    ChatDataService.instance.addListener(_onDataChanged);
    PresenceService.instance.addListener(_onDataChanged);
    // 两个加载都必须等本帧结束再发起：它们在第一个 await 之前就会
    // setState / notifyListeners，在 initState 的构建期同步触发会让**其它**
    // 已挂载的监听者（如 GroupProfileScreen 的正向 setState）撞上 Flutter 的
    // "setState() or markNeedsBuild() called during build" 断言。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureFriends();
      _loadBlocked();
    });
  }

  @override
  void dispose() {
    ChatDataService.instance.removeListener(_onDataChanged);
    PresenceService.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _ensureFriends() {
    if (_friendsRequested) return;
    _friendsRequested = true;
    if (ChatDataService.instance.contacts.isNotEmpty) return;
    // 账户页可能在会话列表拉取完成前就被打开：这里补一次。
    // （首帧延迟见 initState。）
    ChatDataService.instance.loadContactsAndRooms();
  }

  Future<void> _loadBlocked() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || !mounted) return;
    setState(() {
      _loadingBlocked = true;
      _blockedFailed = false;
    });
    try {
      final uids = await TfApiClient.instance.getBlockedUsers(uid, password);
      if (!mounted) return;
      // 旧服务器没有这个端点（null）：当作空列表，不显示错误。
      final blocked = uids ?? const <int>[];
      // 名字并发取回：串行等 N 次请求会让头像条长时间只有 uid 没有名字，
      // 中途卸载还会留下一半填充的 _blockedProfiles。
      final missing = blocked
          .where((id) => !_blockedProfiles.containsKey(id))
          .toList();
      final profiles = await Future.wait(
        missing.map((id) async {
          try {
            return await TfApiClient.instance.getUserByUid(id);
          } catch (_) {
            // 取不到名字不影响解除拉黑，UI 用 U<uid> 兜底。
            return null;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < missing.length; i++) {
          _blockedProfiles[missing[i]] = profiles[i];
        }
        _blockedUids = blocked;
        _loadingBlocked = false;
      });
    } catch (e) {
      talker.error('AccountFriendsSection._loadBlocked failed', e);
      if (mounted) {
        // 保留上一次的列表（如果有），只标记这次失败，不伪造空列表。
        setState(() {
          _blockedFailed = true;
          _loadingBlocked = false;
        });
      }
    }
  }

  Future<bool> _unblock(int uid) async {
    final myUid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (myUid == null || password == null) return false;
    final ok = await TfApiClient.instance.unblockUser(myUid, password, uid);
    if (ok && mounted) {
      setState(() {
        final next = List<int>.from(_blockedUids ?? const []);
        next.remove(uid);
        _blockedUids = next;
      });
    }
    return ok;
  }

  String _nameFor(int uid, UserProfile? profile) =>
      (profile?.username.isNotEmpty ?? false) ? profile!.username : 'U$uid';

  int _uidOf(Contact contact) =>
      int.tryParse(contact.id.replaceFirst('U', '')) ?? -1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final friends = ChatDataService.instance.contacts;
    final presence = PresenceService.instance;
    final onlineFriends = friends
        .where((c) => presence.isOnline(_uidOf(c)))
        .toList();
    // 在线优先，但**不丢人**：卡片标题是「好友」，原先只显示在线的人会让离线
    // 好友从头像条里整批消失，也和展开后的 [_FriendsSheet] 不一致。
    final displayFriends = [
      ...onlineFriends,
      ...friends.where((c) => !presence.isOnline(_uidOf(c))),
    ];
    final blocked = _blockedUids ?? const <int>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          _OverviewCard(
            icon: Symbols.group,
            title: l10n.accountFriends,
            trailingText: friends.isEmpty
                ? null
                : l10n.accountFriendsOnlineCount(onlineFriends.length),
            emptyText: l10n.accountFriendsEmpty,
            onTap: () => _showFriendsSheet(context, friends),
            items: [
              for (final contact in displayFriends)
                _AvatarTile(
                  uid: _uidOf(contact),
                  avatarUrl: contact.avatar,
                  name: contact.name,
                  // `/user/:userId` 的参数是裸 uid（页面里 int.tryParse 解析），
                  // 不能把 "U1" 这种房间 id 直接塞进去。
                  onTap: () => context.push('/user/${_uidOf(contact)}'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _OverviewCard(
            icon: Symbols.block,
            title: l10n.accountBlocked,
            trailingText: blocked.isEmpty
                ? null
                : l10n.accountBlockedCount(blocked.length),
            emptyText: _blockedFailed
                ? l10n.commonFailedOperation
                : l10n.accountBlockedEmpty,
            loading: _loadingBlocked,
            onTap: () => _showBlockedSheet(context, blocked),
            items: [
              for (final uid in blocked)
                _AvatarTile(
                  uid: uid,
                  avatarUrl: _blockedProfiles[uid]?.avatar,
                  name: _nameFor(uid, _blockedProfiles[uid]),
                  showPresence: false,
                  onTap: () => context.push('/user/$uid'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFriendsSheet(BuildContext context, List<Contact> friends) {
    final presence = PresenceService.instance;
    final online = friends.where((c) => presence.isOnline(_uidOf(c)));
    final offline = friends.where((c) => !presence.isOnline(_uidOf(c)));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FriendsSheet(friends: [...online, ...offline]),
    );
  }

  void _showBlockedSheet(BuildContext context, List<int> blocked) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BlockedSheet(
        uids: blocked,
        profiles: Map<int, UserProfile?>.from(_blockedProfiles),
        nameFor: _nameFor,
        onUnblock: _unblock,
      ),
    );
  }
}

/// 卡片外壳：图标 + 标题 + 计数 + 箭头，下面是横向头像条或空态提示。
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.items,
    required this.emptyText,
    required this.onTap,
    this.trailingText,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> items;
  final String emptyText;
  final VoidCallback onTap;
  final String? trailingText;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (trailingText != null)
                    Text(
                      trailingText!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Symbols.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              SizedBox(
                height: 72,
                child: Center(
                  child: loading
                      ? const InlineLoadingIndicator(
                          padding: EdgeInsets.zero,
                        )
                      : Text(
                          emptyText,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              )
            else
              SizedBox(
                height: 88,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  scrollDirection: Axis.horizontal,
                  children: items,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 头像条里的一格：头像（可带在线点）+ 名字。
class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.uid,
    required this.avatarUrl,
    required this.name,
    required this.onTap,
    this.showPresence = true,
  });

  final int uid;
  final String? avatarUrl;
  final String name;
  final VoidCallback onTap;
  final bool showPresence;

  @override
  Widget build(BuildContext context) {
    final avatar = ProfilePictureWidget(
      avatarUrl: avatarUrl,
      radius: 22,
      fallbackText: name,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            showPresence && uid >= 0
                ? OnlineAvatarBadge(uid: uid, radius: 22, child: avatar)
                : avatar,
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsSheet extends StatelessWidget {
  const _FriendsSheet({required this.friends});

  final List<Contact> friends;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 弹层打开期间也要跟着在线状态刷新：它和卡片是两棵子树，
    // 不订阅的话在线/离线文案会停在打开那一刻（卡片却在变）。
    return ListenableBuilder(
      listenable: PresenceService.instance,
      builder: (context, _) {
        final presence = PresenceService.instance;
        return SheetScaffold(
          titleText: l10n.accountFriends,
          heightFactor: 0.8,
          child: friends.isEmpty
              ? EmptyState(icon: Symbols.group, title: l10n.accountFriendsEmpty)
              : PullToRefresh.list(
                  onRefresh: () =>
                      ChatDataService.instance.loadContactsAndRooms(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final contact = friends[index];
                      final uid =
                          int.tryParse(contact.id.replaceFirst('U', '')) ?? -1;
                      return ListTile(
                        leading: OnlineAvatarBadge(
                          uid: uid,
                          radius: 20,
                          child: ProfilePictureWidget(
                            avatarUrl: contact.avatar,
                            radius: 20,
                            fallbackText: contact.name,
                          ),
                        ),
                        title: Text(
                          contact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          presence.isKnown(uid)
                              ? (presence.isOnline(uid)
                                    ? l10n.chatOnline
                                    : l10n.chatOffline)
                              : '@${contact.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/user/$uid');
                        },
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

class _BlockedSheet extends StatefulWidget {
  const _BlockedSheet({
    required this.uids,
    required this.profiles,
    required this.nameFor,
    required this.onUnblock,
  });

  final List<int> uids;
  final Map<int, UserProfile?> profiles;
  final String Function(int uid, UserProfile? profile) nameFor;
  final Future<bool> Function(int uid) onUnblock;

  @override
  State<_BlockedSheet> createState() => _BlockedSheetState();
}

class _BlockedSheetState extends State<_BlockedSheet> {
  late List<int> _uids = List<int>.from(widget.uids);
  int? _busyUid;

  Future<void> _unblock(int uid) async {
    setState(() => _busyUid = uid);
    final ok = await widget.onUnblock(uid);
    if (!mounted) return;
    setState(() {
      _busyUid = null;
      if (ok) _uids = _uids.where((u) => u != uid).toList();
    });
    final l10n = AppLocalizations.of(context)!;
    TouchFishSnackbarService.instance.show(
      ok ? l10n.friendUnblockDone : l10n.commonFailedOperation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SheetScaffold(
      titleText: l10n.accountBlocked,
      heightFactor: 0.8,
      child: _uids.isEmpty
          ? EmptyState(icon: Symbols.block, title: l10n.accountBlockedEmpty)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _uids.length,
              itemBuilder: (context, index) {
                final uid = _uids[index];
                final profile = widget.profiles[uid];
                return ListTile(
                  leading: ProfilePictureWidget(
                    avatarUrl: profile?.avatar,
                    radius: 20,
                    fallbackText: widget.nameFor(uid, profile),
                  ),
                  title: Text(
                    widget.nameFor(uid, profile),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('@U$uid'),
                  // 必须是有确定尺寸的 widget：ListTile 的 trailing 里放 Center
                  // 之类会撑满的组件会断言「Trailing widget consumes the entire
                  // tile width」。
                  trailing: _busyUid == uid
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => _unblock(uid),
                          child: Text(l10n.friendUnblock),
                        ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/user/$uid');
                  },
                );
              },
            ),
    );
  }
}
