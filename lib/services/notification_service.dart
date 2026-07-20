import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import 'chat_data_service.dart';
import '../utils/talker.dart';

class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  static const _keyLastFetchTime = 'notif_last_fetch_time';
  static const _keyLastReadAnnouncement = 'notif_last_read_announcement';
  static const _keyLastReadFriend = 'notif_last_read_friend';

  final List<NotificationInfo> _allNotifications = [];
  final Set<int> _handledFriendSenders = {};
  Timer? _pollTimer;
  bool _isLoading = false;
  bool _isInitialLoad = true;
  String? _error;
  double _lastFetchTime = 0;
  double _lastReadAnnouncementTime = 0;
  double _lastReadFriendTime = 0;
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

  int get announcementUnreadCount => _allNotifications
      .where(
        (n) => n.isAnnouncementEvent && n.timeStamp > _lastReadAnnouncementTime,
      )
      .length;

  int get friendUnreadCount => _allNotifications
      .where((n) => n.isFriendEvent && n.timeStamp > _lastReadFriendTime)
      .length;

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
    if (_activeUid != uid || _activeBaseUrl != baseUrl) return false;

    _lastFetchTime = lastFetchTime;
    _lastReadAnnouncementTime = lastReadAnnouncementTime;
    _lastReadFriendTime = lastReadFriendTime;
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
      _lastFetchTime = 0;
      if (!await _loadReadTimestamps(baseUrl, uid)) return;
    }

    _isLoading = true;
    _error = null;

    try {
      List<NotificationInfo> fetched;
      if (_isInitialLoad) {
        talker.info(
          'NotificationService: initial load (queryAll) for uid=$uid',
        );
        fetched = await TfApiClient.instance.queryAllNotifications(
          uid,
          password,
        );
      } else {
        fetched = await TfApiClient.instance.queryNotificationsAfter(
          uid,
          password,
          _lastFetchTime,
        );
      }

      if (_activeUid != uid || _activeBaseUrl != baseUrl) return;

      talker.info(
        'NotificationService: fetched ${fetched.length} notifications (isInitialLoad=$_isInitialLoad, lastFetchTime=$_lastFetchTime)',
      );
      for (final n in fetched) {
        talker.info(
          '  notif: event=${n.event}, senderRaw=${n.senderRaw}, senderUid=${n.senderUid}, content=${n.content}',
        );
      }

      if (fetched.isNotEmpty) {
        _isInitialLoad = false;
        final existingStamps = _allNotifications
            .map((n) => n.timeStamp)
            .toSet();
        for (final n in fetched) {
          if (!existingStamps.contains(n.timeStamp)) {
            _allNotifications.add(n);
            // Forward message notifications to chat data service
            if (n.isMessageEvent && n.senderUid != null) {
              ChatDataService.instance.processPolledMessage(n);
            } else if (n.event == 'friend.accepted' && n.senderUid != null) {
              ChatDataService.instance.addFriendToContacts(n.senderUid!);
            } else if (n.event == 'group.invited' ||
                n.event == 'group.join.approved' ||
                n.event == 'group.member.removed' ||
                n.event == 'group.deleted' ||
                n.event == 'friend.request') {
              ChatDataService.instance.loadContactsAndRooms();
            }
          }
        }
        _allNotifications.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
      }

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
    fetchNotifications();
    _pollTimer = Timer.periodic(interval, (_) => fetchNotifications());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void markAnnouncementRead() {
    if (_allNotifications.any((n) => n.isAnnouncementEvent)) {
      _lastReadAnnouncementTime =
          DateTime.now().millisecondsSinceEpoch / 1000.0;
      _saveReadTimestamps();
      notifyListeners();
    }
  }

  void markFriendRead() {
    if (_allNotifications.any((n) => n.isFriendEvent)) {
      _lastReadFriendTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
      _saveReadTimestamps();
      notifyListeners();
    }
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
