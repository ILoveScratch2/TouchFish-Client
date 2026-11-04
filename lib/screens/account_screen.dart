import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../widgets/account/inbox_summary_card.dart';
import '../models/user_profile.dart';
import '../models/app_notification.dart';
import '../models/notification_model.dart';
import '../widgets/account/account_name.dart';
import '../widgets/account/account_friends_section.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/account/signature_editor.dart';
import '../routes/app_routes.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../theme/tokens.dart';
import '../services/notification_service.dart';
import '../services/snackbar_service.dart';
import '../services/lock_service.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/loading_indicator.dart';
import 'debug/debug_options_screen.dart';
import 'storage_management_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // user state
  UserProfile? _currentUser;
  final _notificationService = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
    _loadUser();
    _silentRefresh();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  int get _unreadCount =>
      _notificationService.announcementUnreadCount +
      _notificationService.inviteUnreadCount +
      _notificationService.forumUnreadCount;

  void _loadUser() {
    setState(() {
      _currentUser = AuthState.instance.currentUser;
    });
  }

  void _silentRefresh() {
    AuthState.instance.refreshProfile().then((_) {
      if (!mounted) return;
      setState(() {
        _currentUser = AuthState.instance.currentUser;
      });
    });
  }

  void _showNotificationSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _notificationService.markAnnouncementRead();
    _notificationService.markFriendRead();
    _notificationService.markInviteRead();
    _notificationService.markForumRead();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AccountNotificationSheet(l10n: l10n),
    );
  }

  Future<void> _updateSignature(String newSign) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final ok = await TfApiClient.instance.changeSign(uid, password, newSign);
    if (!mounted) return;
    if (ok) {
      await AuthState.instance.refreshProfile();
      setState(() {
        _currentUser = AuthState.instance.currentUser;
      });
    } else {
      final l10n = AppLocalizations.of(context)!;
      TouchFishSnackbarService.instance.show(l10n.profileEditSaveFailed);
    }
  }

  void _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.accountLogout,
      message: l10n.accountLogoutConfirm,
      icon: Icons.logout_rounded,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.accountLogout,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );

    if (confirmed == true && mounted) {
      await AuthState.instance.logout();
      setState(() => _currentUser = null);
      if (mounted) GoRouter.of(context).go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return _buildUnauthorizedScreen(context);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(backgroundColor: Colors.transparent, toolbarHeight: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                spacing: 4,
                children: [
                  _buildProfileCard(context),
                  const InboxSummaryCard(),
                  const AccountFriendsSection(),
                  _buildMenuItems(context),
                  const Divider(height: 1),
                  _buildAdditionalOptions(context),
                  _buildLogoutButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthorizedScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push(AppRoutes.register),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Symbols.person_add, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            l10n.accountCreateAccount,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(l10n.accountCreateAccountDescription),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push(AppRoutes.login),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Symbols.login, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            l10n.accountLogin,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(l10n.accountLoginDescription),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => context.push(AppRoutes.about),
                    icon: const Icon(Symbols.info, fill: 1),
                    iconSize: 18,
                    color: Theme.of(context).colorScheme.secondary,
                    tooltip: l10n.accountAbout,
                  ),
                  IconButton(
                    onPressed: () => context.push(AppRoutes.settings),
                    icon: const Icon(Symbols.settings, fill: 1),
                    iconSize: 18,
                    color: Theme.of(context).colorScheme.secondary,
                    tooltip: l10n.accountSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final user = _currentUser!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Background image and profile picture
            if (user.avatar != null)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background placeholder
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 7,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primaryContainer,
                              Theme.of(context).colorScheme.secondaryContainer,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Profile picture
                  Positioned(
                    bottom: -24,
                    left: 16,
                    child: GestureDetector(
                      child: ProfilePictureWidget(
                        avatarUrl: user.avatar,
                        radius: 32,
                      ),
                      onTap: () {
                        context.push('/user/${user.uid}');
                      },
                    ),
                  ),
                ],
              ),
            // User info
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16 + (user.avatar != null ? 16 : 0),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: user.avatar != null ? 0 : 16,
                children: [
                  if (user.avatar == null)
                    GestureDetector(
                      child: ProfilePictureWidget(
                        avatarUrl: user.avatar,
                        radius: 24,
                      ),
                      onTap: () {
                        context.push('/user/${user.uid}');
                      },
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AccountNameWidget(
                          account: user,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '@${user.username}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            _buildRoleBadge(context, user),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SignatureEditorWidget(
                          currentSignature: user.personalSign,
                          onUpdate: (newSign) => _updateSignature(newSign),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context, UserProfile user) {
    final colorScheme = Theme.of(context).colorScheme;
    final stat = user.normalizedStat;

    late final Color backgroundColor;
    late final Color foregroundColor;
    late final IconData icon;

    switch (stat) {
      case 'root':
        backgroundColor = colorScheme.errorContainer;
        foregroundColor = colorScheme.onErrorContainer;
        icon = Icons.shield_rounded;
        break;
      case 'admin':
        backgroundColor = colorScheme.primaryContainer;
        foregroundColor = colorScheme.onPrimaryContainer;
        icon = Icons.admin_panel_settings_rounded;
        break;
      case 'banned':
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurfaceVariant;
        icon = Icons.block_rounded;
        break;
      default:
        backgroundColor = colorScheme.secondaryContainer;
        foregroundColor = colorScheme.onSecondaryContainer;
        icon = Icons.person_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            stat,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final menuItems = <Widget>[
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        trailing: const Icon(Symbols.chevron_right),
        dense: true,
        leading: const Icon(Symbols.person_edit, size: 24),
        title: Text(l10n.accountUpdateYourProfile),
        onTap: () => context.push(AppRoutes.profileEdit),
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        trailing: const Icon(Symbols.chevron_right),
        dense: true,
        leading: const Icon(Symbols.settings, size: 24),
        title: Text(l10n.accountAppSettings),
        onTap: () => context.push(AppRoutes.settings),
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        trailing: const Icon(Symbols.chevron_right),
        dense: true,
        leading: const Icon(Symbols.devices, size: 24),
        title: Text(l10n.accountSessionDevices),
        onTap: () => context.push(AppRoutes.sessionDevices),
      ),
      ListenableBuilder(
        listenable: LockService.instance,
        builder: (context, _) {
          final enabled = LockService.instance.isEnabled;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            trailing: const Icon(Symbols.chevron_right),
            dense: true,
            enabled: enabled,
            leading: const Icon(Symbols.lock, size: 24),
            title: Text(l10n.accountLockNow),
            onTap: () => LockService.instance.lock(),
          );
        },
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        trailing: const Icon(Symbols.chevron_right),
        dense: true,
        leading: const Icon(Symbols.cloud, size: 24),
        title: Text(l10n.storageTitle),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const StorageManagementScreen(),
            ),
          );
        },
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        trailing: const Icon(Symbols.chevron_right),
        dense: true,
        leading: const Icon(Symbols.storefront, size: 24),
        title: Text(l10n.stickerMarketTitle),
        onTap: () => context.push(AppRoutes.stickerMarket),
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        trailing: const Icon(Symbols.chevron_right),
        dense: true,
        leading: const Icon(Symbols.sticky_note_2, size: 24),
        title: Text(l10n.stickerMyPacks),
        onTap: () => context.push(AppRoutes.myStickers),
      ),
      if (_currentUser?.hasAdminAccess == true)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          trailing: const Icon(Symbols.chevron_right),
          dense: true,
          leading: const Icon(Icons.admin_panel_settings_outlined, size: 24),
          title: Text(l10n.navAdmin),
          onTap: () => context.push(AppRoutes.admin),
        ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1),
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        trailing: const Icon(Symbols.chevron_right),
        dense: true,
        leading: _unreadCount > 0
            ? Badge(
                label: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(fontSize: 10),
                ),
                child: const Icon(Symbols.notifications, size: 24),
              )
            : const Icon(Symbols.notifications, size: 24),
        title: Text(l10n.accountNotifications),
        onTap: () => _showNotificationSheet(context),
      ),
    ];

    return Column(children: menuItems);
  }

  Widget _buildAdditionalOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Symbols.info),
          trailing: const Icon(Symbols.chevron_right),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          dense: true,
          title: Text(l10n.accountAbout),
          onTap: () => context.push(AppRoutes.about),
        ),
        ListTile(
          leading: const Icon(Symbols.bug_report),
          trailing: const Icon(Symbols.chevron_right),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          title: Text(l10n.accountDebugOptions),
          dense: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const DebugOptionsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      leading: const Icon(Symbols.logout),
      trailing: const Icon(Symbols.chevron_right),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(l10n.accountLogout),
      dense: true,
      onTap: _logout,
    );
  }
}

