import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/typing_status.dart';
import '../services/chat_data_service.dart';

/// 打字指示器
class TypingIndicator extends StatefulWidget {
  final List<TypingStatus> typingStatuses;

  const TypingIndicator({super.key, required this.typingStatuses});

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null || widget.typingStatuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: _ChatActivityLine(
              l10n: l10n,
              statuses: widget.typingStatuses,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatActivityLine extends StatelessWidget {
  final AppLocalizations l10n;
  final List<TypingStatus> statuses;

  const _ChatActivityLine({required this.l10n, required this.statuses});

  String _displayName(int uid) {
    final profile = ChatDataService.instance.getUser('U$uid');
    return profile?.username ?? 'User $uid';
  }

  String _buildText() {
    final uids = <int>{for (final s in statuses) s.uid}.toList();
    final first = _displayName(uids.first);
    if (uids.length == 1) return l10n.chatTypingSingle(first);
    if (uids.length == 2) {
      return l10n.chatTypingDouble(first, _displayName(uids[1]));
    }
    return l10n.chatTypingMultiple(first, uids.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 8),
          child: _TypingIndicatorDots(isUploading: false),
        ),
        Expanded(
          child: Text(
            _buildText(),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingIndicatorDots extends StatefulWidget {
  final bool isUploading;

  const _TypingIndicatorDots({required this.isUploading});

  @override
  State<_TypingIndicatorDots> createState() => _TypingIndicatorDotsState();
}

class _TypingIndicatorDotsState extends State<_TypingIndicatorDots>
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

  double _dotProgress(int index) {
    final offset = index * 0.14;
    final progress = (_controller.value - offset) % 1.0;
    if (progress < 0.55) {
      return Curves.easeOutCubic.transform(progress / 0.55);
    }
    return 1 - Curves.easeInCubic.transform((progress - 0.55) / 0.45);
  }

  double _dotLift(int index) {
    final offset = index * 0.16;
    final progress = (_controller.value - offset) % 1.0;
    if (progress < 0.5) {
      return Curves.easeOut.transform(progress / 0.5);
    }
    return 1 - Curves.easeIn.transform((progress - 0.5) / 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final activeColor = widget.isUploading
        ? Theme.of(context).colorScheme.primary
        : baseColor;

    return SizedBox(
      width: 28,
      height: 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final progress = _dotProgress(index);
              final lift = _dotLift(index);
              final size = widget.isUploading
                  ? 3.0 + (progress * 2.1)
                  : 3.4 + (progress * 1.8);

              return Transform.translate(
                offset: Offset(0, -lift * (widget.isUploading ? 1.4 : 1.0)),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      activeColor.withValues(
                        alpha: widget.isUploading ? 0.24 : 0.32,
                      ),
                      activeColor,
                      progress,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
