import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/app_notification.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import 'chat_data_service.dart';
import 'notification_local_store.dart';
import 'chat_ws_service.dart';
import 'app_notification_service.dart';
import '../utils/talker.dart';

/// 通知中心服务（仅系统事件）。
///
/// 消息不再经由此通道！！！！！！！！！！：消息实时 MESSAGE.NEW，断线补拉
/// /message/sync。通知的已读状态由服务端维护（read_at），未读数与
/// 标记已读均调用服务端 API，多端同步。
class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  static const _keyLastFetchTime = 'notif_last_fetch_time';

  final List<NotificationInfo> _allNotifications = [];
  final NotificationLocalStore _localStore = NotificationLocalStore.instance;
  Timer? _persistTimer;

  /// 向下翻页状态。
  bool _loadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 50;
  final Set<int> _handledFriendSenders = {};
  /// 本次会话已经强提醒过的处罚通知
  final Set<String> _presentedPunishments = {};
  final Set<String> _handledInviteKeys = {};
  final StreamController<int> _essenceChanges =
      StreamController<int>.broadcast();
  Timer? _pollTimer;
  StreamSubscription<ChatWsEvent>? _wsSubscription;
  bool _listeningWsState = false;
  bool _wsAuthenticated = false;
  Duration _pollInterval = const Duration(seconds: 30);
  bool _isLoading = false;
  bool _isInitialLoad = true;
  /// 本进程/本账号的首次拉取全量
  bool _needsFullReload = true;
  bool _isFirstFetchForSession = true;
  String? _error;
  double _lastFetchTime = 0;
  int _unreadCount = 0;
  int? _activeUid;
  String? _activeBaseUrl;

  List<NotificationInfo> get allNotifications =>
      List.unmodifiable(_allNotifications);

  int get unreadCount => _unreadCount;

  List<NotificationInfo> get friendNotifications => _allNotifications
      .where(
        (n) => n.isFriendEvent && !_handledFriendSenders.contains(n.senderUid),
      )
      .toList();

  List<NotificationInfo> get announcementNotifications =>
      _allNotifications.where((n) => n.isAnnouncementEvent).toList();

  List<NotificationInfo> get inviteNotifications => _allNotifications
      .where(
        (n) =>
            n.isInviteEvent &&
            !_handledInviteKeys.contains(n.identityKey) &&
            (!n.isFriendEvent || !_handledFriendSenders.contains(n.senderUid)),
      )
      .toList();
  List<NotificationInfo> get forumNotifications =>
      _allNotifications.where((n) => n.isForumEvent).toList();

  /// 系统类
  /// 不属于好友/论坛/群组的都算
  List<NotificationInfo> get systemNotifications => _allNotifications
      .where(
        (n) =>
            !n.isMessageEvent &&
            !n.isFriendEvent &&
            !n.isForumEvent &&
            !n.isGroupEvent,
      )
      .toList();

  int get announcementUnreadCount =>
      categoryUnreadCount(announcementNotifications);

  int get friendUnreadCount => categoryUnreadCount(friendNotifications);

  int get inviteUnreadCount => categoryUnreadCount(inviteNotifications);
  int get forumUnreadCount => categoryUnreadCount(forumNotifications);

  @visibleForTesting
  static int categoryUnreadCount(Iterable<NotificationInfo> notifications) =>
      notifications.where((notification) => notification.readAt == null).length;

  Stream<int> get essenceChanges => _essenceChanges.stream;

  bool get isLoading => _isLoading;
  bool get isRealtime => _wsAuthenticated && _wsSubscription != null;
  String? get error => _error;

  @visibleForTesting
  static String scopedPreferenceKey(
    String baseKey,
    String serverBaseUrl,
    int uid,
  ) {
    final uri = Uri.parse(serverBaseUrl);
    return '$baseKey:${uri.scheme}://${uri.host}:${uri.port}:$uid';
  }

  Future<void> _loadFetchTime(String baseUrl, int uid) async {
    final prefs = await SharedPreferences.getInstance();
    _lastFetchTime =
        prefs.getDouble(scopedPreferenceKey(_keyLastFetchTime, baseUrl, uid)) ??
        0;
    _isInitialLoad = _lastFetchTime == 0;
  }

  Future<void> _saveFetchTime(double fetchTime, String baseUrl, int uid) async {
    if (_activeUid != uid || _activeBaseUrl != baseUrl) return;
    if (fetchTime <= _lastFetchTime) return;
    final prefs = await SharedPreferences.getInstance();
    _lastFetchTime = fetchTime;
    await prefs.setDouble(
      scopedPreferenceKey(_keyLastFetchTime, baseUrl, uid),
      _lastFetchTime,
    );
  }

  Future<void> fetchNotifications() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    if (_isLoading) return;
    final baseUrl = await TfApiClient.instance.getBaseUrl();

    if (_activeUid != uid || _activeBaseUrl != baseUrl) {
      _activeUid = uid;
      _activeBaseUrl = baseUrl;
      _allNotifications.clear();
      _handledFriendSenders.clear();
      _handledInviteKeys.clear();
      _lastFetchTime = 0;
      _needsFullReload = true;
      _isFirstFetchForSession = true;
      await _loadFetchTime(baseUrl, uid);
      await _loadLocalCache(baseUrl, uid);
    }

    _isLoading = true;
    _error = null;

    try {
      final fullReload = _needsFullReload || _isInitialLoad;
      _needsFullReload = false;
      final fetched = fullReload
          ? await TfApiClient.instance.queryAllNotifications(uid, password)
          : _lastFetchTime > 0
          ? await TfApiClient.instance.queryNotificationsAfter(
              uid,
              password,
              _lastFetchTime,
            )
          : await TfApiClient.instance.queryAllNotifications(uid, password);

      if (_activeUid != uid || _activeBaseUrl != baseUrl) return;

      if (fetched == null) {
        // 请求失败
        talker.warning('NotificationService: fetch failed, keep local cache');
        _isLoading = false;
        notifyListeners();
        return;
      }

      talker.info(
        'NotificationService: fetched ${fetched.length} notifications',
      );

      if (fullReload) {
        // 全量拉取以服务端为准
        _isInitialLoad = false;
        _hasMore = fetched.length >= 500;
        if (!_sameContentAs(fetched)) {
          _allNotifications
            ..clear()
            ..addAll(fetched)
            ..sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
        }
      } else if (fetched.isNotEmpty) {
        _isInitialLoad = false;
        final existingKeys = _allNotifications
            .map((n) => n.identityKey)
            .toSet();
        for (final n in fetched) {
          if (existingKeys.add(n.identityKey)) {
            if (n.event == 'group.essence.add' ||
                n.event == 'group.essence.remove') {
              final gid = n.groupEventGid;
              if (gid != null) _essenceChanges.add(gid);
            }
            _allNotifications.add(n);
            if (n.event == 'friend.accepted' && n.senderUid != null) {
              ChatDataService.instance.addFriendToContacts(n.senderUid!);
            } else if (n.event == 'group.invited' ||
                n.event == 'group.join.approved' ||
                n.event == 'group.left' ||
                n.event == 'group.member.removed' ||
                n.event == 'group.deleted' ||
                n.event == 'friend.request') {
              final gid = n.groupEventGid;
              if (gid != null &&
                  (n.event == 'group.left' ||
                      n.event == 'group.member.removed' ||
                      n.event == 'group.deleted')) {
                unawaited(ChatDataService.instance.removeRoom('G$gid'));
              }
              ChatDataService.instance.loadContactsAndRooms();
            }
          }
        }
        _allNotifications.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
      }
      _presentUnreadPunishments(fetched);
      _schedulePersist();

      _isInitialLoad = false;
      _isFirstFetchForSession = false;
      final newestFetchTime = fetched.fold<double>(
        _lastFetchTime,
        (currentMax, notification) => notification.timeStamp > currentMax
            ? notification.timeStamp
            : currentMax,
      );
      await _saveFetchTime(newestFetchTime, baseUrl, uid);
      await _refreshUnreadCount();
      _error = null;
    } catch (e) {
      talker.error('NotificationService.fetchNotifications failed', e);
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _presentUnreadPunishments(Iterable<NotificationInfo> fetched) {
    for (final notification in fetched) {
      if (!notification.isPunishmentEvent) continue;
      if (notification.readAt != null) continue;
      if (!_presentedPunishments.add(notification.identityKey)) continue;
      unawaited(
        AppNotificationService.instance.presentUrgent(
          AppNotification.fromNotificationInfo(notification),
        ),
      );
    }
  }

  /// 服务端结果与当前列表是否等
  bool _sameContentAs(List<NotificationInfo> fetched) {
    if (fetched.length != _allNotifications.length) return false;
    String signature(NotificationInfo n) =>
        '${n.identityKey}|${n.readAt ?? ''}|${n.locked}';
    final current = _allNotifications.map(signature).toSet();
    final incoming = fetched.map(signature).toSet();
    return current.length == incoming.length &&
        current.containsAll(incoming);
  }

  /// 读本地缓存
  Future<void> _loadLocalCache(String baseUrl, int uid) async {
    final cached = await _localStore.load(baseUrl, uid);
    if (cached.isEmpty) return;
    if (_activeUid != uid || _activeBaseUrl != baseUrl) return;
    final existingKeys = _allNotifications.map((n) => n.identityKey).toSet();
    for (final n in cached) {
      if (existingKeys.add(n.identityKey)) _allNotifications.add(n);
    }
    _allNotifications.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
    notifyListeners();
  }

  /// 合并写
  void _schedulePersist() {
    final uid = _activeUid;
    final baseUrl = _activeBaseUrl;
    if (uid == null || baseUrl == null) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(
        _localStore.save(baseUrl, uid, List.unmodifiable(_allNotifications)),
      );
    });
  }

  bool get isLoadingMore => _loadingMore;

  /// 还有更早的通知
  bool get hasMore => _hasMore;

  Future<bool> loadMoreNotifications() async {
    if (_loadingMore || !_hasMore) return false;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return false;

    var oldest = double.infinity;
    for (final n in _allNotifications) {
      if (n.timeStamp < oldest) oldest = n.timeStamp;
    }
    if (oldest.isInfinite) return false;

    final baseUrl = await TfApiClient.instance.getBaseUrl();
    if (_activeUid != uid || _activeBaseUrl != baseUrl) return false;

    _loadingMore = true;
    notifyListeners();
    final page = await TfApiClient.instance.queryNotificationsBefore(
      uid,
      password,
      oldest,
      limit: _pageSize,
    );
    // 请求期间换账号/换服务器
    if (_activeUid != uid || _activeBaseUrl != baseUrl) {
      _loadingMore = false;
      return false;
    }
    _loadingMore = false;

    if (page == null) {
      // 失败
      //保留 _hasMore
      notifyListeners();
      return false;
    }
    if (page.isEmpty) {
      _hasMore = false;
      notifyListeners();
      return false;
    }

    final existingKeys = _allNotifications.map((n) => n.identityKey).toSet();
    var added = 0;
    for (final n in page) {
      if (existingKeys.add(n.identityKey)) {
        _allNotifications.add(n);
        added++;
      }
    }
    _allNotifications.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
    // 拉到的这一页不足一页
    // 没有更早
    if (page.length < _pageSize) _hasMore = false;
    talker.info('NotificationService: loaded $added older notifications');
    _schedulePersist();
    notifyListeners();
    return added > 0;
  }

  Future<void> _refreshUnreadCount() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    final count = await TfApiClient.instance.unreadNotificationCount(
      uid,
      password,
    );
    if (AuthState.instance.uid != uid ||
        AuthState.instance.password != password ||
        _activeUid != uid ||
        _activeBaseUrl != baseUrl) {
      return;
    }
    _unreadCount = count;
  }

  /// 测试用：直接注入通知列表
  @visibleForTesting
  void debugReplaceNotifications(
    List<NotificationInfo> notifications, {
    int? unreadCount,
  }) {
    _allNotifications
      ..clear()
      ..addAll(notifications);
    if (unreadCount != null) _unreadCount = unreadCount;
    notifyListeners();
  }

  /// 测试用：直接设定
  @visibleForTesting
  void debugSetHasMore(bool value) {
    _hasMore = value;
    notifyListeners();
  }

  Future<void> forceRefresh() async {
    _isInitialLoad = true;
    _needsFullReload = true;
    // 强制刷新要能盖掉正在进行的拉取
    _isLoading = false;
    _allNotifications.clear();
    _handledFriendSenders.clear();
    _lastFetchTime = 0;
    await fetchNotifications();
  }

  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    _pollInterval = interval;
    _pollTimer?.cancel();
    _pollTimer = null;
    // 首次启动/登录时会在短时间内恢复历史通知（可能较多），
    // 抑制应用内横幅一段时间，只累计各栏目角标，避免集中轰炸。
    if (_isFirstFetchForSession || _isInitialLoad) {
      AppNotificationService.instance.suppressInAppBanners(
        const Duration(seconds: 10),
      );
    }
    _wsSubscription ??= ChatWsService.instance.eventStream.listen(_onWsEvent);
    if (!_listeningWsState) {
      ChatWsService.instance.addListener(_onWsAuthStateChanged);
      _wsAuthenticated = ChatWsService.instance.isAuthenticated;
      _listeningWsState = true;
    }
    fetchNotifications();
    _syncPollTimer();
  }

  /// WS 已认证时停止轮询：NOTIFICATION.NEW 已经实时推送，轮询纯属重复请求。
  void _syncPollTimer() {
    if (ChatWsService.instance.isAuthenticated) {
      if (_pollTimer != null) {
        talker.info('NotificationService: WS authenticated, polling paused');
      }
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => fetchNotifications());
  }

  void _onWsAuthStateChanged() {
    final wasPolling = _pollTimer != null;
    final wasAuthenticated = _wsAuthenticated;
    _wsAuthenticated = ChatWsService.instance.isAuthenticated;
    _syncPollTimer();
    if (!wasPolling && _pollTimer != null) {
      talker.info('NotificationService: WS offline, polling resumed');
    }
    if (_wsAuthenticated && !wasAuthenticated) {
      // 重连成功必须补拉一次：断线期间（以及服务端因发送队列满而丢弃 WS 帧时）
      // 写入的通知没有任何重放机制，而轮询此刻是暂停的，不补拉就一直看不到。
      talker.info('NotificationService: WS re-authenticated, catching up');
      unawaited(fetchNotifications());
    }
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    if (_listeningWsState) {
      ChatWsService.instance.removeListener(_onWsAuthStateChanged);
      _listeningWsState = false;
    }
    _wsAuthenticated = false;
    // 换账号或登出后要能对新会话重新提醒一次
    _presentedPunishments.clear();
  }

  void _onWsEvent(ChatWsEvent event) {
    if (event.type != 'NOTIFICATION.NEW' || event.notification == null) return;
    final notification = NotificationInfo.fromServerJson(event.notification!);
    if (_allNotifications.any(
      (n) => n.identityKey == notification.identityKey,
    )) {
      return;
    }
    if (notification.event == 'group.essence.add' ||
        notification.event == 'group.essence.remove') {
      final gid = notification.groupEventGid;
      if (gid != null) _essenceChanges.add(gid);
    }
    if ((notification.event == 'group.essence.add' ||
            notification.event == 'group.essence.remove') &&
        notification.groupEventGid != null &&
        ChatDataService.instance.roomNotifyLevel(
              'G${notification.groupEventGid}',
            ) !=
            0) {
      return;
    }
    _allNotifications.add(notification);
    _allNotifications.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
    unawaited(_presentNotification(notification));
    _unreadCount++;
    notifyListeners();
  }

  Future<void> _presentNotification(NotificationInfo notification) async {
    var appNotification = AppNotification.fromNotificationInfo(notification);
    final avatar = appNotification.avatarUrl;
    if (avatar != null && avatar.startsWith('/')) {
      try {
        final baseUrl = await TfApiClient.instance.getBaseUrl();
        appNotification = appNotification.copyWith(
          avatarUrl: '$baseUrl$avatar',
        );
      } catch (_) {}
    }
    await AppNotificationService.instance.present(appNotification);
  }

  Future<bool> _markCategoryRead(List<NotificationInfo> notifications) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final ids = unreadNotificationIds(notifications);
    if (uid == null || password == null || ids.isEmpty) {
      return false;
    }
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    if (_activeUid != uid || _activeBaseUrl != baseUrl) return false;

    final success = await TfApiClient.instance.markNotificationsRead(
      uid,
      password,
      ids: ids,
    );
    if (!success) return false;

    if (AuthState.instance.uid != uid ||
        AuthState.instance.password != password ||
        _activeUid != uid ||
        _activeBaseUrl != baseUrl ||
        await TfApiClient.instance.getBaseUrl() != baseUrl) {
      return true;
    }

    final updated = applyReadAtByIds(
      _allNotifications,
      ids,
      DateTime.now().millisecondsSinceEpoch / 1000,
    );
    _unreadCount = _unreadCount >= updated ? _unreadCount - updated : 0;
    notifyListeners();
    _schedulePersist();
    await _refreshUnreadCount();
    notifyListeners();
    return true;
  }

  @visibleForTesting
  static List<int> unreadNotificationIds(
    Iterable<NotificationInfo> notifications,
  ) => notifications
      .where(
        (notification) => notification.readAt == null && notification.id > 0,
      )
      .map((notification) => notification.id)
      .toList();

  @visibleForTesting
  static int applyReadAtByIds(
    List<NotificationInfo> notifications,
    Iterable<int> ids,
    double readAt,
  ) {
    final idSet = ids.toSet();
    var updated = 0;
    for (var index = 0; index < notifications.length; index++) {
      final notification = notifications[index];
      if (notification.readAt == null && idSet.contains(notification.id)) {
        notifications[index] = notification.withReadAt(readAt);
        updated++;
      }
    }
    return updated;
  }

  /// 标记单条通知已读。
  ///
  /// 通知中心里点开某一条就该消掉那一条的红点，而不是把整类全部清掉——
  /// 后者会让用户丢掉"这一批里我还没看的是哪几条"的信息。
  Future<bool> markReadFor(NotificationInfo notification) =>
      _markCategoryRead([notification]);

  Future<bool> markAnnouncementRead() =>
      _markCategoryRead(announcementNotifications);

  /// 系统类
  Future<bool> markSystemRead() => _markCategoryRead(systemNotifications);

  Future<bool> markFriendRead() => _markCategoryRead(friendNotifications);

  Future<bool> markInviteRead() => _markCategoryRead(inviteNotifications);

  Future<bool> markForumRead() => _markCategoryRead(forumNotifications);

  Future<bool> handleGroupJoinRequest(
    NotificationInfo notification,
    bool approved,
  ) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final rid = notification.groupRequestRid;
    if (uid == null || password == null || rid == null) return false;
    final success = await TfApiClient.instance.handleJoinRequest(
      uid,
      password,
      rid,
      approved,
    );
    if (success) {
      _handledInviteKeys.add(notification.identityKey);
      _allNotifications.remove(notification);
      notifyListeners();
      if (approved) ChatDataService.instance.loadContactsAndRooms();
    }
    return success;
  }

  /// 删除单条通知。
  ///
  /// 先本地移除再发请求（乐观更新）：列表本来就在用户眼前，
  /// 等一个来回再消掉卡片会让人以为没删成功而重复操作。
  /// 请求失败时用 [fetchNotifications] 拉回真实状态，不做手工回滚——
  /// 本地回滚要处理"期间又来了新通知"的插入位置，容易错。
  Future<bool> deleteFor(NotificationInfo notification) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return false;
    if (notification.id <= 0) return false;
    // 未到期的处罚通知不可删除
    if (notification.locked) return false;

    final index = _allNotifications.indexWhere((n) => n.id == notification.id);
    if (index == -1) return false;
    final removed = _allNotifications.removeAt(index);
    if (removed.readAt == null && _unreadCount > 0) _unreadCount--;
    notifyListeners();
    _schedulePersist();

    final success = await TfApiClient.instance.deleteNotificationsByIds(
      uid,
      password,
      [notification.id],
    );
    if (!success) {
      await fetchNotifications();
      notifyListeners();
    }
    return success;
  }

  Future<bool> clearAllNotifications() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return false;

    final success = await TfApiClient.instance.deleteAllNotifications(
      uid,
      password,
    );
    if (success) {
      _allNotifications.clear();
      _handledFriendSenders.clear();
      _handledInviteKeys.clear();
      _unreadCount = 0;
      notifyListeners();
    }
    return success;
  }

  Future<bool> acceptFriendRequest(NotificationInfo notification) async {
    return _handleFriendResponse(notification, 'allow');
  }

  Future<bool> rejectFriendRequest(NotificationInfo notification) async {
    return _handleFriendResponse(notification, 'reject');
  }

  Future<bool> _handleFriendResponse(
    NotificationInfo notification,
    String stat,
  ) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null || notification.senderUid == null) {
      return false;
    }

    final success = await TfApiClient.instance.dealFriendShip(
      uid,
      password,
      notification.senderUid!,
      stat,
    );
    talker.info(
      'NotificationService._handleFriendResponse: stat=$stat, senderUid=${notification.senderUid}, success=$success',
    );
    if (success) {
      if (notification.senderUid != null) {
        _handledFriendSenders.add(notification.senderUid!);
      }
      _allNotifications.remove(notification);
      if (notification.id > 0) {
        unawaited(
          TfApiClient.instance.markNotificationsRead(
            uid,
            password,
            ids: [notification.id],
          ),
        );
      }
      notifyListeners();
      if (stat == 'allow' && notification.senderUid != null) {
        talker.info(
          'NotificationService._handleFriendResponse: calling addFriendToContacts(${notification.senderUid})',
        );
        ChatDataService.instance.addFriendToContacts(notification.senderUid!);
      }
    }
    return success;
  }
}
