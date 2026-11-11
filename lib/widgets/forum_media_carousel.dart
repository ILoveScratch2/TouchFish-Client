import 'package:flutter/material.dart';

import '../models/file_attachment.dart';
import '../theme/tokens.dart';
import 'file_attachment_view.dart';

/// 横向媒体轮播
class ForumMediaCarousel extends StatefulWidget {
  final List<FileAttachment> images;

  /// 图片按 cover 裁切填充
  final double height;

  const ForumMediaCarousel({
    super.key,
    required this.images,
    this.height = 240,
  });

  @override
  State<ForumMediaCarousel> createState() => _ForumMediaCarouselState();
}

class _ForumMediaCarouselState extends State<ForumMediaCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: widget.images.length > 1 ? 0.78 : 1,
  );
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return ClipRRect(
        borderRadius: TFRadius.cardRadius,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: FileAttachmentView(attachment: images.first),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == images.length - 1 ? 0 : TFSpace.sm,
                ),
                child: ClipRRect(
                  borderRadius: TFRadius.cardRadius,
                  child: FileAttachmentView(attachment: images[index]),
                ),
              );
            },
          ),
        ),
        if (images.length <= 8) ...[
          const SizedBox(height: TFSpace.sm),
          _PageDots(count: images.length, active: _index),
        ],
      ],
    );
  }
}

/// 与置顶卡的分页指示保持同一。
class _PageDots extends StatelessWidget {
  final int count;
  final int active;

  const _PageDots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: TFMotion.fast,
            curve: TFMotion.standard,
            margin: const EdgeInsets.only(right: TFSpace.xs),
            width: i == active ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              borderRadius: TFRadius.pillRadius,
            ),
          ),
      ],
    );
  }
}
