import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class TypingIndicator extends StatefulWidget {
  final List<String> userNames;

  const TypingIndicator({super.key, required this.userNames});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _message(AppLocalizations l10n) {
    final names = widget.userNames;
    if (names.length == 1) return l10n.chatTypingSingle(names.first);
    if (names.length == 2) return l10n.chatTypingDouble(names[0], names[1]);
    return l10n.chatTypingMultiple(names.first, names.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null || widget.userNames.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 18,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(3, (index) {
                  final phase = (_controller.value - index * 0.14) % 1.0;
                  final lift = phase < 0.5
                      ? Curves.easeOut.transform(phase * 2)
                      : Curves.easeIn.transform((1 - phase) * 2);
                  final size = 3.5 + lift * 1.8;
                  return Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Transform.translate(
                      offset: Offset(0, -lift * 3),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.35 + lift * 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _message(l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
