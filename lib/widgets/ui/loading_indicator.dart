import 'package:flutter/material.dart';

/// 全屏居中加载指示器。
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// 列表尾部 / 内联加载指示器（尺寸更小、带上下间距）。
class InlineLoadingIndicator extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry padding;

  const InlineLoadingIndicator({
    super.key,
    this.size = 20,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
