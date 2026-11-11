import 'package:flutter/material.dart';

import '../models/forum_model.dart';
import '../theme/tokens.dart';
import 'account/profile_picture.dart';

/// 版块横向速览条
class ForumQuickStrip extends StatelessWidget {
  final List<Forum> forums;
  final ValueChanged<Forum> onOpen;

  const ForumQuickStrip({
    super.key,
    required this.forums,
    required this.onOpen,
  });

  static const double _height = 84;
  static const double _cardWidth = 64;

  @override
  Widget build(BuildContext context) {
    if (forums.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(TFSpace.lg, 10, TFSpace.lg, 8),
        itemCount: forums.length,
        separatorBuilder: (_, _) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final forum = forums[index];
          return SizedBox(
            width: _cardWidth,
            child: InkWell(
              borderRadius: TFRadius.smRadius,
              onTap: () => onOpen(forum),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfilePictureWidget(
                    avatarUrl: forum.avatarUrl,
                    radius: 24,
                    fallbackIcon: Icons.forum,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    forum.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
