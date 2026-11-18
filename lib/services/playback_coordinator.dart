import 'dart:async';

import 'package:flutter/widgets.dart';

/// 全局播放协调
class PlaybackCoordinator {
  PlaybackCoordinator._();

  static final PlaybackCoordinator instance = PlaybackCoordinator._();

  Object? _owner;
  Future<void> Function()? _pauseOwner;

  /// 声明自己成为当前唯一发声的播放器
  void claim(Object owner, Future<void> Function() pause) {
    if (identical(_owner, owner)) return;
    final previous = _pauseOwner;
    _owner = owner;
    _pauseOwner = pause;
    if (previous != null) unawaited(previous());
  }

  /// 释放所有权
  void release(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _pauseOwner = null;
  }
}

/// 全局路由观察
final RouteObserver<Route<dynamic>> appRouteObserver =
    RouteObserver<Route<dynamic>>();
