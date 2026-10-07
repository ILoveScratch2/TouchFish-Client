import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';

/// 多选模式底部操作栏
class RoomSelectionMode extends StatelessWidget {
  final bool visible;
  final int selectedCount;
  final VoidCallback onClose;
  final VoidCallback onCopy;
  final VoidCallback onRedirect;
  final VoidCallback onRedirectToCurrentChat;

  const RoomSelectionMode({
    super.key,
    required this.visible,
    required this.selectedCount,
    required this.onClose,
    required this.onCopy,
    required this.onRedirect,
    required this.onRedirectToCurrentChat,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasSelection = selectedCount > 0;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      elevation: 6,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 400;

                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasSelection
                              ? l10n.selectionCount(selectedCount)
                              : l10n.selectionSelectMessages,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            color: hasSelection
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SelectionActionButton(
                        icon: Symbols.content_copy,
                        label: l10n.selectionCopy,
                        enabled: hasSelection,
                        onPressed: onCopy,
                        filled: false,
                        compact: compact,
                      ),
                      const SizedBox(width: 8),
                      _SelectionActionButton(
                        icon: Symbols.send,
                        label: l10n.selectionMergeForward,
                        enabled: hasSelection,
                        onPressed: onRedirect,
                        filled: false,
                        compact: compact,
                      ),
                      const SizedBox(width: 8),
                      _SelectionActionButton(
                        icon: Symbols.login,
                        label: l10n.selectionRedirectToCurrentChat,
                        enabled: hasSelection,
                        onPressed: onRedirectToCurrentChat,
                        filled: true,
                        compact: compact,
                      ),
                      const SizedBox(width: 8),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool filled;
  final bool compact;
  final VoidCallback onPressed;

  const _SelectionActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.filled,
    required this.compact,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final style = FilledButton.styleFrom(
      backgroundColor: filled ? null : colorScheme.secondaryContainer,
      foregroundColor: filled ? null : colorScheme.onSecondaryContainer,
      disabledBackgroundColor: colorScheme.surfaceContainerHighest,
      disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: 10,
      ),
      minimumSize: Size(compact ? 40 : 0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );

    if (compact) {
      return Tooltip(
        message: label,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: style,
          child: Icon(icon, size: 18),
        ),
      );
    }

    return Tooltip(
      message: label,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: style,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }
}
