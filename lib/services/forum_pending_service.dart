import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';

class ForumPendingService extends ChangeNotifier {
  static ForumPendingService? _instance;
  static ForumPendingService get instance =>
      _instance ??= ForumPendingService._();
  ForumPendingService._();

  Timer? _pollTimer;
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

  void startPolling({Duration interval = const Duration(minutes: 10)}) {
    _pollTimer?.cancel();
    refresh();
    _pollTimer = Timer.periodic(interval, (_) => refresh());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
