import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../widgets/account/account_name.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/account/signature_editor.dart';
import '../routes/app_routes.dart';
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
    // login launch!
    _loadUser();
  }

  void _loadUser() {
    // 还没做登录
    setState(() {
      _currentUser = UserProfileDemoData.getDemoProfile('1');
    });
  }

  void _logout() async {
    // 登出肯定也没做的
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountLogout),
        content: Text(l10n.accountLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.accountLogout),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _currentUser = null;
      });
      
      // 应该清除数据的，但现在直接跳转到登录界面，因为根本没有好吧
      if (mounted) {
        GoRouter.of(context).go(AppRoutes.login);
      }
    }
  }

  void _updateSignature(String newSignature) {
    // 签名修改诶！但是也没做
    setState(() {
      _currentUser = UserProfile(
        uid: _currentUser!.uid,
        username: _currentUser!.username,
        email: _currentUser!.email,
        stat: _currentUser!.stat,
        createTime: _currentUser!.createTime,
        personalSign: newSignature,
        introduction: _currentUser!.introduction,
        avatar: _currentUser!.avatar,
      );
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.accountUpdateSignature),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            toolbarHeight: 0,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom,
              ),
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
        );
      },
    );
  }

  Widget _buildUnauthorizedScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.account),
      ),
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
                        Row(
                          spacing: 4,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: AccountNameWidget(
                                account: user,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 2.5),
                                child: Text(
                                  '@${user.username}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          user.personalSign?.isNotEmpty == true
                              ? user.personalSign!
                              : AppLocalizations.of(context)!.accountDescriptionNone,
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
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minWidth = 160.0;
          const spacing = 8.0;
          const padding = 24.0;
          final totalMin = 3 * minWidth + 2 * spacing;
          final availableWidth = constraints.maxWidth - padding;
          
          final children = [
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    spacing: 8,
                    children: [
                      const Icon(Symbols.manage_accounts, size: 20),
                      Flexible(
                        child: Text(
                          l10n.accountSettings,
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
                  // 也没有账户设置界面
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.accountSettings),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ];
          
          if (availableWidth > totalMin) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 48,
                child: Row(
                  spacing: 8,
                  children: children.map((child) => Expanded(child: child)).toList(),
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
