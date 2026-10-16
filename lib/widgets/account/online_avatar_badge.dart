import 'package:flutter/material.dart';

import '../../services/presence_service.dart';

/// 在线角标的圆点 Key
const Key onlineBadgeDotKey = Key('online-badge-dot');

/// 头像右下角的在线状态角标。
///
/// 全局 `presence` 开关开启且该 uid 已在线时，在 [child] 右下角叠一个绿点；
/// 离线 / 未知 / 功能关闭时原样返回 [child]（不占用任何视觉空间）。
class OnlineAvatarBadge extends StatelessWidget {
  /// 对方 uid；null（如群聊）时永不显示角标。
  final int? uid;
  final double radius;
  final Widget child;

  const OnlineAvatarBadge({
    super.key,
    required this.uid,
    required this.child,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final id = uid;
    return ListenableBuilder(
      listenable: PresenceService.instance,
      builder: (context, _) {
        final presence = PresenceService.instance;
        final show = id != null && presence.enabled && presence.isOnline(id);
        if (!show) return child;

        final dot = radius * 0.4;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                key: onlineBadgeDotKey,
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: dot * 0.2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
