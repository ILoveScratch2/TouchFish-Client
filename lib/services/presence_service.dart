import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'auth_state.dart';
import 'chat_ws_service.dart';
import 'feature_flags.dart';

/// 好友在线状态缓存
class PresenceService extends ChangeNotifier {
  PresenceService._();

  static PresenceService? _instance;
  static PresenceService get instance => _instance ??= PresenceService._();

  /// 兜底全量刷新间隔
  static const Duration _pollInterval = Duration(minutes: 5);
  static const Duration _minRefreshGap = Duration(seconds: 2);

  /// uid -> 在线
  final Map<int, bool> _online = {};

  /// uid -> 最近一次已应用状态
  final Map<int, int> _stateTs = {};

  StreamSubscription<ChatWsEvent>? _sub;
  Timer? _pollTimer;
  bool _wsListenerAttached = false;
  ChatWsState? _lastWsState;
  DateTime? _lastRefreshAt;

  bool get enabled => FeatureFlags.instance.presence;

  bool isOnline(int uid) => _online[uid] ?? false;

  /// 是否已知该 uid 的状态
  bool isKnown(int uid) => _online.containsKey(uid);

  /// 订阅 WS 事件与连接状态
  void start() {
    _sub ??= ChatWsService.instance.eventStream.listen(_onEvent);
    if (!_wsListenerAttached) {
      _wsListenerAttached = true;
      ChatWsService.instance.addListener(_onWsStateChanged);
      _lastWsState = ChatWsService.instance.state;
    }
    if (ChatWsService.instance.isAuthenticated) {
      _startPolling();
      unawaited(refreshFriends());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    if (_wsListenerAttached) {
      ChatWsService.instance.removeListener(_onWsStateChanged);
      _wsListenerAttached = false;
    }
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      if (!ChatWsService.instance.isAuthenticated) return;
      unawaited(refreshFriends());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// WS 重新认证后补拉
  void _onWsStateChanged() {
    final state = ChatWsService.instance.state;
    final previous = _lastWsState;
    _lastWsState = state;
    if (state != ChatWsState.authenticated) {
      _stopPolling();
      return;
    }
    _startPolling();
    if (previous == ChatWsState.authenticated) return;
    unawaited(refreshFriends());
  }

  void _onEvent(ChatWsEvent event) {
    if (event.type != 'presence.update') return;
    final data = event.notification;
    if (data == null) return;
    final uid = (data['uid'] as num?)?.toInt();
    final status = data['status'];
    if (uid == null || status is! String) return;
    debugApplyPush(uid, status, ts: (data['ts'] as num?)?.toInt());
  }

  @visibleForTesting
  void debugApplyPush(int uid, String status, {int? ts}) {
    switch (status) {
      case 'online':
        _set(uid, true, ts);
      case 'offline':
        _set(uid, false, ts);
      case 'hidden':
        _remove(uid, ts);
      default:
        break;
    }
  }

  bool _acceptTs(int uid, int? ts) {
    if (ts == null) return true;
    final previous = _stateTs[uid];
    if (previous != null && ts < previous) return false;
    _stateTs[uid] = ts;
    return true;
  }

  void _set(int uid, bool online, [int? ts]) {
    if (!_acceptTs(uid, ts)) return;
    if (_online[uid] == online) return;
    _online[uid] = online;
    notifyListeners();
  }

  void _remove(int uid, [int? ts]) {
    if (!_acceptTs(uid, ts)) return;
    if (_online.remove(uid) != null) notifyListeners();
  }

  /// 批量拉取好友在线状态
  /// uids 缺省=全部好友。
  Future<void> refreshFriends({List<int>? uids, bool force = false}) async {
    if (!enabled) return;
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    final unscoped = uids == null;
    if (!force && unscoped) {
      final now = DateTime.now();
      final last = _lastRefreshAt;
      if (last != null && now.difference(last) < _minRefreshGap) return;
      _lastRefreshAt = now;
    }
    try {
      final result = await TfApiClient.instance.queryFriendPresence(
        uid,
        AuthState.instance.password,
        uids: uids,
      );
      if (result == null) return;
      applyPresenceSnapshot(result.presence, scope: uids, ts: result.ts);
    } catch (e) {
      talker.error('PresenceService.refreshFriends failed', e);
    }
  }

  /// 应用一次批量查询结果
  @visibleForTesting
  void applyPresenceSnapshot(
    Map<int, String> result, {
    List<int>? scope,
    int? ts,
  }) {
    var changed = false;
    result.forEach((id, status) {
      if (!_acceptTs(id, ts)) return;
      final online = status == 'online';
      if (_online[id] != online) {
        _online[id] = online;
        changed = true;
      }
    });
    for (final id in scope ?? _online.keys.toList()) {
      if (result.containsKey(id)) continue;
      if (!_acceptTs(id, ts)) continue;
      if (_online.remove(id) != null) changed = true;
    }
    if (changed) notifyListeners();
  }

  /// 清空缓存（登出时调用）。
  void clear() {
    _stopPolling();
    _stateTs.clear();
    _lastRefreshAt = null;
    if (_online.isEmpty) return;
    _online.clear();
    notifyListeners();
  }

  @visibleForTesting
  void debugSet(int uid, bool? online) {
    if (online == null) {
      _remove(uid);
    } else {
      _set(uid, online);
    }
  }
}
