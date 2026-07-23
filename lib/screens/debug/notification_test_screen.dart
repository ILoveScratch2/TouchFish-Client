import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/app_notification.dart';
import '../../services/app_notification_service.dart';

class NotificationTestScreen extends StatelessWidget {
  const NotificationTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final samples = [
      _NotificationSample(
        title: l10n.debugNotificationTypePrivateMessage,
        icon: Icons.person_outline,
        route: '/chat/U10001',
        topic: 'message.private',
      ),
      _NotificationSample(
        title: l10n.debugNotificationTypeGroupMessage,
        icon: Icons.group_outlined,
        route: '/chat/G10001',
        topic: 'message.group',
      ),
      _NotificationSample(
        title: l10n.debugNotificationTypeAnnouncement,
        icon: Icons.campaign_outlined,
        route: '/announcement',
        topic: 'announcement.created',
      ),
      _NotificationSample(
        title: l10n.debugNotificationTypeForum,
        icon: Icons.forum_outlined,
        route: '/forum',
        topic: 'forum.post.mentioned',
      ),
      _NotificationSample(
        title: l10n.debugNotificationTypeInvite,
        icon: Icons.person_add_outlined,
        route: '/account',
        topic: 'friend.request',
      ),
      _NotificationSample(
        title: l10n.debugNotificationTypeGeneral,
        icon: Icons.notifications_outlined,
        route: '/account',
        topic: 'notification.general',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.debugNotificationTester)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: samples.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final sample = samples[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            leading: CircleAvatar(child: Icon(sample.icon)),
            title: Text(sample.title),
            subtitle: Text(l10n.debugNotificationTestBody),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.web_asset_outlined),
                  tooltip: l10n.debugNotificationTestInApp,
                  onPressed: () => _showInApp(context, sample),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.desktop_windows_outlined),
                  tooltip: l10n.debugNotificationTestSystem,
                  onPressed: kIsWeb ? null : () => _showSystem(context, sample),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  AppNotification _notification(
    BuildContext context,
    _NotificationSample sample,
  ) {
    return AppNotification(
      id: '${sample.topic}:${DateTime.now().microsecondsSinceEpoch}',
      title: sample.title,
      body: AppLocalizations.of(context)!.debugNotificationTestBody,
      subtitle: sample.topic,
      route: sample.route,
      topic: sample.topic,
    );
  }

  void _showInApp(BuildContext context, _NotificationSample sample) {
    AppNotificationService.instance.showInAppTest(
      _notification(context, sample),
    );
  }

  Future<void> _showSystem(
    BuildContext context,
    _NotificationSample sample,
  ) async {
    final shown = await AppNotificationService.instance.showSystemTest(
      _notification(context, sample),
    );
    if (!context.mounted || shown) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.debugNotificationSystemUnavailable,
        ),
      ),
    );
  }
}

class _NotificationSample {
  final String title;
  final IconData icon;
  final String route;
  final String topic;

  const _NotificationSample({
    required this.title,
    required this.icon,
    required this.route,
    required this.topic,
  });
}
