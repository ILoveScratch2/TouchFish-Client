import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../services/chat_data_service.dart';
import '../../services/forum_pending_service.dart';
import '../../services/notification_service.dart';
import '../../theme/tokens.dart';
import '../ui/empty_state.dart';

/// 收件箱聚合卡
class InboxSummaryCard extends StatefulWidget {
  const InboxSummaryCard({super.key});

  @override
  State<InboxSummaryCard> createState() => _InboxSummaryCardState();
}

class _InboxSummaryCardState extends State<InboxSummaryCard> {
  final _notifications = NotificationService.instance;
  final _chatData = ChatDataService.instance;
  final _forumPending = ForumPendingService.instance;

  @override
  void initState() {
    super.initState();
    for (final listenable in <Listenable>[
      _notifications,
      _chatData,
      _forumPending,
    ]) {
      listenable.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final listenable in <Listenable>[
      _notifications,
      _chatData,
      _forumPending,
    ]) {
      listenable.removeListener(_onChanged);
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final items = <_InboxItem>[
      if (_chatData.totalUnreadCount > 0)
        _InboxItem(
          icon: Icons.chat_bubble_outline,
          label: l10n.navChat,
          count: _chatData.totalUnreadCount,
          route: AppRoutes.chat,
        ),
      if (_notifications.announcementUnreadCount > 0)
        _InboxItem(
          icon: Icons.campaign_outlined,
          label: l10n.navAnnouncement,
          count: _notifications.announcementUnreadCount,
          route: AppRoutes.announcement,
        ),
      if (_notifications.forumUnreadCount > 0)
        _InboxItem(
          icon: Icons.forum_outlined,
          label: l10n.navForum,
          count: _notifications.forumUnreadCount,
          route: AppRoutes.forum,
        ),
      if (_forumPending.pendingCount > 0)
        _InboxItem(
          icon: Icons.pending_actions_outlined,
          label: l10n.navAdmin,
          count: _forumPending.pendingCount,
          route: AppRoutes.adminPendingForums,
        ),
    ];

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: TFSpace.md),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TFSpace.sm),
            child: EmptyState(
              compact: true,
              icon: Symbols.inbox,
              title: l10n.inboxAllClear,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TFSpace.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TFSpace.xs),
          child: Column(
            children: [
              for (final item in items)
                InkWell(
                  onTap: () => GoRouter.of(context).go(item.route),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TFSpace.card,
                      vertical: TFSpace.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: TFSize.iconMd,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: TFSpace.md),
                        Expanded(
                          child: Text(
                            item.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          item.count > 99 ? '99+' : '${item.count}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: TFSpace.xs),
                        Icon(
                          Icons.chevron_right,
                          size: TFSize.iconSm,
                          color: colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxItem {
  final IconData icon;
  final String label;
  final int count;
  final String route;

  const _InboxItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.route,
  });
}
