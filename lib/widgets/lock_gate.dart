import 'package:flutter/material.dart';

// 绝密·启用前！
import '../screens/lock_screen.dart';
import '../services/lock_service.dart';
import '../theme/tokens.dart';

/// 应用锁门控：锁定时用锁屏覆盖 [child]。
class LockGate extends StatelessWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LockService.instance,
      builder: (context, _) {
        final locked = LockService.instance.isLocked;
        return AnimatedSwitcher(
          // 上锁必须瞬时完成
          duration: locked ? Duration.zero : TFMotion.fast,
          switchInCurve: TFMotion.decelerate,
          switchOutCurve: TFMotion.accelerate,
          // 淡出时把旧子树叠在新子树下面
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [...previousChildren, ?currentChild],
          ),
          child: locked
              ? const LockScreen(key: ValueKey('lock-screen'))
              : KeyedSubtree(key: const ValueKey('lock-content'), child: child),
        );
      },
    );
  }
}
