import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';

class MessageSwipeableWrapper extends StatefulWidget {
  final String messageId;
  final Widget child;
  final bool isCurrentUser;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onShowMenu;
  final bool enabled;

  const MessageSwipeableWrapper({
    super.key,
    required this.messageId,
    required this.child,
    required this.isCurrentUser,
    this.onReply,
    this.onForward,
    this.onShowMenu,
    this.enabled = true,
  });

  @override
  State<MessageSwipeableWrapper> createState() =>
      _MessageSwipeableWrapperState();
}

class _MessageSwipeableWrapperState extends State<MessageSwipeableWrapper> {
  Widget _buildSwipeHintBackground({
    required bool isStartToEnd,
    required IconData icon,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final alignment = isStartToEnd
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final padding = isStartToEnd
        ? const EdgeInsets.only(left: 20)
        : const EdgeInsets.only(right: 20);

    return Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: alignment,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // 右侧提示时图标贴屏幕边缘、文字在图标内侧
        textDirection: isStartToEnd ? TextDirection.ltr : TextDirection.rtl,
        children: [
          Icon(icon, color: colorScheme.primary, size: 24),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final l10n = AppLocalizations.of(context)!;
    final quickActionLabel = widget.isCurrentUser
        ? l10n.messageSwipeForward
        : l10n.messageSwipeReply;

    return Dismissible(
      key: ValueKey('message-swipe-${widget.messageId}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.35,
      },
      resizeDuration: null,
      movementDuration: const Duration(milliseconds: 120),
      background: _buildSwipeHintBackground(
        isStartToEnd: true,
        icon: Symbols.menu_open,
        label: l10n.messageSwipeMore,
      ),
      secondaryBackground: _buildSwipeHintBackground(
        isStartToEnd: false,
        icon: widget.isCurrentUser ? Symbols.forward : Symbols.reply,
        label: quickActionLabel,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // 左滑显示菜单
          widget.onShowMenu?.call();
        } else if (direction == DismissDirection.endToStart) {
          // 右滑快速操作
          if (widget.isCurrentUser) {
            widget.onForward?.call();
          } else {
            widget.onReply?.call();
          }
        }
        return false; // 显然不是真的要删除
      },
      child: widget.child,
    );
  }
}
