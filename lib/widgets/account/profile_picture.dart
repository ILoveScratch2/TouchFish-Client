import 'package:flutter/material.dart';

class ProfilePictureWidget extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final String? fallbackText;

  const ProfilePictureWidget({
    super.key,
    this.avatarUrl,
    this.radius = 24,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.person,
        size: radius,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
