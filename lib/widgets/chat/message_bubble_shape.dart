import 'package:flutter/widgets.dart';

import '../../theme/tokens.dart';

/// 消息气泡的圆角语义值对象
/// 
@immutable
class MessageBubbleShape {
  /// 气泡圆角半径。
  final double radius;

  /// 是否为本人发出的消息
  /// 目前不影响渲染
  final bool isOutgoing;

  const MessageBubbleShape({required this.radius, this.isOutgoing = false});

  /// 正文气泡
  const MessageBubbleShape.standard({this.isOutgoing = false})
    : radius = TFRadius.md;

  /// 气泡上方的悬浮操作条（略大于气泡
  const MessageBubbleShape.hoverBar()
    : radius = TFRadius.lg,
      isOutgoing = false;

  /// 内嵌卡片：图片/文件/引用等
  const MessageBubbleShape.embedded()
    : radius = TFRadius.sm,
      isOutgoing = false;

  /// 四角等半径
  BorderRadius get borderRadius => BorderRadius.circular(radius);

  /// 将来做连续消息合并
  /// 现在用不着
  BorderRadius withGroupedCorners({required bool groupAbove, required bool groupBelow}) {
    const zero = Radius.zero;
    final normal = Radius.circular(radius);
    // 同一发送者一侧
    return isOutgoing
        ? BorderRadius.only(
            topLeft: normal,
            bottomLeft: normal,
            topRight: groupAbove ? zero : normal,
            bottomRight: groupBelow ? zero : normal,
          )
        : BorderRadius.only(
            topRight: normal,
            bottomRight: normal,
            topLeft: groupAbove ? zero : normal,
            bottomLeft: groupBelow ? zero : normal,
          );
  }

  @override
  bool operator ==(Object other) =>
      other is MessageBubbleShape &&
      other.radius == radius &&
      other.isOutgoing == isOutgoing;

  @override
  int get hashCode => Object.hash(radius, isOutgoing);
}
