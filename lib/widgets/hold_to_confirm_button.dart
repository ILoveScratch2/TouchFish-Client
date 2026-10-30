import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// 长按确认按钮（危险操作用）
class HoldToConfirmButton extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;

  /// 长按时长，默认 1.5s
  final Duration holdDuration;

  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  double _progress = 0;

  static const int _ticks = 30;

  void _start() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    var tick = 0;
    final interval = Duration(
      microseconds: widget.holdDuration.inMicroseconds ~/ _ticks,
    );
    _timer = Timer.periodic(interval, (_) {
      tick++;
      if (!mounted) return;
      setState(() => _progress = (tick / _ticks).clamp(0, 1));
      if (tick >= _ticks) {
        _timer?.cancel();
        HapticFeedback.heavyImpact();
        widget.onConfirmed();
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    if (mounted) setState(() => _progress = 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final errorColor = colorScheme.error;

    return Semantics(
      button: true,
      label: widget.label,
      onLongPress: widget.onConfirmed,
      child: GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressEnd: (_) => _cancel(),
        onLongPressCancel: _cancel,
        onLongPressUp: _cancel,
        child: ClipRRect(
          borderRadius: TFRadius.controlRadius,
          child: Stack(
            children: [
              Container(
                height: TFSize.controlLg,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: TFRadius.controlRadius,
                  color: errorColor.withValues(alpha: TFAlpha.hover),
                  border: Border.all(
                    color: errorColor.withValues(alpha: 0.55),
                    width: TFSize.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_forever,
                      size: TFSize.iconSm,
                      color: errorColor,
                    ),
                    const SizedBox(width: TFSpace.sm),
                    Text(
                      widget.label,
                      style: textTheme.labelLarge?.copyWith(
                        color: errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_progress > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progress,
                      child: ColoredBox(
                        color: errorColor.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
