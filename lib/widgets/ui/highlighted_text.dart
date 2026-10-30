import 'package:flutter/material.dart';

import '../../utils/message_search.dart';

/// 带命中高亮的文本
class HighlightedText extends StatelessWidget {
  final SearchExcerpt excerpt;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  const HighlightedText(
    this.excerpt, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium;
    final colorScheme = theme.colorScheme;

    if (!excerpt.hasMatch) {
      return Text(
        excerpt.text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final start = excerpt.matchStart;
    final end = (excerpt.matchStart + excerpt.matchLength).clamp(
      0,
      excerpt.text.length,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: excerpt.text.substring(0, start)),
          TextSpan(
            text: excerpt.text.substring(start, end),
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              backgroundColor: colorScheme.primaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: excerpt.text.substring(end)),
        ],
      ),
      style: baseStyle,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
