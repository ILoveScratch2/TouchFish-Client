import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/app_notification.dart';
import '../models/notification_model.dart';
import '../routes/app_routes.dart';
import '../services/notification_service.dart';
import '../services/snackbar_service.dart';
import '../theme/tokens.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/loading_indicator.dart';

enum NotificationFilter { all, system, forum, friend, group }

/// 通知中心
/// 独立页面
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationFilter _filter = NotificationFilter.all;

  /// 触底补拉更早通知的距离
  static const double _loadMoreThreshold = 320;

  final ScrollController _scrollController = ScrollController();

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 打开时补拉
    unawaited(NotificationService.instance.fetchNotifications());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - _loadMoreThreshold) {
      return;
    }
    // 服务端内部有并发保护（_loadingMore）
    unawaited(NotificationService.instance.loadMoreNotifications());
  }

  List<NotificationInfo> _source() {
    final service = NotificationService.instance;
    switch (_filter) {
      case NotificationFilter.all:
        return service.allNotifications;
      case NotificationFilter.system:
        return service.systemNotifications;
      case NotificationFilter.forum:
        return service.forumNotifications;
      case NotificationFilter.friend:
        return service.friendNotifications;
      case NotificationFilter.group:
        return service.inviteNotifications;
    }
  }

  int _countFor(NotificationFilter filter) {
    final service = NotificationService.instance;
    switch (filter) {
      case NotificationFilter.all:
        return service.allNotifications.length;
      case NotificationFilter.system:
        return service.systemNotifications.length;
      case NotificationFilter.forum:
        return service.forumNotifications.length;
      case NotificationFilter.friend:
        return service.friendNotifications.length;
      case NotificationFilter.group:
        return service.inviteNotifications.length;
    }
  }

  Future<void> _openNotification(NotificationInfo notification) async {
    final service = NotificationService.instance;
    if (notification.readAt == null) {
      unawaited(service.markReadFor(notification));
    }
    final route = AppNotification.routeFor(notification);
    if (!mounted) return;
    // 通知中心本身是页面，直接跳目标页即可
    if (route.isNotEmpty && route != AppRoutes.account) {
      GoRouter.of(context).push(route);
    }
  }

  Future<void> _markAllRead() async {
    final service = NotificationService.instance;
    switch (_filter) {
      case NotificationFilter.all:
        await service.markSystemRead();
        await service.markFriendRead();
        await service.markInviteRead();
        await service.markForumRead();
      case NotificationFilter.system:
        await service.markSystemRead();
      case NotificationFilter.forum:
        await service.markForumRead();
      case NotificationFilter.friend:
        await service.markFriendRead();
      case NotificationFilter.group:
        await service.markInviteRead();
    }
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // 直接进页面时没有可返回的栈
    context.go(AppRoutes.account);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final service = NotificationService.instance;
        final notifs = _source();
        final unread = notifs.where((n) => n.readAt == null).length;
        // 概览用同一份
        final all = service.allNotifications;
        final total = all.length;
        final totalUnread = all.where((n) => n.readAt == null).length;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.notificationTitle),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: _goBack,
            ),
            actions: [
              if (unread > 0)
                TextButton(
                  onPressed: _markAllRead,
                  child: Text(l10n.notificationMarkAllRead),
                ),
              IconButton(
                tooltip: l10n.refresh,
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    unawaited(NotificationService.instance.fetchNotifications()),
              ),
              const SizedBox(width: TFSpace.xs),
            ],
          ),
          body: Column(
            children: [
              // 概览
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TFSpace.lg,
                    TFSpace.sm,
                    TFSpace.lg,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.notificationSummary(total, totalUnread),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              // 分类筛选
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TFSpace.lg,
                    vertical: TFSpace.sm,
                  ),
                  children: [
                    _filterChip(
                      NotificationFilter.all,
                      l10n.notificationFilterAll,
                    ),
                    _filterChip(
                      NotificationFilter.system,
                      l10n.notificationFilterSystem,
                    ),
                    _filterChip(
                      NotificationFilter.forum,
                      l10n.notificationFilterForum,
                    ),
                    _filterChip(
                      NotificationFilter.friend,
                      l10n.notificationFilterFriend,
                    ),
                    _filterChip(
                      NotificationFilter.group,
                      l10n.notificationFilterGroup,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: service.isLoading && notifs.isEmpty
                    ? const LoadingIndicator()
                    : notifs.isEmpty
                    ? EmptyState(
                        icon: Icons.notifications_none,
                        title: l10n.notificationEmpty,
                        description: l10n.notificationEmptyDescription,
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: TFSpace.md,
                          vertical: TFSpace.sm,
                        ),
                        // 底部状态
                        itemCount: notifs.length + 1,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: TFSpace.sm),
                        itemBuilder: (context, index) {
                          if (index >= notifs.length) {
                            return _buildListFooter(context);
                          }
                          final notif = notifs[index];
                          return Dismissible(
                            key: ValueKey('notification-${notif.id}'),
                            direction: DismissDirection.endToStart,
                            background: _buildDeleteBackground(context),
                            confirmDismiss: (_) => _deleteNotification(notif),
                            child: _NotificationCard(
                              notification: notif,
                              onTap: () => _openNotification(notif),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 列表底部
  Widget _buildListFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = NotificationService.instance;
    final theme = Theme.of(context);
    if (service.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: TFSpace.lg),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!service.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: TFSpace.lg),
        child: Center(
          child: Text(
            l10n.notificationNoMore,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: TFSpace.md);
  }

  Future<bool> _deleteNotification(NotificationInfo notification) async {
    final l10n = AppLocalizations.of(context)!;
    if (notification.locked) {
      // 处罚未撤销/未到期前不准 rm -rf
      TouchFishSnackbarService.instance.show(l10n.punishmentNoticeLocked);
      return false;
    }
    final success = await NotificationService.instance.deleteFor(notification);
    TouchFishSnackbarService.instance.show(
      success ? l10n.notificationDeleted : l10n.notificationDeleteFailed,
    );
    return success;
  }

  Widget _buildDeleteBackground(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: TFSpace.xl),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(TFRadius.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delete_outline,
            size: TFSize.iconSm,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: TFSpace.xs),
          Text(
            l10n.notificationSwipeToDelete,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(NotificationFilter value, String label) {
    final count = _countFor(value);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: TFSpace.sm),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: TFSpace.xs),
              Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationInfo notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final unread = notification.readAt == null;
    final timeLabel = _formatRelativeTime(
      context,
      notification.dateTime,
    );

    final icon = _iconFor(notification);
    final accent = _accentFor(colorScheme, notification);
    final category = _categoryLabel(l10n, notification);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: unread
          ? colorScheme.primaryContainer.withValues(alpha: 0.22)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TFRadius.card),
        side: BorderSide(
          color: unread
              ? colorScheme.primary.withValues(alpha: 0.35)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(TFSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: TFSize.avatarMd,
                height: TFSize.avatarMd,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(TFRadius.sm),
                ),
                child: Icon(icon, color: accent, size: TFSize.iconMd),
              ),
              const SizedBox(width: TFSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: TFSpace.sm),
                        Text(
                          timeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TFSpace.xs),
                    Text(
                      notification.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: TFSpace.sm),
                    Wrap(
                      spacing: TFSpace.xs,
                      runSpacing: TFSpace.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Pill(
                          label: category,
                          color: accent,
                        ),
                        if (notification.locked)
                          _Pill(
                            label: l10n.notificationLockedBadge,
                            color: colorScheme.error,
                            icon: Icons.lock_outline,
                          ),
                        if (unread)
                          _Pill(
                            label: l10n.notificationUnreadBadge,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(NotificationInfo notification) {
    if (notification.isFriendEvent) return Icons.person_add_alt_1;
    if (notification.isForumEvent) return Icons.forum_outlined;
    if (notification.isGroupEvent) return Icons.group_outlined;
    if (notification.isAnnouncementEvent) return Icons.campaign_outlined;
    if (notification.isPunishmentEvent) return Icons.gavel;
    if (notification.isAuthEvent) return Icons.admin_panel_settings_outlined;
    return Icons.notifications_none;
  }

  static Color _accentFor(ColorScheme colorScheme, NotificationInfo n) {
    if (n.isPunishmentEvent || n.isAuthEvent) return colorScheme.error;
    if (n.isForumEvent) return colorScheme.tertiary;
    if (n.isGroupEvent) return colorScheme.secondary;
    return colorScheme.primary;
  }

  static String _categoryLabel(AppLocalizations l10n, NotificationInfo n) {
    if (n.isFriendEvent) return l10n.notificationFilterFriend;
    if (n.isForumEvent) return l10n.notificationFilterForum;
    if (n.isGroupEvent) return l10n.notificationFilterGroup;
    if (n.isPunishmentEvent) return l10n.punishmentTitle;
    if (n.isAnnouncementEvent) return l10n.navAnnouncement;
    if (n.isAuthEvent) return l10n.notificationFilterSystem;
    return l10n.notificationCategoryOther;
  }

  static String _formatRelativeTime(BuildContext context, DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.isNegative || diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    if (diff.inDays == 1) return l10n.timeYesterday;
    if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}

/// 小标签
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TFSpace.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(TFRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: TFSize.iconXs, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
