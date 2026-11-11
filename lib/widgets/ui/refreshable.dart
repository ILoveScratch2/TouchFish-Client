import 'package:flutter/material.dart';


class PullToRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final bool _contentMode;

  const PullToRefresh.list({
    super.key,
    required this.onRefresh,
    required this.child,
  }) : _contentMode = false;

  const PullToRefresh.content({
    super.key,
    required this.onRefresh,
    required this.child,
  }) : _contentMode = true;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: _contentMode ? ScrollableFill(child: child) : child,
    );
  }
}

class ScrollableFill extends StatelessWidget {
  final Widget child;

  const ScrollableFill({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
    );
  }
}
