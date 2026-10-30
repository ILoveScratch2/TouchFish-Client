import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 标签 - 值 的键值行
class InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selectable;

  const InfoRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.padding = const EdgeInsets.symmetric(
      horizontal: TFSpace.lg,
      vertical: TFSpace.md,
    ),
    this.onTap,
    this.selectable = false,
  }) : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final labelWidget = Text(
      label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );

    final effectiveValue = valueWidget ??
        (selectable
            ? SelectableText(
                value ?? '',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium,
              )
            : Text(
                value ?? '',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium,
              ));

    final content = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: labelWidget),
          const SizedBox(width: TFSpace.md),
          Expanded(flex: 3, child: Align(
            alignment: Alignment.centerRight,
            child: effectiveValue,
          )),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// 带左侧状态轨的卡片
class TrustRailCard extends StatelessWidget {
  final Widget child;
  final TrustLevel level;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TrustRailCard({
    super.key,
    required this.child,
    this.level = TrustLevel.normal,
    this.padding = const EdgeInsets.all(TFSpace.card),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final railColor = switch (level) {
      TrustLevel.normal => colorScheme.primary,
      TrustLevel.caution => colorScheme.tertiary,
      TrustLevel.danger => colorScheme.error,
    };

    final body = Padding(padding: padding, child: child);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: railColor),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

enum TrustLevel { normal, caution, danger }
