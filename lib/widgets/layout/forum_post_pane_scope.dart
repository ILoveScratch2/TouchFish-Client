import 'package:flutter/material.dart';

/// 分屏里「帖子详情整屏 / 恢复分栏」的开关下传。
///
/// 论坛外壳在渲染当前帖子时包一层，帖子详情页据此在右上角显示整屏按钮；
/// 这是**当前这一次查看**的临时状态——换帖子、退出帖子即恢复分屏（不持久化）。
class ForumPostPaneScope extends InheritedWidget {
  /// 当前帖子是否整屏显示。
  final bool fullScreen;

  /// 切换整屏 / 分栏。
  final VoidCallback toggleFullScreen;

  const ForumPostPaneScope({
    super.key,
    required this.fullScreen,
    required this.toggleFullScreen,
    required super.child,
  });

  /// 不在论坛分屏里（例如整屏 push 打开的帖子）时为 null，此时不显示按钮。
  static ForumPostPaneScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ForumPostPaneScope>();

  @override
  bool updateShouldNotify(ForumPostPaneScope oldWidget) =>
      fullScreen != oldWidget.fullScreen;
}
