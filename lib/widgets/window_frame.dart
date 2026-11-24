import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'custom_title_bar.dart';
import '../constants/app_constants.dart';

/// Custom Window Frame by ILoveScratch2
class WindowFrame extends StatelessWidget {
  final Widget child;
  final String title;

  const WindowFrame({
    super.key,
    required this.child,
    this.title = AppConstants.appName,
  });

  /// 桌面端（有自绘标题栏）
  static bool get isDesktopWindowed =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindowed) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: CustomTitleBar.height),
          child: child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: CustomTitleBar.height,
          child: CustomTitleBar(title: title),
        ),
      ],
    );
  }
}
