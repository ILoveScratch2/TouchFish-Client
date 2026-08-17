import 'package:flutter/material.dart';

/// maybe wyf need this!
class SyncIndicator extends StatefulWidget {
  final bool isSyncing;
  final String? hint;

  const SyncIndicator({super.key, required this.isSyncing, this.hint});

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    if (widget.isSyncing) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant SyncIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSyncing != widget.isSyncing) {
      if (widget.isSyncing) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.isSyncing;
    final showHint =
        widget.isSyncing && widget.hint != null && widget.hint!.isNotEmpty;

    if (!isLoading && _controller.isDismissed) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.2,
    );

    // 仅提示行（不显示自己的进度条，页面只有一个 loading 进度条）一起滑入/淡出。
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: ColoredBox(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: showHint
                    ? Padding(
                        key: ValueKey(widget.hint),
                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 6),
                        child: Text(
                          widget.hint!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('sync-hint-hidden'),
                        width: double.infinity,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
