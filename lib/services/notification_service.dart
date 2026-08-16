import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/app_notification.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import 'chat_data_service.dart';
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
  final Set<int> _handledFriendSenders = {};
  final Set<String> _handledInviteKeys = {};
  final StreamController<int> _essenceChanges =
      StreamController<int>.broadcast();
  Timer? _pollTimer;
  StreamSubscription<ChatWsEvent>? _wsSubscription;
  bool _isLoading = false;
  bool _isInitialLoad = true;
  bool _isFirstFetchForSession = true;
  String? _error;
  double _lastFetchTime = 0;
  int _unreadCount = 0;
  int? _activeUid;
  String? _activeBaseUrl;

  List<NotificationInfo> get allNotifications =>
      List.unmodifiable(_allNotifications);

  /// 系统事件通知（new api通知表只存系统事件，消息不再混入）让我们感谢 xsfx的恩情还不完
  List<NotificationInfo> get nonMessageNotifications => allNotifications;

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
    final baseUrl = await TfApiClient.instance.getBaseUrl();

    if (_activeUid != uid || _activeBaseUrl != baseUrl) {
      _activeUid = uid;
      _activeBaseUrl = baseUrl;
      _allNotifications.clear();
      _handledFriendSenders.clear();
      _handledInviteKeys.clear();
      _lastFetchTime = 0;
      _isFirstFetchForSession = true;
      await _loadFetchTime(baseUrl, uid);
    }

    _isLoading = true;
    _error = null;

    try {
      final since = _lastFetchTime > 0
          ? _lastFetchTime
          : (DateTime.now().millisecondsSinceEpoch / 1000) - 7 * 86400;
      final fetched = await TfApiClient.instance.queryNotificationsAfter(
        uid,
        password,
        since,
      );

      if (_activeUid != uid || _activeBaseUrl != baseUrl) return;

      talker.info(
        'NotificationService: fetched ${fetched.length} notifications',
      );

      if (fetched.isNotEmpty) {
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

  Future<void> forceRefresh() async {
    _isInitialLoad = true;
    _allNotifications.clear();
    _handledFriendSenders.clear();
    _lastFetchTime = 0;
    await fetchNotifications();
  }

  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    _pollTimer?.cancel();
    // 首次启动/登录时会在短时间内恢复历史通知（可能较多），
    // 抑制应用内横幅一段时间，只累计各栏目角标，避免集中轰炸。
    if (_isFirstFetchForSession || _isInitialLoad) {
      AppNotificationService.instance.suppressInAppBanners(
        const Duration(seconds: 10),
      );
    }
    _wsSubscription ??= ChatWsService.instance.eventStream.listen(_onWsEvent);
    fetchNotifications();
    _pollTimer = Timer.periodic(interval, (_) => fetchNotifications());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _wsSubscription?.cancel();
    _wsSubscription = null;
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

  Future<bool> markAnnouncementRead() =>
      _markCategoryRead(announcementNotifications);

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
