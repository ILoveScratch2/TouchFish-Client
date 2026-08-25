import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_symbols_icons/symbols.dart';

import 'custom_title_bar.dart';

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
  Widget? content,
  List<TouchFishDialogAction<T>>? actions,
  IconData? icon,
  bool barrierDismissible = true,
}) {
  return _showTouchFishAlertDialog(
    context,
    tone: _TouchFishAlertTone.info,
    title: title,
    message: message,
    content: content,
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
  Widget? content,
  List<TouchFishDialogAction<T>>? actions,
  IconData? icon,
  required bool barrierDismissible,
  bool selectableMessage = false,
}) {
  Widget buildDialog(BuildContext dialogContext) {
    return _buildTouchFishAlertDialog<T>(
      dialogContext,
      tone: tone,
      title: title,
      message: message,
      content: content,
      actions: actions,
      icon: icon,
      selectableMessage: selectableMessage,
    );
  }

  // CustomTitleBar WTF
  if (isDesktopWindowed) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null) {
      final completer = Completer<T?>();
      late final OverlayEntry entry;
      void remove([T? result]) {
        if (entry.mounted) entry.remove();
        if (!completer.isCompleted) completer.complete(result);
      }

      final theme = Theme.of(context);
      entry = OverlayEntry(
        builder: (overlayContext) => _TouchFishDialogOverlay<T>(
          topInset: CustomTitleBar.height,
          barrierDismissible: barrierDismissible,
          barrierColor: theme.dialogTheme.barrierColor ?? Colors.black54,
          onDismiss: remove,
          childBuilder: (dialogContext, onPop) => _buildTouchFishAlertDialog<T>(
            dialogContext,
            tone: tone,
            title: title,
            message: message,
            content: content,
            actions: actions,
            icon: icon,
            selectableMessage: selectableMessage,
            onPop: onPop,
          ),
        ),
      );
      overlay.insert(entry);
      return completer.future;
    }
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => buildDialog(dialogContext),
  );
}

bool get isDesktopWindowed =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

class _TouchFishDialogOverlay<T> extends StatefulWidget {
  final double topInset;
  final bool barrierDismissible;
  final Color barrierColor;

  final void Function(T? result) onDismiss;

  final Widget Function(BuildContext context, void Function(T? result) onPop)
  childBuilder;

  const _TouchFishDialogOverlay({
    required this.topInset,
    required this.barrierDismissible,
    required this.barrierColor,
    required this.onDismiss,
    required this.childBuilder,
  });

  @override
  State<_TouchFishDialogOverlay<T>> createState() =>
      _TouchFishDialogOverlayState<T>();
}

class _TouchFishDialogOverlayState<T> extends State<_TouchFishDialogOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _requestClose([T? result]) {
    if (_closing) return;
    _closing = true;
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onDismiss(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = widget.topInset;
    final opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            widget.barrierDismissible) {
          _requestClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Positioned(
            top: inset,
            left: 0,
            right: 0,
            bottom: 0,
            child: FadeTransition(
              opacity: opacity,
              child: ModalBarrier(
                dismissible: widget.barrierDismissible,
                color: widget.barrierColor,
                onDismiss: () => _requestClose(),
              ),
            ),
          ),
          Positioned(
            top: inset,
            left: 0,
            right: 0,
            bottom: 0,
            child: FadeTransition(
              opacity: opacity,
              child: Center(child: widget.childBuilder(context, _requestClose)),
            ),
          ),
        ],
      ),
    );
  }
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
  void Function(T? result)? onPop,
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
        onPop: onPop,
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
                (selectableMessage ? SelectableText(message!) : Text(message!)),
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
  void Function(T? result)? onPop,
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

  void handle(T? result) {
    if (onPop != null) {
      onPop(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  return [
    for (final action in effectiveActions)
      action.isPrimary
          ? FilledButton(
              onPressed: () => handle(action.result),
              style: action.isDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    )
                  : null,
              child: Text(action.label),
            )
          : TextButton(
              onPressed: () => handle(action.result),
              style: action.isDestructive
                  ? TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    )
                  : null,
              child: Text(action.label),
            ),
  ];
}
