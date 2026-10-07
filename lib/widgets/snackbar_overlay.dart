import 'dart:async';
import 'package:flutter/material.dart';
import '../services/snackbar_service.dart';

class TouchFishSnackbarOverlay extends StatefulWidget {
  final Widget child;
  const TouchFishSnackbarOverlay({super.key, required this.child});

  @override
  State<TouchFishSnackbarOverlay> createState() => _TouchFishSnackbarOverlayState();
}

class _TouchFishSnackbarOverlayState extends State<TouchFishSnackbarOverlay> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  ({Color background, Color foreground, IconData? icon}) _styleFor(
    SnackbarType type,
    ColorScheme colorScheme,
  ) {
    switch (type) {
      case SnackbarType.success:
        return (
          background: colorScheme.primary,
          foreground: colorScheme.onPrimary,
          icon: Icons.check_circle_outline,
        );
      case SnackbarType.error:
        return (
          background: colorScheme.error,
          foreground: colorScheme.onError,
          icon: Icons.error_outline,
        );
      case SnackbarType.warning:
        return (
          background: colorScheme.tertiary,
          foreground: colorScheme.onTertiary,
          icon: Icons.warning_amber_outlined,
        );
      case SnackbarType.info:
        return (
          background: colorScheme.inverseSurface,
          foreground: colorScheme.onInverseSurface,
          icon: null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TouchFishSnackbarService.instance,
      builder: (context, _) {
        final message = TouchFishSnackbarService.instance.message;
        if (message != null) {
          _timer?.cancel();
          _timer = Timer(const Duration(seconds: 3), TouchFishSnackbarService.instance.clear);
        }
        final style = _styleFor(
          TouchFishSnackbarService.instance.type,
          Theme.of(context).colorScheme,
        );
        return Stack(
          children: [
            widget.child,
            if (message != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 180),
                    child: Center(
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        color: style.background,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (style.icon != null) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    style.icon,
                                    size: 18,
                                    color: style.foreground,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  message,
                                  style: TextStyle(color: style.foreground),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
