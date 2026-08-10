import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'custom_title_bar.dart';
import '../constants/app_constants.dart';

/// Custom Window Frame by ILoveScratch2
class WindowFrame extends StatefulWidget {
  final Widget child;
  final String title;

  const WindowFrame({
    super.key,
    required this.child,
    this.title = AppConstants.appName,
  });

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> {
  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (!isDesktop) {
      return widget.child;
    }

    return Column(
      children: [
        CustomTitleBar(title: widget.title),
        Expanded(child: widget.child),
      ],
    );
  }
}
