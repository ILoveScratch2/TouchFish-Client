import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../widgets/account/account_name.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/account/signature_editor.dart';
import '../routes/app_routes.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../utils/talker.dart';
import '../widgets/app_alert_dialog.dart';
import 'debug/debug_options_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // user state
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _silentRefresh();
  }

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

  void _updateSignature(String newSignature) {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    TfApiClient.instance
        .changeSign(uid, password, newSignature)
        .then((success) {
          if (!mounted) return;
          if (success) {
            AuthState.instance.refreshProfile().then((_) {
              if (!mounted) return;
              setState(() => _currentUser = AuthState.instance.currentUser);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.accountUpdateSignature,
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        })
        .catchError((e) {
          talker.error('_updateSignature failed', e);
        });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

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
                      _buildSignatureCard(context),
                      _buildActionButtons(context, isWide),
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
      },
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
                        Text(
                          user.personalSign?.isNotEmpty == true
                              ? user.personalSign!
                              : AppLocalizations.of(
                                  context,
                                )!.accountDescriptionNone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildSignatureCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: SignatureEditorWidget(
          currentSignature: _currentUser?.personalSign,
          onUpdate: _updateSignature,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isWide) {
    final l10n = AppLocalizations.of(context)!;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minWidth = 160.0;
          const spacing = 8.0;
          const padding = 24.0;
          final availableWidth = constraints.maxWidth - padding;

          final children = <Widget>[
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      const Icon(Symbols.settings, size: 20),
                      Flexible(
                        child: Text(
                          l10n.accountAppSettings,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () => context.push(AppRoutes.settings),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      const Icon(Symbols.person_edit, size: 20),
                      Flexible(
                        child: Text(
                          l10n.accountUpdateYourProfile,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  context.push(AppRoutes.profileEdit);
                },
              ),
            ),
          ];

          if (_currentUser?.hasAdminAccess == true) {
            children.add(
              Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined, size: 20),
                        Flexible(
                          child: Text(
                            l10n.navAdmin,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () => context.push(AppRoutes.admin),
                ),
              ),
            );
          }

          final totalMin =
              children.length * minWidth +
              (children.length > 1 ? (children.length - 1) * spacing : 0);

          if (availableWidth > totalMin) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 48,
                child: Row(
                  spacing: 8,
                  children: children
                      .map((child) => Expanded(child: child))
                      .toList(),
                ),
              ),
            );
          } else {
            return SizedBox(
              height: 48,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    spacing: 8,
                    children: children
                        .map((child) => SizedBox(width: minWidth, child: child))
                        .toList(),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final menuItems = [
      {
        'icon': Symbols.notifications,
        'title': l10n.accountNotifications,
        'onTap': () {
          // 通知？也没有的
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountNotifications),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      },
    ];

    return Column(
      children: menuItems.map((item) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          trailing: const Icon(Symbols.chevron_right),
          dense: true,
          leading: Icon(item['icon'] as IconData, size: 24),
          title: Text(item['title'] as String),
          onTap: item['onTap'] as VoidCallback,
        );
      }).toList(),
    );
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
