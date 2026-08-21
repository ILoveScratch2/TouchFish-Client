import 'package:flutter/material.dart';
// 绝密·启用前！
import '../screens/lock_screen.dart';
import '../services/lock_service.dart';

class LockGate extends StatelessWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LockService.instance,
      builder: (context, _) =>
          LockService.instance.isLocked ? const LockScreen() : child,
    );
  }
}
