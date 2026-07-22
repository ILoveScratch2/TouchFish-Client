import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/notification_model.dart';
import '../routes/app_routes.dart';
import '../services/notification_service.dart';

class ForumNotificationSheet extends StatelessWidget {
  const ForumNotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notificationService = NotificationService.instance;
    return AnimatedBuilder(
      animation: notificationService,
      builder: (context, _) {
        final notifications = notificationService.forumNotifications;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    l10n.notificationTabNotifications,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: notifications.isEmpty
                      ? Center(child: Text(l10n.notificationEmpty))
                      : ListView.separated(
                          itemCount: notifications.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return ListTile(
                              leading: Icon(_iconFor(notification.event)),
                              title: Text(notification.title),
                              subtitle: Text(notification.content),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _open(context, notification),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(String event) {
    if (event.contains('mentioned')) return Icons.alternate_email;
    if (event.contains('approved')) return Icons.check_circle_outline;
    if (event.contains('rejected') || event.contains('deleted')) {
      return Icons.error_outline;
    }
    if (event.contains('pending')) return Icons.rate_review_outlined;
    return Icons.forum_outlined;
  }

  void _open(BuildContext context, NotificationInfo notification) {
    final router = GoRouter.of(context);
    final fid = (notification.meta['fid'] as num?)?.toInt();
    final pid = (notification.meta['pid'] as num?)?.toInt();
    Navigator.pop(context);
    if (notification.event == 'forum.review.pending') {
      router.go(AppRoutes.adminPendingForums);
    } else if (notification.event == 'forum.post.deleted' && fid != null) {
      router.go('/forum/$fid');
    } else if (fid != null && pid != null) {
      router.go('/forum/$fid/post/$pid');
    } else if (fid != null) {
      router.go('/forum/$fid');
    } else {
      router.go(AppRoutes.forum);
    }
  }
}
