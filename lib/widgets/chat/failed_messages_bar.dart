import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// 未发出消息
class FailedMessagesBar extends StatelessWidget {
  final int count;
  final VoidCallback onRetryAll;

  const FailedMessagesBar({
    super.key,
    required this.count,
    required this.onRetryAll,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        left: TFSpace.lg,
        right: TFSpace.sm,
        top: 2,
        bottom: 2,
      ),
      color: colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: TFSize.iconSm,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: TFSpace.sm),
          Expanded(
            child: Text(
              l10n.failedMessagesCount(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetryAll,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
              minimumSize: const Size(44, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: TFSpace.md),
              textStyle: theme.textTheme.labelMedium,
            ),
            child: Text(l10n.failedMessagesRetryAll),
          ),
        ],
      ),
    );
  }
}
