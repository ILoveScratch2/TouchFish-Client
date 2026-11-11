import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_model.dart';
import '../utils/talker.dart';

/// 通知本地缓存
class NotificationLocalStore {
  static NotificationLocalStore? _instance;
  static NotificationLocalStore get instance =>
      _instance ??= NotificationLocalStore._();
  NotificationLocalStore._();

  /// 最多缓存条数
  static const int maxCached = 300;

  static const String _prefix = 'touchfish_notification_cache/';

  String _key(String baseUrl, int uid) {
    final uri = Uri.tryParse(baseUrl);
    final scope = uri == null
        ? baseUrl
        : '${uri.scheme}://${uri.host}:${uri.port}';
    return '$_prefix$scope/$uid';
  }

  Future<List<NotificationInfo>> load(String baseUrl, int uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(baseUrl, uid));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = <NotificationInfo>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        // 没有事件类型的条目不是通知
        final event = map['event'];
        if (event is! String || event.isEmpty) continue;
        try {
          items.add(NotificationInfo.fromLocalJson(map));
        } catch (_) {
          // 单条损坏跳过
        }
      }
      return items;
    } catch (error) {
      talker.warning('NotificationLocalStore.load failed: $error');
      return const [];
    }
  }

  Future<void> save(
    String baseUrl,
    int uid,
    List<NotificationInfo> notifications,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = notifications
          .take(maxCached)
          .map((n) => n.toJson())
          .toList(growable: false);
      await prefs.setString(_key(baseUrl, uid), jsonEncode(payload));
    } catch (error) {
      talker.warning('NotificationLocalStore.save failed: $error');
    }
  }

  Future<void> remove(String baseUrl, int uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(baseUrl, uid));
    } catch (error) {
      talker.warning('NotificationLocalStore.remove failed: $error');
    }
  }
}
