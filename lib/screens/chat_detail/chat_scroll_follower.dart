import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/tokens.dart';

/// 聊天消息列表跟随底部

class ChatScrollFollower {
  ChatScrollFollower({this.isActive});
  final bool Function()? isActive;
  ScrollController? _controller;
  bool _following = true;
  bool _autoScrolling = false;
  int _token = 0;

  bool get isFollowing => _following;

  bool get isAutoScrolling => _autoScrolling;

  bool get _alive => (isActive?.call() ?? true) && (_controller?.hasClients ?? false);

  void attach(ScrollController controller) {
    _controller = controller;
    reset();
  }

  void reset() {
    _following = true;
    _autoScrolling = false;
    _token++;
  }

  bool get isAtBottom {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return true;
    final position = controller.position;
    return position.pixels <= position.minScrollExtent + 1;
  }

  bool get isNearBottom {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return true;
    final position = controller.position;
    return position.pixels <= position.minScrollExtent + 100;
  }

  bool get shouldFollowContentChange =>
      _following && !_autoScrolling && isNearBottom;

  void stopFollowing() {
    _following = false;
    _autoScrolling = false;
    _token++;
  }

  void notePosition() {
    if (_autoScrolling) return;
    if (isAtBottom) _following = true;
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle) return false;
      stopFollowing();
      return true;
    }
    if (notification is ScrollUpdateNotification) {
      // dragDetails 只覆盖拖动/惯性
      // 鼠标滚轮与触控板滚动没有 dragDetails
      final delta = notification.scrollDelta ?? 0;
      if (notification.dragDetails != null || delta > 0) {
        stopFollowing();
        return true;
      }
      return false;
    }
    if (notification is ScrollEndNotification) {
      // 自动回底自己 End 通知不算用户操作
      if (!_autoScrolling && isAtBottom) _following = true;
      return false;
    }
    return false;
  }

  /// 回到底部
  void scrollToBottom({bool animated = true}) {
    _following = true;
    final token = ++_token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (token != _token || !_alive) return;
      final controller = _controller!;
      final position = controller.position;
      if (position.pixels <= position.minScrollExtent + 0.5) return;
      _autoScrolling = true;
      if (!animated) {
        controller.jumpTo(position.minScrollExtent);
        _autoScrolling = false;
        return;
      }
      unawaited(
        controller
            .animateTo(
              position.minScrollExtent,
              duration: TFMotion.slow,
              curve: TFMotion.decelerate,
            )
            .whenComplete(() {
              if (token == _token) _autoScrolling = false;
            }),
      );
    });
  }
}
