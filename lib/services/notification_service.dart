import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';

class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  static const _keyLastFetchTime = 'notif_last_fetch_time';
  static const _keyLastReadAnnouncement = 'notif_last_read_announcement';
  static const _keyLastReadFriend = 'notif_last_read_friend';

  final List<NotificationInfo> _allNotifications = [];
  Timer? _pollTimer;
  bool _isLoading = false;
  bool _isInitialLoad = true;
  String? _error;
  double _lastFetchTime = 0;
  double _lastReadAnnouncementTime = 0;
  double _lastReadFriendTime = 0;

  List<NotificationInfo> get allNotifications => List.unmodifiable(_allNotifications);

  List<NotificationInfo> get nonMessageNotifications =>
      _allNotifications.where((n) => !n.isMessageEvent).toList();

  List<NotificationInfo> get friendNotifications =>
      _allNotifications.where((n) => n.isFriendEvent).toList();

  List<NotificationInfo> get announcementNotifications =>
      _allNotifications.where((n) => n.isAnnouncementEvent).toList();

  int get announcementUnreadCount =>
      _allNotifications.where((n) => n.isAnnouncementEvent && n.timeStamp > _lastReadAnnouncementTime).length;

  int get friendUnreadCount =>
      _allNotifications.where((n) => n.isFriendEvent && n.timeStamp > _lastReadFriendTime).length;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadReadTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    _lastFetchTime = prefs.getDouble(_keyLastFetchTime) ?? 0;
    _lastReadAnnouncementTime = prefs.getDouble(_keyLastReadAnnouncement) ?? 0;
    _lastReadFriendTime = prefs.getDouble(_keyLastReadFriend) ?? 0;
    _isInitialLoad = _lastFetchTime == 0;
  }

  Future<void> _saveFetchTime() async {
    final prefs = await SharedPreferences.getInstance();
    _lastFetchTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    await prefs.setDouble(_keyLastFetchTime, _lastFetchTime);
  }

  Future<void> _saveReadTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLastReadAnnouncement, _lastReadAnnouncementTime);
    await prefs.setDouble(_keyLastReadFriend, _lastReadFriendTime);
  }

  Future<void> fetchNotifications() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    _isLoading = true;
    _error = null;

    try {
      List<NotificationInfo> fetched;
      if (_isInitialLoad) {
        fetched = await TfApiClient.instance.queryAllNotifications(uid, password);
        _isInitialLoad = false;
      } else {
        fetched = await TfApiClient.instance.queryNotificationsAfter(
          uid,
          password,
          _lastFetchTime,
        );
      }

      if (fetched.isNotEmpty) {
        final existingStamps = _allNotifications.map((n) => n.timeStamp).toSet();
        for (final n in fetched) {
          if (!existingStamps.contains(n.timeStamp)) {
            _allNotifications.add(n);
          }
        }
        _allNotifications.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
      }

      await _saveFetchTime();
      _error = null;
    } catch (e) {
      talker.error('NotificationService.fetchNotifications failed', e);
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    _pollTimer?.cancel();
    _loadReadTimestamps().then((_) {
      fetchNotifications();
    });
    _pollTimer = Timer.periodic(interval, (_) => fetchNotifications());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void markAnnouncementRead() {
    if (_allNotifications.any((n) => n.isAnnouncementEvent)) {
      _lastReadAnnouncementTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
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
    if (uid == null || password == null || notification.sender == null) {
      return false;
    }

    final success = await TfApiClient.instance.dealFriendShip(
      uid,
      password,
      notification.sender!,
      stat,
    );
    if (success) {
      _allNotifications.remove(notification);
      notifyListeners();
    }
    return success;
  }
}
