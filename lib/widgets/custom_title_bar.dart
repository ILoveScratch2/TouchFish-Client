import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:window_manager/window_manager.dart';

/// Custom Title Bar by ILoveScratch2
class CustomTitleBar extends StatefulWidget {
  final String title;
  final bool showTitle;
  
  const CustomTitleBar({
    super.key,
    this.title = 'TouchFish Client',
    this.showTitle = true,
  });

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  final ValueNotifier<bool> _isMaximized = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _isMaximized.dispose();
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();
    _isMaximized.value = maximized;
  }

  @override
  void onWindowMaximize() {
    _isMaximized.value = true;
  }

  @override
  void onWindowUnmaximize() {
    _isMaximized.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Platform.isMacOS
          ? _buildMacTitleBar(context)
          : _buildWindowsTitleBar(context),
    );
  }

  /// macOS
  Widget _buildMacTitleBar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const SizedBox(height: 40),
            if (widget.showTitle)
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Windows/Linux
  Widget _buildWindowsTitleBar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 8),
                  if (widget.showTitle)
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
          _buildWindowButton(
            icon: Symbols.minimize,
            onPressed: () => windowManager.minimize(),
            tooltip: '最小化',
          ),
          
          ValueListenableBuilder<bool>(
            valueListenable: _isMaximized,
            builder: (context, isMaximized, _) {
              return _buildWindowButton(
                icon: isMaximized ? Symbols.fullscreen_exit : Symbols.fullscreen,
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.restore();
                  } else {
                    windowManager.maximize();
                  }
                },
                tooltip: isMaximized ? '还原' : '最大化',
              );
            },
          ),
          
          _buildWindowButton(
            icon: Symbols.close,
            onPressed: () => windowManager.close(),
            tooltip: '关闭',
            isClose: true,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool isClose = false,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose 
            ? Colors.red.withOpacity(0.9)
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        child: SizedBox(
          width: 46,
          height: 40,
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
