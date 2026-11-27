import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/typing_status.dart';
import '../services/chat_data_service.dart';

/// 打字指示器
class TypingIndicator extends StatelessWidget {
  final List<TypingStatus> typingStatuses;

  const TypingIndicator({super.key, required this.typingStatuses});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null || typingStatuses.isEmpty) {
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
            child: _ChatActivityLine(l10n: l10n, statuses: typingStatuses),
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
          child: const _TypingIndicatorDots(),
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
  const _TypingIndicatorDots();

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

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: const Size(28, 12),
      painter: _TypingDotsPainter(
        _controller,
        Theme.of(context).colorScheme.onSurfaceVariant,
        Directionality.of(context),
      ),
    ),
  );
}

class _TypingDotsPainter extends CustomPainter {
  final Animation<double> phase;
  final Color color;
  final TextDirection direction;
  final Paint _paint = Paint();
  final List<double> _diameters = List.filled(3, 0);

  _TypingDotsPainter(this.phase, this.color, this.direction)
    : super(repaint: phase);

  double _dotProgress(int index) {
    final offset = index * 0.14;
    final progress = (phase.value - offset) % 1.0;
    if (progress < 0.55) {
      return Curves.easeOutCubic.transform(progress / 0.55);
    }
    return 1 - Curves.easeInCubic.transform((progress - 0.55) / 0.45);
  }

  double _dotLift(int index) {
    final offset = index * 0.16;
    final progress = (phase.value - offset) % 1.0;
    if (progress < 0.5) {
      return Curves.easeOut.transform(progress / 0.5);
    }
    return 1 - Curves.easeIn.transform((progress - 0.5) / 0.5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 3.0;
    var width = 2 * spacing;
    for (var i = 0; i < _diameters.length; i++) {
      _diameters[i] = 3.4 + _dotProgress(i) * 1.8;
      width += _diameters[i];
    }
    var x = (size.width - width) / 2;
    for (var i = 0; i < _diameters.length; i++) {
      final diameter = _diameters[i];
      final radius = diameter / 2;
      final progress = (diameter - 3.4) / 1.8;
      _paint.color = color.withValues(
        alpha: 0.32 + (color.a - 0.32) * progress,
      );
      final center = x + radius;
      canvas.drawCircle(
        Offset(
          direction == TextDirection.ltr ? center : size.width - center,
          size.height / 2 - _dotLift(i),
        ),
        radius,
        _paint,
      );
      x += diameter + spacing;
    }
  }

  @override
  bool shouldRepaint(_TypingDotsPainter old) =>
      old.phase != phase || old.color != color || old.direction != direction;
}
