import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'custom_title_bar.dart';

/// Custom Window Frame by ILoveScratch2
class WindowFrame extends StatefulWidget {
  final Widget child;
  final String title;
  
  const WindowFrame({
    super.key,
    required this.child,
    this.title = 'TouchFish Client',
  });

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> 
    with WidgetsBindingObserver, WindowListener {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveWindowSize();
    }
  }

  @override
  void onWindowClose() async {
    await _saveWindowSize();
  }

  @override
  void onWindowResized() async {
    await _saveWindowSize();
  }

  @override
  void onWindowMoved() async {
    await _saveWindowSize();
  }

  Future<void> _saveWindowSize() async {
    try {
      final bounds = await windowManager.getBounds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('window_width', bounds.width);
      await prefs.setDouble('window_height', bounds.height);
      await prefs.setDouble('window_x', bounds.left);
      await prefs.setDouble('window_y', bounds.top);
    } catch (e) {
      debugPrint('windows size save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
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
