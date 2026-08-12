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

class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  static const _keyLastFetchTime = 'notif_last_fetch_time';
  static const _keyLastReadAnnouncement = 'notif_last_read_announcement';
  static const _keyLastReadFriend = 'notif_last_read_friend';
  static const _keyLastReadInvite = 'notif_last_read_invite';
  static const _keyLastReadForum = 'notif_last_read_forum';

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
  double _lastReadAnnouncementTime = 0;
  double _lastReadFriendTime = 0;
  double _lastReadInviteTime = 0;
  double _lastReadForumTime = 0;
  int? _activeUid;
  String? _activeBaseUrl;

  List<NotificationInfo> get allNotifications =>
      List.unmodifiable(_allNotifications);

  List<NotificationInfo> get nonMessageNotifications =>
      _allNotifications.where((n) => !n.isMessageEvent).toList();

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

  int get announcementUnreadCount => _allNotifications
      .where(
        (n) => n.isAnnouncementEvent && n.timeStamp > _lastReadAnnouncementTime,
      )
      .length;

  int get friendUnreadCount => _allNotifications
      .where((n) => n.isFriendEvent && n.timeStamp > _lastReadFriendTime)
      .length;

  int get inviteUnreadCount => inviteNotifications
      .where((n) => n.timeStamp > _lastReadInviteTime)
      .length;
  int get forumUnreadCount =>
      forumNotifications.where((n) => n.timeStamp > _lastReadForumTime).length;

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

  Future<bool> _loadReadTimestamps(String baseUrl, int uid) async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchTime =
        prefs.getDouble(scopedPreferenceKey(_keyLastFetchTime, baseUrl, uid)) ??
        0;
    final lastReadAnnouncementTime =
        prefs.getDouble(
          scopedPreferenceKey(_keyLastReadAnnouncement, baseUrl, uid),
        ) ??
        0;
    final lastReadFriendTime =
        prefs.getDouble(
          scopedPreferenceKey(_keyLastReadFriend, baseUrl, uid),
        ) ??
        0;
    final lastReadInviteTime =
        prefs.getDouble(
          scopedPreferenceKey(_keyLastReadInvite, baseUrl, uid),
        ) ??
        0;
    final lastReadForumTime =
        prefs.getDouble(scopedPreferenceKey(_keyLastReadForum, baseUrl, uid)) ??
        0;
    if (_activeUid != uid || _activeBaseUrl != baseUrl) return false;

    _lastFetchTime = lastFetchTime;
    _lastReadAnnouncementTime = lastReadAnnouncementTime;
    _lastReadFriendTime = lastReadFriendTime;
    _lastReadInviteTime = lastReadInviteTime;
    _lastReadForumTime = lastReadForumTime;
    _isInitialLoad = _lastFetchTime == 0;
    return true;
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

  Future<void> _saveReadTimestamps() async {
    final uid = _activeUid;
    final baseUrl = _activeBaseUrl;
    if (uid == null || baseUrl == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      scopedPreferenceKey(_keyLastReadAnnouncement, baseUrl, uid),
      _lastReadAnnouncementTime,
    );
    await prefs.setDouble(
      scopedPreferenceKey(_keyLastReadFriend, baseUrl, uid),
      _lastReadFriendTime,
    );
    await prefs.setDouble(
      scopedPreferenceKey(_keyLastReadInvite, baseUrl, uid),
      _lastReadInviteTime,
    );
    await prefs.setDouble(
      scopedPreferenceKey(_keyLastReadForum, baseUrl, uid),
      _lastReadForumTime,
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
      if (!await _loadReadTimestamps(baseUrl, uid)) return;
    }

    _isLoading = true;
    _error = null;

    try {
      List<NotificationInfo> fetched;
      final shouldProcessAsHistorical =
          _isInitialLoad || _isFirstFetchForSession;
      // Always use time-based fetch to avoid pulling every notification ever.
      // If no previous fetch time is recorded, look back 7 days.
      var since = _lastFetchTime;
      if (since <= 0) {
        since = (DateTime.now().millisecondsSinceEpoch / 1000) - 7 * 86400;
      }
      fetched = await TfApiClient.instance.queryNotificationsAfter(
        uid,
        password,
        since,
      );

      if (_activeUid != uid || _activeBaseUrl != baseUrl) return;

      talker.info(
        'NotificationService: fetched ${fetched.length} notifications (lastFetchTime=$_lastFetchTime)',
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
            if (n.isMessageEvent && n.senderUid != null) {
              ChatDataService.instance.processPolledMessage(
                n,
                isHistorical: shouldProcessAsHistorical,
              );
            } else if (n.event == 'friend.accepted' && n.senderUid != null) {
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
      _error = null;
    } catch (e) {
      talker.error('NotificationService.fetchNotifications failed', e);
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    if (notification.isMessageEvent ||
        _allNotifications.any(
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
        ChatDataService.instance
                .roomNotifyLevel('G${notification.groupEventGid}') !=
            0) {
      return;
    }
    _allNotifications.add(notification);
    _allNotifications.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
    unawaited(_presentNotification(notification));
    notifyListeners();
  }

  Future<void> _presentNotification(NotificationInfo notification) async {
    var appNotification = AppNotification.fromNotificationInfo(notification);
    final avatar = appNotification.avatarUrl;
    if (avatar != null && avatar.startsWith('/')) {
      try {
        final baseUrl = await TfApiClient.instance.getBaseUrl();
        appNotification = appNotification.copyWith(avatarUrl: '$baseUrl$avatar');
      } catch (_) {}
    }
    await AppNotificationService.instance.present(appNotification);
  }

  void markAnnouncementRead() {
    final notifications = announcementNotifications;
    if (notifications.isNotEmpty) {
      _lastReadAnnouncementTime = notifications.fold<double>(
        _lastReadAnnouncementTime,
        (latest, notification) =>
            notification.timeStamp > latest ? notification.timeStamp : latest,
      );
      _saveReadTimestamps();
      notifyListeners();
    }
  }

  void markFriendRead() {
    final notifications = friendNotifications;
    if (notifications.isNotEmpty) {
      _lastReadFriendTime = notifications.fold<double>(
        _lastReadFriendTime,
        (latest, notification) =>
            notification.timeStamp > latest ? notification.timeStamp : latest,
      );
      _saveReadTimestamps();
      notifyListeners();
    }
  }

  void markInviteRead() {
    final notifications = inviteNotifications;
    if (notifications.isEmpty) return;
    _lastReadInviteTime = notifications.fold<double>(
      _lastReadInviteTime,
      (latest, notification) =>
          notification.timeStamp > latest ? notification.timeStamp : latest,
    );
    _saveReadTimestamps();
    notifyListeners();
  }

  void markForumRead() {
    final notifications = forumNotifications;
    if (notifications.isEmpty) return;
    _lastReadForumTime = notifications.fold<double>(
      _lastReadForumTime,
      (latest, notification) =>
          notification.timeStamp > latest ? notification.timeStamp : latest,
    );
    _saveReadTimestamps();
    notifyListeners();
  }

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
      unawaited(
        TfApiClient.instance.deleteNotificationsBefore(
          uid,
          password,
          notification.timeStamp + 0.001,
        ),
      );
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
