import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    _refresh();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await _notificationService.forceRefresh();
    _notificationService.markInviteRead();
  }

  Future<void> _handleFriend(
    NotificationInfo notification,
    bool accepted,
  ) async {
    final success = accepted
        ? await _notificationService.acceptFriendRequest(notification)
        : await _notificationService.rejectFriendRequest(notification);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    _showResult(
      success,
      accepted ? l10n.chatInviteAccept : l10n.chatInviteReject,
      accepted ? l10n.chatInviteAcceptFailed : l10n.chatInviteRejectFailed,
    );
  }

  Future<void> _handleGroupRequest(
    NotificationInfo notification,
    bool approved,
  ) async {
    final success = await _notificationService.handleGroupJoinRequest(
      notification,
      approved,
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    _showResult(
      success,
      approved ? l10n.chatInviteAccept : l10n.chatInviteReject,
      l10n.commonFailedOperation,
    );
  }

  void _showResult(bool success, String successText, String failureText) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? successText : failureText)),
    );
  }

  void _openGroup(int gid) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.go('/chat/G$gid');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final notifications = _notificationService.inviteNotifications;

    return Container(
      padding: MediaQuery.of(context).viewInsets,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 16,
              left: 20,
              right: 16,
              bottom: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chatInvites,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: _notificationService.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _notificationService.isLoading ? null : _refresh,
                  tooltip: l10n.retry,
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _notificationService.isLoading && notifications.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                ? _EmptyInvites(label: l10n.chatNoInvites)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _InviteNotificationTile(
                        notification: notification,
                        onAccept: notification.event == 'friend.request'
                            ? () => _handleFriend(notification, true)
                            : notification.event == 'group.join.request'
                            ? () => _handleGroupRequest(notification, true)
                            : null,
                        onReject: notification.event == 'friend.request'
                            ? () => _handleFriend(notification, false)
                            : notification.event == 'group.join.request'
                            ? () => _handleGroupRequest(notification, false)
                            : null,
                        onOpenGroup:
                            notification.groupEventGid != null &&
                                notification.groupRequestRid == null &&
                                (notification.event == 'group.invited' ||
                                    notification.event == 'group.join.approved')
                            ? () => _openGroup(notification.groupEventGid!)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInvites extends StatelessWidget {
  final String label;

  const _EmptyInvites({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _InviteNotificationTile extends StatelessWidget {
  final NotificationInfo notification;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onOpenGroup;

  const _InviteNotificationTile({
    required this.notification,
    this.onAccept,
    this.onReject,
    this.onOpenGroup,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isGroup = notification.isGroupEvent;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          isGroup ? Icons.group_add_outlined : Icons.person_add_outlined,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(notification.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(notification.content),
          const SizedBox(height: 4),
          Text(
            _formatTime(notification.dateTime),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (notification.event == 'group.invited' &&
              notification.groupRequestRid != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.groupInvitePendingReview,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ],
        ],
      ),
      trailing: onAccept != null || onReject != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.error),
                  tooltip: l10n.chatInviteReject,
                  onPressed: onReject,
                ),
                IconButton.filled(
                  icon: const Icon(Icons.check),
                  tooltip: l10n.chatInviteAccept,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: onAccept,
                ),
              ],
            )
          : onOpenGroup != null
          ? IconButton(
              icon: const Icon(Icons.arrow_forward),
              tooltip: l10n.groupOpen,
              onPressed: onOpenGroup,
            )
          : null,
    );
  }

  static String _formatTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
