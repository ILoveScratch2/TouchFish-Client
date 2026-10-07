import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/talker.dart';

/// 应用是否处于"用户正看着"的前台状态。
class AppForegroundService extends ChangeNotifier
    with WidgetsBindingObserver, WindowListener {
  static final AppForegroundService instance = AppForegroundService._();

  AppForegroundService._();

  bool _isForeground = true;
  bool get isForeground => _isForeground;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    if (_isDesktop) {
      windowManager.addListener(this);
      try {
        final focused = await windowManager.isFocused();
        final visible = await windowManager.isVisible();
        _update(focused && visible);
      } catch (error) {
        talker.warning('Failed to read initial window focus state: $error');
      }
    }
  }

  /// 窗口被显式显示/隐藏（托盘菜单）时同步状态。
  ///
  void setWindowVisible(bool visible) => _update(visible);

  void _update(bool value) {
    if (_isForeground == value) return;
    _isForeground = value;
    notifyListeners();
  }

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDesktop) return;
    _update(state == AppLifecycleState.resumed);
  }

  @override
  void onWindowFocus() => _update(true);

  @override
  void onWindowBlur() => _update(false);
}