enum _NotificationFilter { all, system, forum, friend, group }

class _AccountNotificationSheet extends StatefulWidget {
  final AppLocalizations l10n;

  const _AccountNotificationSheet({required this.l10n});

  @override
  State<_AccountNotificationSheet> createState() =>
      _AccountNotificationSheetState();
}

class _AccountNotificationSheetState extends State<_AccountNotificationSheet> {
  _NotificationFilter _filter = _NotificationFilter.all;

  List<NotificationInfo> _source() {
    final service = NotificationService.instance;
    switch (_filter) {
      case _NotificationFilter.all:
        return service.nonMessageNotifications;
      case _NotificationFilter.system:
        return service.announcementNotifications;
      case _NotificationFilter.forum:
        return service.forumNotifications;
      case _NotificationFilter.friend:
        return service.friendNotifications;
      case _NotificationFilter.group:
        return service.inviteNotifications;
    }
  }

  Future<void> _openNotification(NotificationInfo notification) async {
    final service = NotificationService.instance;
    if (notification.readAt == null) {
      unawaited(service.markReadFor(notification));
    }
    final route = AppNotification.routeFor(notification);
    if (!mounted) return;
    // 先取 router 再关
    final router = GoRouter.of(context);
    Navigator.pop(context);
    if (route.isNotEmpty && route != AppRoutes.account) {
      router.push(route);
    }
  }

