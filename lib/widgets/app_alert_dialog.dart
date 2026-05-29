import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

const double _kDialogMaxWidth = 480.0;

class TouchFishDialogAction<T> {
  const TouchFishDialogAction({
    required this.label,
    this.result,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final String label;
  final T? result;
  final bool isPrimary;
  final bool isDestructive;
}

enum _TouchFishAlertTone { info, error }

Future<T?> showTouchFishInfoDialog<T>(
  BuildContext context, {
  required String title,
  required String message,
  List<TouchFishDialogAction<T>>? actions,
  IconData? icon,
  bool barrierDismissible = true,
}) {
  return _showTouchFishAlertDialog(
    context,
    tone: _TouchFishAlertTone.info,
    title: title,
    message: message,
    actions: actions,
    icon: icon,
    barrierDismissible: barrierDismissible,
  );
}

Future<T?> showTouchFishErrorDialog<T>(
  BuildContext context, {
  required String title,
  required String message,
  List<TouchFishDialogAction<T>>? actions,
  IconData? icon,
  bool barrierDismissible = true,
}) {
  return _showTouchFishAlertDialog(
    context,
    tone: _TouchFishAlertTone.error,
    title: title,
    message: message,
    actions: actions,
    icon: icon,
    barrierDismissible: barrierDismissible,
  );
}

Future<T?> _showTouchFishAlertDialog<T>(
  BuildContext context, {
  required _TouchFishAlertTone tone,
  required String title,
  required String message,
  List<TouchFishDialogAction<T>>? actions,
  IconData? icon,
  required bool barrierDismissible,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final accentColor = tone == _TouchFishAlertTone.error
          ? theme.colorScheme.error
          : theme.colorScheme.primary;
      final effectiveActions = actions == null || actions.isEmpty
          ? <TouchFishDialogAction<T>>[
              TouchFishDialogAction<T>(
                label: MaterialLocalizations.of(dialogContext).okButtonLabel,
                isPrimary: true,
              ),
            ]
          : actions;

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kDialogMaxWidth),
        child: AlertDialog(
          title: null,
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon ??
                      (tone == _TouchFishAlertTone.error
                          ? Icons.error_outline_rounded
                          : Symbols.info_rounded),
                  size: 48,
                  color: accentColor,
                ),
                const SizedBox(height: 16),
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                tone == _TouchFishAlertTone.error
                    ? SelectableText(message)
                    : Text(message),
                const SizedBox(height: 8),
              ],
            ),
          ),
          actions: [
            for (final action in effectiveActions)
              action.isPrimary
                  ? FilledButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(action.result);
                      },
                      child: Text(action.label),
                    )
                  : TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(action.result);
                      },
                      style: action.isDestructive
                          ? TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            )
                          : null,
                      child: Text(action.label),
                    ),
          ],
        ),
      );
    },
  );
}
