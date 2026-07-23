import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';

class AppNotificationOverlay extends StatelessWidget {
  const AppNotificationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppNotificationService.instance,
      builder: (context, _) {
        final items = AppNotificationService.instance.items;
        if (items.isEmpty) return const SizedBox.shrink();

        final desktop = MediaQuery.sizeOf(context).width >= 600;
        final desktopFrame =
            !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
        final top =
            MediaQuery.paddingOf(context).top + (desktopFrame ? 52 : 16);
        if (desktop) {
          return Positioned(
            top: top,
            right: 16,
            width: 420,
            child: Material(
              color: Colors.transparent,
              child: Column(
                spacing: 8,
                children: items
                    .map(
                      (item) => _AnimatedNotificationItem(
                        key: ValueKey(item.notification.id),
                        item: item,
                        desktop: true,
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        }

        const overlap = 20.0;
        return Positioned(
          top: top,
          left: 16,
          right: 16,
          height: overlap * (items.length - 1) + 130,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: items.asMap().entries.map((entry) {
                return Positioned(
                  top: entry.key * overlap,
                  left: 0,
                  right: 0,
                  child: _AnimatedNotificationItem(
                    key: ValueKey(entry.value.notification.id),
                    item: entry.value,
                    desktop: false,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedNotificationItem extends StatefulWidget {
  final AppNotificationItem item;
  final bool desktop;

  const _AnimatedNotificationItem({
    super.key,
    required this.item,
    required this.desktop,
  });

  @override
  State<_AnimatedNotificationItem> createState() =>
      _AnimatedNotificationItemState();
}

class _AnimatedNotificationItemState extends State<_AnimatedNotificationItem>
    with TickerProviderStateMixin {
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 250),
  );
  late final AnimationController _progressController = AnimationController(
    vsync: this,
    duration: widget.item.duration,
  );

  @override
  void initState() {
    super.initState();
    _entryController.forward();
    _progressController.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedNotificationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.item.dismissed && widget.item.dismissed) {
      _entryController.reverse().then((_) {
        AppNotificationService.instance.remove(widget.item.notification.id);
      });
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: widget.desktop ? const Offset(1, 0) : const Offset(0, -1),
        end: Offset.zero,
      ).animate(curved),
      child: SizeTransition(
        sizeFactor: curved,
        axis: Axis.vertical,
        child: Material(
          elevation: 8,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: _NotificationCard(
            item: widget.item,
            desktop: widget.desktop,
            progress: _progressController,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotificationItem item;
  final bool desktop;
  final Animation<double> progress;

  const _NotificationCard({
    required this.item,
    required this.desktop,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final notification = item.notification;
    return GestureDetector(
      onTap: () => AppNotificationService.instance.open(notification),
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 100) {
          AppNotificationService.instance.dismiss(notification.id);
        }
      },
      onVerticalDragEnd: desktop
          ? null
          : (details) {
              if ((details.primaryVelocity ?? 0) < -100) {
                AppNotificationService.instance.dismiss(notification.id);
              }
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Card(
              margin: EdgeInsets.zero,
              elevation: 4,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 40, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NotificationAvatar(url: notification.avatarUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (notification.body.isNotEmpty)
                                Text(
                                  notification.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (notification.subtitle?.isNotEmpty == true)
                                Text(
                                  notification.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: progress,
                    builder: (context, _) => LinearProgressIndicator(
                      value: 1 - progress.value,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () =>
                    AppNotificationService.instance.dismiss(notification.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  final String? url;

  const _NotificationAvatar({this.url});

  @override
  Widget build(BuildContext context) {
    if (url?.isNotEmpty == true) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(url!),
        onBackgroundImageError: (_, _) {},
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.notifications_outlined,
        size: 18,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
