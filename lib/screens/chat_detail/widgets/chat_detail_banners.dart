import 'package:flutter/material.dart';


class ChatDetailBanners extends StatelessWidget {
  const ChatDetailBanners({
    super.key,
    this.syncIndicator,
    this.progress,
    this.pinnedBar,
    this.essenceBar,
    this.notice,
  });

  final Widget? syncIndicator;
  final Widget? progress;
  final Widget? pinnedBar;
  final Widget? essenceBar;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final slots = <Widget?>[
      syncIndicator,
      progress,
      pinnedBar,
      essenceBar,
      notice,
    ];
    if (slots.every((slot) => slot == null)) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final slot in slots) _BannerSlot(child: slot),
      ],
    );
  }
}

class _BannerSlot extends StatelessWidget {
  const _BannerSlot({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: child == null
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : KeyedSubtree(key: const ValueKey('content'), child: child!),
    );
  }
}


class ChatDetailNotice extends StatelessWidget {
  const ChatDetailNotice({
    super.key,
    required this.text,
    this.onDismiss,
    this.leading = Icons.info_outline,
  });

  final String text;
  final VoidCallback? onDismiss;
  final IconData leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.secondaryContainer,
      child: ListTile(
        leading: Icon(leading, color: colorScheme.onSecondaryContainer),
        title: Text(
          text,
          style: TextStyle(color: colorScheme.onSecondaryContainer),
        ),
        trailing: onDismiss == null
            ? null
            : IconButton(icon: const Icon(Icons.close), onPressed: onDismiss),
      ),
    );
  }
}
