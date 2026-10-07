import 'package:flutter/material.dart';

/// 真·Code::Blocks
const String codeFontFamily = 'Fira Code';
const List<String> codeFontFamilyFallback = [
  'Menlo',
  'Monaco',
  'Courier New',
  'Courier',
  'Ubuntu Mono',
  'DejaVu Sans Mono',
  'Liberation Mono',
  'Noto Sans Mono',
  'Droid Sans Mono',
  'Source Code Pro',
  'Consolas',
  'JetBrains Mono',
  'monospace',
];

class CodeBlock extends StatelessWidget {
  final String text;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const CodeBlock({
    super.key,
    required this.text,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: codeFontFamily,
          fontFamilyFallback: codeFontFamilyFallback,
          fontSize: fontSize,
          height: 1.4,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
