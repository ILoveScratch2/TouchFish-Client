import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 骨架屏
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = TFRadius.smRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final base = colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduceMotion ? 0.5 : _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              base,
              colorScheme.surfaceContainerHigh,
              0.35 + 0.35 * t,
            ),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

/// 消息列表骨架
class MessageListSkeleton extends StatelessWidget {
  final int itemCount;

  const MessageListSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: TFSpace.md,
        vertical: TFSpace.sm,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // 伪随机但稳定的宽度
        final isMine = index % 3 == 2;
        final width = 120.0 + ((index * 53) % 140);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: TFSpace.sm),
          child: Row(
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine) ...[
                const SkeletonBox(
                  width: TFSize.avatarMd,
                  height: TFSize.avatarMd,
                  borderRadius: TFRadius.pillRadius,
                ),
                const SizedBox(width: TFSpace.sm),
              ],
              Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMine) ...[
                    const SkeletonBox(width: 64, height: 10),
                    const SizedBox(height: TFSpace.xs),
                  ],
                  SkeletonBox(width: width, height: 40),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 通用列表骨架：头像方块 + 两行文本
class ListSkeleton extends StatelessWidget {
  final int itemCount;

  const ListSkeleton({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: TFSpace.sm),
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TFSpace.lg,
          vertical: TFSpace.md,
        ),
        child: Row(
          children: [
            const SkeletonBox(
              width: TFSize.avatarMd,
              height: TFSize.avatarMd,
              borderRadius: TFRadius.pillRadius,
            ),
            const SizedBox(width: TFSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: 96.0 + ((index * 37) % 80),
                    height: 12,
                  ),
                  const SizedBox(height: TFSpace.sm),
                  const SkeletonBox(width: double.infinity, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
