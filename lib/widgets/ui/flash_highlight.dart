import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 定位后的落点闪烁
class FlashHighlight extends StatefulWidget {
  final Widget child;
  final bool active;

  /// 闪烁次数
  final int pulses;

  /// 单次时长
  final Duration pulseDuration;

  const FlashHighlight({
    super.key,
    required this.child,
    required this.active,
    this.pulses = 3,
    this.pulseDuration = const Duration(milliseconds: 420),
  });

  @override
  State<FlashHighlight> createState() => _FlashHighlightState();
}

class _FlashHighlightState extends State<FlashHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.pulseDuration * widget.pulses,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(FlashHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final baseColor = Theme.of(context).colorScheme.primaryContainer;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 每个脉冲 1 0 的三角波，最后 15% 淡出收尾
        final progress = _controller.value * widget.pulses;
        final phase = progress - progress.floorToDouble();
        final triangular = 1 - (phase * 2 - 1).abs();
        final fadeOut = _controller.value > 0.85
            ? (1 - _controller.value) / 0.15
            : 1.0;
        final alpha = (0.42 * triangular * fadeOut).clamp(0.0, 0.42);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: alpha),
            borderRadius: TFRadius.smRadius,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
