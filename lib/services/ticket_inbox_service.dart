import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'auth_state.dart';
import 'notification_service.dart';


class TicketInboxService extends ChangeNotifier {
  static TicketInboxService? _instance;
  static TicketInboxService get instance =>
      _instance ??= TicketInboxService._();
  TicketInboxService._();

  /// 合并窗口
  static const _refreshCoalesceWindow = Duration(seconds: 3);
  static const _fallbackPollInterval = Duration(minutes: 5);

  Timer? _fallbackTimer;
  Timer? _coalesceTimer;
  bool _listening = false;
  bool _isLoading = false;
  int _pendingCount = 0;
  int _unreadCount = 0;

  /// 管理员队列待处理
  int get pendingCount => _pendingCount;

  /// 当前用户工单未读回复
  int get unreadCount => _unreadCount;

  bool get isLoading => _isLoading;
  bool get isRealtime => NotificationService.instance.isRealtime;

  Future<void> refresh() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      _pendingCount = 0;
      _unreadCount = 0;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        TfApiClient.instance.getTicketPendingCount(uid, password),
        TfApiClient.instance.getTicketUnreadCount(uid, password),
      ]);
      _pendingCount = results[0];
      _unreadCount = results[1];
    } catch (error) {
      talker.error('TicketInboxService.refresh failed', error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startWatching() {
    if (!_listening) {
      NotificationService.instance.addListener(_onNotificationsChanged);
      _listening = true;
    }
    _syncFallbackPolling();
    refresh();
  }

  void stopWatching() {
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    if (_listening) {
      NotificationService.instance.removeListener(_onNotificationsChanged);
      _listening = false;
    }
  }

  void _syncFallbackPolling() {
    if (NotificationService.instance.isRealtime) {
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
      return;
    }
    _fallbackTimer ??= Timer.periodic(
      _fallbackPollInterval,
      (_) => refresh(),
    );
  }

  void _onNotificationsChanged() {
    _syncFallbackPolling();
    final latest = NotificationService.instance.allNotifications;
    if (latest.isEmpty) return;
    if (!latest.any((n) => n.event.startsWith('ticket.'))) return;

    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_refreshCoalesceWindow, refresh);
  }
}
