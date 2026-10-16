import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'auth_state.dart';
import 'chat_ws_service.dart';
import 'feature_flags.dart';

/// 好友在线状态缓存。
class PresenceService extends ChangeNotifier {
  PresenceService._();

  static PresenceService? _instance;
  static PresenceService get instance => _instance ??= PresenceService._();

  /// uid -> 在线
  final Map<int, bool> _online = {};
  StreamSubscription<ChatWsEvent>? _sub;

  bool get enabled => FeatureFlags.instance.presence;

  bool isOnline(int uid) => _online[uid] ?? false;

  /// 是否已知该 uid 的状态（offline 也返回 true；unknown 返回 false）。
  bool isKnown(int uid) => _online.containsKey(uid);

  /// 订阅 WS 事件（幂等，可在连接前调用）。
  void start() {
    _sub ??= ChatWsService.instance.eventStream.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  void _onEvent(ChatWsEvent event) {
    if (event.type != 'presence.update') return;
    final data = event.notification;
    if (data == null) return;
    final uid = (data['uid'] as num?)?.toInt();
    final status = data['status'];
    if (uid == null || status is! String) return;
    switch (status) {
      case 'online':
        _set(uid, true);
      case 'offline':
        _set(uid, false);
      case 'hidden':
        _remove(uid);
      default:
        break;
    }
  }

  void _set(int uid, bool online) {
    if (_online[uid] == online) return;
    _online[uid] = online;
    notifyListeners();
  }

  void _remove(int uid) {
    if (_online.remove(uid) != null) notifyListeners();
  }

  /// 批量拉取好友在线状态（打开界面时调用）。uids 缺省=全部好友。
  Future<void> refreshFriends({List<int>? uids}) async {
    if (!enabled) return;
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    try {
      final result = await TfApiClient.instance.queryFriendPresence(
        uid,
        AuthState.instance.password,
        uids: uids,
      );
      if (result == null) return;
      applyPresenceSnapshot(result, scope: uids);
    } catch (e) {
      talker.error('PresenceService.refreshFriends failed', e);
    }
  }

  /// 应用一次批量查询结果。响应里出现的 uid 用服务端状态覆盖；
  /// 被服务端整条省略的 uid（关闭了在线状态展示，或已不是好友）置回「未知」，
  /// 否则旧的绿点会一直残留 —— `hidden` 推送只发给变更时刻在线的好友。
  /// [scope] 为请求的 uids 子集时只对该子集对账（缺省=全部好友）。
  @visibleForTesting
  void applyPresenceSnapshot(Map<int, String> result, {List<int>? scope}) {
    var changed = false;
    result.forEach((id, status) {
      final online = status == 'online';
      if (_online[id] != online) {
        _online[id] = online;
        changed = true;
      }
    });
    for (final id in scope ?? _online.keys.toList()) {
      if (result.containsKey(id)) continue;
      if (_online.remove(id) != null) changed = true;
    }
    if (changed) notifyListeners();
  }

  /// 清空缓存（登出时调用）。
  void clear() {
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
