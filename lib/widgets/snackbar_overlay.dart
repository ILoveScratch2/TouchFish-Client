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
                        color: Theme.of(context).colorScheme.inverseSurface,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface)),
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
