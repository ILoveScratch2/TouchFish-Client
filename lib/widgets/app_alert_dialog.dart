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
  String? title,
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

Widget buildTouchFishInfoDialog(
  BuildContext context, {
  String? title,
  String? message,
  Widget? content,
  List<Widget>? actionWidgets,
  IconData? icon,
  bool selectableMessage = false,
  bool addDefaultActionWhenEmpty = true,
}) {
  return _buildTouchFishAlertDialog<void>(
    context,
    tone: _TouchFishAlertTone.info,
    title: title,
    message: message,
    content: content,
    actionWidgets: actionWidgets,
    icon: icon,
    selectableMessage: selectableMessage,
    addDefaultActionWhenEmpty: addDefaultActionWhenEmpty,
  );
}

Future<T?> showTouchFishErrorDialog<T>(
  BuildContext context, {
  String? title,
  required String message,
  List<TouchFishDialogAction<T>>? actions,
  IconData? icon,
  bool barrierDismissible = true,
  bool selectableMessage = true,
}) {
  return _showTouchFishAlertDialog(
    context,
    tone: _TouchFishAlertTone.error,
    title: title,
    message: message,
    actions: actions,
    icon: icon,
    barrierDismissible: barrierDismissible,
    selectableMessage: selectableMessage,
  );
}

Widget buildTouchFishErrorDialog(
  BuildContext context, {
  String? title,
  String? message,
  Widget? content,
  List<Widget>? actionWidgets,
  IconData? icon,
  bool selectableMessage = false,
  bool addDefaultActionWhenEmpty = true,
}) {
  return _buildTouchFishAlertDialog<void>(
    context,
    tone: _TouchFishAlertTone.error,
    title: title,
    message: message,
    content: content,
    actionWidgets: actionWidgets,
    icon: icon,
    selectableMessage: selectableMessage,
    addDefaultActionWhenEmpty: addDefaultActionWhenEmpty,
  );
}

Future<T?> _showTouchFishAlertDialog<T>(
  BuildContext context, {
  required _TouchFishAlertTone tone,
  String? title,
  required String message,
  List<TouchFishDialogAction<T>>? actions,
  IconData? icon,
  required bool barrierDismissible,
  bool selectableMessage = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      return _buildTouchFishAlertDialog<T>(
        dialogContext,
        tone: tone,
        title: title,
        message: message,
        actions: actions,
        icon: icon,
        selectableMessage: selectableMessage,
      );
    },
  );
}

Widget _buildTouchFishAlertDialog<T>(
  BuildContext context, {
  required _TouchFishAlertTone tone,
  String? title,
  String? message,
  Widget? content,
  List<TouchFishDialogAction<T>>? actions,
  List<Widget>? actionWidgets,
  IconData? icon,
  bool selectableMessage = false,
  bool addDefaultActionWhenEmpty = true,
}) {
  assert(message != null || content != null);

  final theme = Theme.of(context);
  final accentColor = tone == _TouchFishAlertTone.error
      ? theme.colorScheme.error
      : theme.colorScheme.primary;
  final resolvedActionWidgets =
      actionWidgets ??
      _buildDialogActionWidgets(
        context,
        actions: actions,
        addDefaultActionWhenEmpty: addDefaultActionWhenEmpty,
      );

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
            if (title != null && title.isNotEmpty) ...[
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
            ],
            content ??
                (selectableMessage
                    ? SelectableText(message!)
                    : Text(message!)),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: resolvedActionWidgets,
    ),
  );
}

List<Widget> _buildDialogActionWidgets<T>(
  BuildContext context, {
  List<TouchFishDialogAction<T>>? actions,
  required bool addDefaultActionWhenEmpty,
}) {
  final theme = Theme.of(context);
  final effectiveActions = actions == null || actions.isEmpty
      ? (addDefaultActionWhenEmpty
          ? <TouchFishDialogAction<T>>[
              TouchFishDialogAction<T>(
                label: MaterialLocalizations.of(context).okButtonLabel,
                isPrimary: true,
              ),
            ]
          : <TouchFishDialogAction<T>>[])
      : actions;

  return [
    for (final action in effectiveActions)
      action.isPrimary
          ? FilledButton(
              onPressed: () {
                Navigator.of(context).pop(action.result);
              },
              style: action.isDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    )
                  : null,
              child: Text(action.label),
            )
          : TextButton(
              onPressed: () {
                Navigator.of(context).pop(action.result);
              },
              style: action.isDestructive
                  ? TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    )
                  : null,
              child: Text(action.label),
            ),
  ];
}
