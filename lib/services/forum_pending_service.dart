import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/notification_service.dart';
import '../utils/talker.dart';

/// 论坛待审数
class ForumPendingService extends ChangeNotifier {
  static ForumPendingService? _instance;
  static ForumPendingService get instance =>
      _instance ??= ForumPendingService._();
  ForumPendingService._();

  static const _refreshCoalesceWindow = Duration(seconds: 3);
  static const _fallbackPollInterval = Duration(minutes: 5);

  Timer? _fallbackTimer;
  Timer? _coalesceTimer;
  bool _listening = false;
  bool _isLoading = false;
  int _pendingCount = 0;
  String? _error;

  int get pendingCount => _pendingCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> refresh() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      _pendingCount = 0;
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final forums = await TfApiClient.instance.getApprovingForumList(
        uid,
        password,
      );
      _pendingCount = forums.length;
      _error = null;
    } catch (e) {
      talker.error('ForumPendingService.refresh failed', e);
      _error = e.toString();
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
    final realtime = NotificationService.instance.isRealtime;
    if (realtime) {
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
    final latest = NotificationService.instance.forumNotifications;
    if (latest.isEmpty) return;
    if (!latest.any((n) => n.event == 'forum.review.pending')) return;

    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_refreshCoalesceWindow, refresh);
  }
}
