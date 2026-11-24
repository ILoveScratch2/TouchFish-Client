import 'package:flutter/material.dart';

import '../../utils/wide_screen_helper.dart';

/// 详情/辅助面板
class ResponsiveSidebar {
  /// 宽屏面板默认宽度。
  static const double defaultWidth = 360;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext context, void Function([T? result]) close)
        builder,
    double width = defaultWidth,
    bool useRootNavigator = true,
    Color? barrierColor,
    String? barrierLabel,
  }) {
    final isWide = WideScreenHelper.isWide(context);
    final resolvedBarrier =
        barrierColor ?? Colors.black.withValues(alpha: 0.32);

    if (!isWide) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: useRootNavigator,
        showDragHandle: true,
        builder: (ctx) => _SheetHost<T>(builder: builder),
      );
    }

    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: true,
      barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: resolvedBarrier,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width,
                maxHeight: MediaQuery.sizeOf(ctx).height - 24,
              ),
              child: _PanelHost<T>(builder: builder),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
/// 宽屏面板
class _PanelHost<T> extends StatelessWidget {
  final Widget Function(BuildContext context, void Function([T? result]) close)
      builder;

  const _PanelHost({required this.builder});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: builder(context, ([T? result]) => Navigator.of(context).pop(result)),
    );
  }
}

/// 窄屏 bottom sheet
class _SheetHost<T> extends StatelessWidget {
  final Widget Function(BuildContext context, void Function([T? result]) close)
      builder;

  const _SheetHost({required this.builder});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: builder(context, ([T? result]) => Navigator.of(context).pop(result)),
    );
  }
}
