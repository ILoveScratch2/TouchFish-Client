import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 空态
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final double? iconSize;

  /// 紧凑变体
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.iconSize,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedIconSize = iconSize ?? (compact ? 28 : 44);
    final gap = compact ? TFSpace.sm : TFSpace.lg;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: TFSpace.xxxl,
            vertical: compact ? TFSpace.lg : TFSpace.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: resolvedIconSize, color: colorScheme.outline),
              SizedBox(height: gap),
              Text(
                title,
                textAlign: TextAlign.center,
                style: (compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: TFSpace.sm),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[
                SizedBox(height: compact ? TFSpace.md : TFSpace.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
