import 'package:flutter/material.dart';
import '../services/snackbar_service.dart';

class TouchFishSnackbarOverlay extends StatelessWidget {
  final Widget child;
  const TouchFishSnackbarOverlay({super.key, required this.child});

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
        final style = _styleFor(
          TouchFishSnackbarService.instance.type,
          Theme.of(context).colorScheme,
        );
        return Stack(
          children: [
            child,
            if (message != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    builder: (context, opacity, child) =>
                        Opacity(opacity: opacity, child: child),
                    child: Center(
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        color: style.background,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
