import 'package:flutter/material.dart';

class NetworkIndicator extends StatelessWidget {
  final double size;
  final bool isConnected;
  final Color? color;

  const NetworkIndicator({
    super.key,
    required this.size,
    required this.isConnected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? (isConnected 
      ? Theme.of(context).colorScheme.primary 
      : Theme.of(context).colorScheme.error);

    return Icon(
      isConnected ? Icons.wifi : Icons.wifi_off,
      size: size,
      color: iconColor,
    );
  }
}