  Future<void> _markAllRead() async {
    final service = NotificationService.instance;
    switch (_filter) {
      case _NotificationFilter.all:
        await service.markAnnouncementRead();
        await service.markFriendRead();
        await service.markInviteRead();
        await service.markForumRead();
      case _NotificationFilter.system:
        await service.markAnnouncementRead();
      case _NotificationFilter.forum:
        await service.markForumRead();
      case _NotificationFilter.friend:
        await service.markFriendRead();
      case _NotificationFilter.group:
        await service.markInviteRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final service = NotificationService.instance;
        final colorScheme = Theme.of(context).colorScheme;
        final notifs = _source();
        final unread = notifs.where((n) => n.readAt == null).length;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 16,
                  left: 20,
                  right: 8,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.l10n.notificationTitle,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unread > 0)
                      TextButton(
                        onPressed: _markAllRead,
                        child: Text(l10n.notificationMarkAllRead),
                      ),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                  ],
                ),
              ),
              // 分类筛选
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _filterChip(_NotificationFilter.all, l10n.notificationFilterAll),
                    _filterChip(
                      _NotificationFilter.system,
                      l10n.notificationFilterSystem,
                    ),
                    _filterChip(
                      _NotificationFilter.forum,
                      l10n.notificationFilterForum,
                    ),
                    _filterChip(
                      _NotificationFilter.friend,
                      l10n.notificationFilterFriend,
                    ),
                    _filterChip(
                      _NotificationFilter.group,
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
                        title: widget.l10n.notificationEmpty,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: notifs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
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

  Future<bool> _deleteNotification(NotificationInfo notification) async {
    final l10n = AppLocalizations.of(context)!;
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: TFRadius.mdRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delete_outline,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 6),
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

  Widget _filterChip(_NotificationFilter value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
        visualDensity: VisualDensity.compact,
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
    final unread = notification.readAt == null;
    final timeLabel = _formatRelativeTime(
      context,
      notification.dateTime,
    );

    IconData icon;
    Color iconColor;
    if (notification.isFriendEvent) {
      icon = Icons.person_add;
      iconColor = colorScheme.primary;
    } else if (notification.isForumEvent) {
      icon = Icons.forum;
      iconColor = colorScheme.tertiary;
    } else if (notification.isGroupEvent) {
      icon = Icons.group;
      iconColor = colorScheme.secondary;
    } else if (notification.isAnnouncementEvent) {
      icon = Icons.campaign;
      iconColor = colorScheme.primary;
    } else if (notification.isAuthEvent) {
      icon = Icons.admin_panel_settings;
      iconColor = colorScheme.error;
    } else {
      icon = Icons.notifications;
      iconColor = colorScheme.primary;
    }

    return Card(
      margin: EdgeInsets.zero,
      color: unread
          ? colorScheme.primaryContainer.withValues(alpha: 0.28)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: TFRadius.mdRadius,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 10),
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
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: unread ? colorScheme.onSurface : iconColor,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
