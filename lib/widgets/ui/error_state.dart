import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 统一错误态
class ErrorState extends StatelessWidget {
  final String title;
  final String? description;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const ErrorState({
    super.key,
    required this.title,
    this.description,
    this.onRetry,
    this.retryLabel = '重试',
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TFSpace.xxxl,
          vertical: TFSpace.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colorScheme.outline),
            const SizedBox(height: TFSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
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
            if (onRetry != null) ...[
              const SizedBox(height: TFSpace.xl),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: TFSize.iconSm),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
