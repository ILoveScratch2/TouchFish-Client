import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key});

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  final _notificationService = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
    _notificationService.markFriendRead();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _acceptFriendRequest(NotificationInfo notif) async {
    final success = await _notificationService.acceptFriendRequest(notif);
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.chatInviteAccept : l10n.announcementCreateFailed),
        ),
      );
    }
  }

  Future<void> _rejectFriendRequest(NotificationInfo notif) async {
    final success = await _notificationService.rejectFriendRequest(notif);
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.chatInviteReject : l10n.announcementCreateFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final friendNotifs = _notificationService.friendNotifications;

    return Container(
      padding: MediaQuery.of(context).viewInsets,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 16, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chatInvites,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _notificationService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : friendNotifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.chatNoInvites,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: friendNotifs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final notif = friendNotifs[index];
                          return _FriendNotificationTile(
                            notification: notif,
                            onAccept: () => _acceptFriendRequest(notif),
                            onReject: () => _rejectFriendRequest(notif),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FriendNotificationTile extends StatelessWidget {
  final NotificationInfo notification;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _FriendNotificationTile({
    required this.notification,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final timeLabel = _formatTime(notification.dateTime);

    final bool isPending = notification.event == 'friend.request';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                notification.event == 'friend.request'
                    ? Icons.person_add
                    : Icons.person,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.content,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: Text(l10n.chatInviteReject),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onAccept,
                  child: Text(l10n.chatInviteAccept),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
