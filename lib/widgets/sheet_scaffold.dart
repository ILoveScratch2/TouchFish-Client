import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tokens.dart';

/// 底部弹层的统一外壳
class SheetScaffold extends StatelessWidget {
  final Widget? title;
  final String? titleText;
  final List<Widget> actions;
  final Widget child;
  final double heightFactor;
  final double? height;
  final VoidCallback? onClose;

  /// 是否在顶部画拖拽指示条
  /// 弹层本身有 header 时默认不画
  final bool showHandle;

  const SheetScaffold({
    super.key,
    this.title,
    this.titleText,
    required this.child,
    this.actions = const [],
    this.heightFactor = TFSize.sheetHeightFactor,
    this.height,
    this.onClose,
    this.showHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    assert(title != null || titleText != null);

    final theme = Theme.of(context);
    final titleWidget =
        title ??
        Text(
          titleText!,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      // 只让键盘挤占底部，左右不再被 viewInsets 影响
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: height ?? MediaQuery.sizeOf(context).height * heightFactor,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: TFRadius.sheetRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: TFSpace.sm),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: TFAlpha.disabled,
                    ),
                    borderRadius: TFRadius.pillRadius,
                  ),
                ),
              ),
            Padding(
              padding: TFInsets.sheetHeader,
              child: Row(
                children: [
                  // 只在标题行内伸缩；动作区按内容宽度排布
                  Expanded(child: titleWidget),
                  ...actions,
                  IconButton(
                    icon: Icon(
                      Symbols.close,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => onClose != null
                        ? onClose?.call()
                        : Navigator.pop(context),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(
                        TFSize.controlSm,
                        TFSize.controlSm,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: child),
            SizedBox(height: safeBottom > 0 ? TFSpace.sm : 0),
          ],
        ),
      ),
    );
  }
}

/// 统一弹层入口
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useRootNavigator = false,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    isDismissible: dismissible,
    enableDrag: dismissible,
    builder: builder,
  );
}
