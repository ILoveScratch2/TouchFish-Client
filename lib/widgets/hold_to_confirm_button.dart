import 'dart:async';
import 'package:flutter/material.dart';

class HoldToConfirmButton extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;
  const HoldToConfirmButton({super.key, required this.label, required this.onConfirmed});

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> {
  Timer? _timer;
  double _progress = 0;

  void _start() {
    _timer?.cancel();
    const ticks = 30;
    var tick = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      tick++;
      if (!mounted) return;
      setState(() => _progress = tick / ticks);
      if (tick >= ticks) {
        _timer?.cancel();
        widget.onConfirmed();
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    if (mounted) setState(() => _progress = 0);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _cancel(),
      onLongPressCancel: _cancel,
      child: Stack(
        children: [
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.delete_forever), label: Text(widget.label))),
          if (_progress > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _progress, child: ColoredBox(color: Theme.of(context).colorScheme.error.withValues(alpha: .25))),
              ),
            ),
        ],
      ),
    );
  }
}
