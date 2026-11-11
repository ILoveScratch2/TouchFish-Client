import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../widgets/account/inbox_summary_card.dart';
import '../models/user_profile.dart';
import '../widgets/account/account_name.dart';
import '../widgets/account/account_friends_section.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/account/signature_editor.dart';
import '../routes/app_routes.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../services/notification_service.dart';
import '../services/ticket_inbox_service.dart';
import '../services/snackbar_service.dart';
import '../services/lock_service.dart';
import '../widgets/app_alert_dialog.dart';
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

  int _ticketUnread = 0;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
    TicketInboxService.instance.addListener(_onTicketInboxChanged);
    _loadUser();
    _silentRefresh();
    _refreshTicketUnread();
  }

  void _onTicketInboxChanged() {
    // 推迟到当前帧结束
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final unread = TicketInboxService.instance.unreadCount;
      if (unread != _ticketUnread) setState(() => _ticketUnread = unread);
    });
  }

  Future<void> _refreshTicketUnread() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final unread = await TfApiClient.instance.getTicketUnreadCount(
      uid,
      password,
    );
    if (!mounted) return;
    setState(() => _ticketUnread = unread);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    TicketInboxService.instance.removeListener(_onTicketInboxChanged);
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

  /// 打开通知中心
  void _openNotifications(BuildContext context) {
    context.push(AppRoutes.notifications);
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
      // 登出会全部重建
      if (!mounted) return;
      setState(() => _currentUser = null);
      GoRouter.of(context).go(AppRoutes.login);
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
        leading: const Icon(Symbols.support_agent, size: 24),
        title: Text(l10n.ticketFeedback),
        subtitle: _ticketUnread > 0
            ? Text(
                l10n.ticketUnreadReplies(_ticketUnread),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : null,
        onTap: () async {
          await context.push(AppRoutes.tickets);
          if (mounted) await _refreshTicketUnread();
        },
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
        onTap: () => _openNotifications(context),
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
