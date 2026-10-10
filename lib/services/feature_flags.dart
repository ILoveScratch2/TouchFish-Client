import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/tf_api_client.dart';
import '../utils/talker.dart';

/// 服务器功能开关的全局只读视图。
///
/// 数据来源为 `/info` 下发的 `features`（TfServerConfig.features），随
/// [TfApiClient.fetchServerInfo] 自动刷新，并缓存到 SharedPreferences，
/// 使离线/启动早期也能拿到上次的开关状态。变更时 [notifyListeners]。
class FeatureFlags extends ChangeNotifier {
  static FeatureFlags? _instance;

  static FeatureFlags get instance {
    _instance ??= FeatureFlags._();
    return _instance!;
  }

  FeatureFlags._();

  static const String _prefsKey = 'cached_feature_flags';

  TfFeatureFlags _flags = const TfFeatureFlags();
  bool _initialized = false;

  TfFeatureFlags get flags => _flags;

  bool get privateChat => _flags.privateChat;
  bool get groupChat => _flags.groupChat;
  bool get groupCreate => _flags.groupCreate;
  bool get friendRequest => _flags.friendRequest;
  bool get forum => _flags.forum;
  bool get sticker => _flags.sticker;
  bool get announcement => _flags.announcement;

  /// 从 SharedPreferences 读取上次缓存（首次进入 app 时调用一次）。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _flags = TfFeatureFlags.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      talker.error('FeatureFlags: load cache failed', e);
    }
  }

  /// 用服务端下发的最新开关覆盖本地并持久化。值未变化时不通知。
  Future<void> apply(TfFeatureFlags next) async {
    if (_flagsEqual(next)) return;
    _flags = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
    } catch (e) {
      talker.error('FeatureFlags: persist failed', e);
    }
  }

  bool _flagsEqual(TfFeatureFlags other) =>
      _flags.privateChat == other.privateChat &&
      _flags.groupChat == other.groupChat &&
      _flags.groupCreate == other.groupCreate &&
      _flags.friendRequest == other.friendRequest &&
      _flags.forum == other.forum &&
      _flags.sticker == other.sticker &&
      _flags.announcement == other.announcement;

  /// 仅供测试：重置为默认并清除缓存状态。
  @visibleForTesting
  void resetForTest() {
    _flags = const TfFeatureFlags();
    _initialized = false;
  }
}
