import 'package:flutter/material.dart';
import '../optimized_image.dart';

class ProfilePictureWidget extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final String? fallbackText;
  final IconData? fallbackIcon;

  const ProfilePictureWidget({
    super.key,
    this.avatarUrl,
    this.radius = 24,
    this.fallbackText,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: resizedImageProvider(
          NetworkImage(avatarUrl!),
          MediaQuery.of(context).devicePixelRatio,
          width: radius * 2,
          height: radius * 2,
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        fallbackIcon ?? Icons.person,
        size: radius,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
