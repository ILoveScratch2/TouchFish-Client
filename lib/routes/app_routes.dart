import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/register_screen.dart';
import '../screens/register_step2_screen.dart';
import '../screens/register_step3_screen.dart';
import '../screens/register_success_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/chat_detail_screen.dart';
import '../screens/announcement_screen.dart';
import '../screens/forum_screen.dart';
import '../screens/forum_detail_screen.dart';
import '../screens/forum_post_detail_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/account_screen.dart';
import '../screens/pending_forums_screen.dart';
import '../screens/default_assets_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/about_screen.dart';
import '../screens/licenses_screen.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/server_settings_screen.dart';
import '../screens/account_management_screen.dart';
import '../screens/sticker_screens.dart';
import '../screens/forum_search_screen.dart';
import '../screens/group_search_screen.dart';
import '../screens/group_profile_screen.dart';
import '../screens/forward_screen.dart';
import '../models/message_model.dart';
import '../services/auth_state.dart';
import '../widgets/window_frame.dart';
import '../utils/talker.dart';

class AppRoutes {
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String main = '/';
  static const String chat = '/chat';
  static const String chatDetail = '/chat/:roomId';
  static const String announcement = '/announcement';
  static const String forum = '/forum';
  static const String forumDetail = '/forum/:forumId';
  static const String forumPostDetail = '/forum/:forumId/post/:postId';
  static const String forumSearch = '/forum/search';
  static const String groupSearch = '/group/search';
  static const String groupProfile = '/group/:gid';
  static const String forward = '/forward';
  static const String account = '/account';
  static const String admin = '/admin';
  static const String adminPendingForums = '/admin/pending-forums';
  static const String adminDefaultAssets = '/admin/default-assets';
  static const String adminServerSettings = '/admin/server-settings';
  static const String adminAccountManagement = '/admin/account-management';
  static const String settings = '/settings';
  static const String register = '/register';
  static const String registerStep2 = '/register/step2';
  static const String registerStep3 = '/register/step3';
  static const String registerSuccess = '/register/success';
  static const String userProfile = '/user/:userId';
  static const String about = '/about';
  static const String licenses = '/licenses';
  static const String profileEdit = '/profile/edit';
  static const String stickerMarket = '/stickers';
  static const String myStickers = '/stickers/mine';

  static const _publicPaths = {
    welcome,
    login,
    settings,
    register,
    registerStep2,
    registerStep3,
    registerSuccess,
    about,
    licenses,
  };

  static Page<void> _mainSectionPage(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      reverseTransitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reduceMotion) return child;
        final isWide = MediaQuery.sizeOf(context).width >= 600;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: isWide ? const Offset(0, 0.06) : const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @visibleForTesting
  static String? authRedirect({
    required String path,
    required bool isLoggedIn,
    required bool isRestoringSavedSession,
  }) {
    if (isLoggedIn || isRestoringSavedSession || _publicPaths.contains(path)) {
      return null;
    }
    return login;
  }

  @visibleForTesting
  static bool isValidRegisterStep2Extra(Object? extra) {
    return extra is Map<String, dynamic> &&
        extra['username'] is String &&
        extra['password'] is String &&
        (extra['requiresEmail'] == null || extra['requiresEmail'] is bool) &&
        (extra['captchaStamp'] == null || extra['captchaStamp'] is String) &&
        (extra['captchaCode'] == null || extra['captchaCode'] is String);
  }

  @visibleForTesting
  static bool isValidRegisterStep3Extra(Object? extra) {
    return extra is Map<String, dynamic> &&
        extra['username'] is String &&
        extra['uid'] is int;
  }

  static GoRouter createRouter({
    required bool isFirstLaunch,
    required bool hasSavedSession,
  }) {
    final router = GoRouter(
      initialLocation: isFirstLaunch
          ? welcome
          : (hasSavedSession ? main : login),
      refreshListenable: AuthState.instance,
      redirect: (context, state) {
        final auth = AuthState.instance;
        final restoringSavedSession =
            auth.hasStoredCredentials && !auth.isLoggedIn;
        return authRedirect(
          path: state.uri.path,
          isLoggedIn: auth.isLoggedIn,
          isRestoringSavedSession: restoringSavedSession,
        );
      },
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return WindowFrame(child: child);
          },
          routes: [
            GoRoute(
              path: welcome,
              builder: (context, state) => const WelcomeScreen(),
            ),
            GoRoute(
              path: login,
              builder: (context, state) => const LoginScreen(),
            ),
            GoRoute(
              path: settings,
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: register,
              builder: (context, state) {
                final args = state.extra;
                final username = args is Map ? args['username'] : null;
                final password = args is Map ? args['password'] : null;
                return RegisterScreen(
                  initialUsername: username is String ? username : null,
                  initialPassword: password is String ? password : null,
                );
              },
            ),
            GoRoute(
              path: registerStep2,
              redirect: (context, state) =>
                  isValidRegisterStep2Extra(state.extra) ? null : register,
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>;
                return RegisterStep2Screen(
                  username: args['username'] as String,
                  password: args['password'] as String,
                  requiresEmail: args['requiresEmail'] as bool? ?? false,
                  captchaStamp: args['captchaStamp'] as String?,
                  captchaCode: args['captchaCode'] as String?,
                );
              },
            ),
            GoRoute(
              path: registerStep3,
              redirect: (context, state) =>
                  isValidRegisterStep3Extra(state.extra) ? null : register,
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>;
                return RegisterStep3Screen(
                  username: args['username'] as String,
                  uid: args['uid'] as int,
                );
              },
            ),
            GoRoute(
              path: registerSuccess,
              builder: (context, state) => const RegisterSuccessScreen(),
            ),
            GoRoute(
              path: '/user/:userId',
              builder: (context, state) {
                final userId = state.pathParameters['userId']!;
                return UserProfileScreen(userId: userId);
              },
            ),
            GoRoute(
              path: about,
              builder: (context, state) => const AboutScreen(),
            ),
            GoRoute(
              path: licenses,
              builder: (context, state) => const LicensesScreen(),
            ),
            GoRoute(
              path: profileEdit,
              builder: (context, state) => const ProfileEditScreen(),
            ),
            GoRoute(
              path: forumSearch,
              builder: (context, state) => const ForumSearchScreen(),
            ),
            GoRoute(
              path: groupSearch,
              builder: (context, state) => const GroupSearchScreen(),
            ),
            GoRoute(
              path: forward,
              builder: (context, state) {
                final args = state.extra;
                final message = args is ChatMessage ? args : null;
                return ForwardScreen(message: message!);
              },
            ),
            GoRoute(
              path: groupProfile,
              builder: (context, state) {
                final gid = state.pathParameters['gid']!;
                final args = state.extra;
                final Map<String, dynamic>? initialData = args is Map
                    ? args['initialData'] as Map<String, dynamic>?
                    : null;
                final String? groupName =
                    args is Map ? args['groupName'] as String? : null;
                return GroupProfileScreen(
                  gid: gid,
                  initialData: initialData,
                  initialGroupName: groupName,
                );
              },
            ),
            GoRoute(
              path: '/forum/:forumId',
              builder: (context, state) {
                final forumId = state.pathParameters['forumId']!;
                return ForumDetailScreen(forumId: forumId);
              },
            ),
            GoRoute(
              path: '/forum/:forumId/post/:postId',
              builder: (context, state) {
                final forumId = state.pathParameters['forumId']!;
                final postId = state.pathParameters['postId']!;
                return ForumPostDetailScreen(forumId: forumId, postId: postId);
              },
            ),
            ShellRoute(
              builder: (context, state, child) {
                return MainScreen(child: child);
              },
              routes: [
                GoRoute(
                  path: main,
                  pageBuilder: (context, state) {
                    final isWide = MediaQuery.of(context).size.width >= 600;
                    final placeholder = ChatShellScreen(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                          child: Text(
                            '选择一个聊天开始对话',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                    // 宽的时候没动画（不然很奇怪）
                    return isWide
                        ? NoTransitionPage(
                            key: state.pageKey,
                            child: placeholder,
                          )
                        : _mainSectionPage(context, state, placeholder);
                  },
                ),
                GoRoute(
                  path: chat,
                  pageBuilder: (context, state) {
                    final isWide = MediaQuery.of(context).size.width >= 600;
                    final placeholder = ChatShellScreen(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                          child: Text(
                            '选择一个聊天开始对话',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                    return isWide
                        ? NoTransitionPage(
                            key: state.pageKey,
                            child: placeholder,
                          )
                        : _mainSectionPage(context, state, placeholder);
                  },
                ),
                GoRoute(
                  path: '/chat/:roomId',
                  pageBuilder: (context, state) {
                    final roomId = state.pathParameters['roomId']!;
                    final isWide = MediaQuery.of(context).size.width >= 600;
                    final shell = ChatShellScreen(
                      child: ChatDetailScreen(
                        key: ValueKey(roomId),
                        roomId: roomId,
                      ),
                    );
                    // 宽的时候没动画（不然很奇怪）
                    // 窄的时候才能德芙纵享丝滑
                    return isWide
                        ? NoTransitionPage(key: state.pageKey, child: shell)
                        : MaterialPage(child: shell);
                  },
                ),
                GoRoute(
                  path: announcement,
                  pageBuilder: (context, state) => _mainSectionPage(
                    context,
                    state,
                    const AnnouncementScreen(),
                  ),
                ),
                GoRoute(
                  path: forum,
                  pageBuilder: (context, state) =>
                      _mainSectionPage(context, state, const ForumScreen()),
                ),
                GoRoute(
                  path: account,
                  pageBuilder: (context, state) =>
                      _mainSectionPage(context, state, const AccountScreen()),
                ),
                GoRoute(
                  path: stickerMarket,
                  builder: (context, state) => const StickerMarketplaceScreen(),
                ),
                GoRoute(
                  path: myStickers,
                  builder: (context, state) => const MyStickerPacksScreen(),
                ),
                GoRoute(
                  path: admin,
                  redirect: (context, state) {
                    return AuthState.instance.currentUser?.hasAdminAccess ==
                            true
                        ? null
                        : AppRoutes.account;
                  },
                  pageBuilder: (context, state) =>
                      _mainSectionPage(context, state, const AdminScreen()),
                ),
                GoRoute(
                  path: adminPendingForums,
                  redirect: (context, state) {
                    return AuthState.instance.currentUser?.hasAdminAccess ==
                            true
                        ? null
                        : AppRoutes.account;
                  },
                  pageBuilder: (context, state) => _mainSectionPage(
                    context,
                    state,
                    const PendingForumsScreen(),
                  ),
                ),
                GoRoute(
                  path: adminDefaultAssets,
                  redirect: (context, state) {
                    return AuthState.instance.currentUser?.hasAdminAccess ==
                            true
                        ? null
                        : AppRoutes.account;
                  },
                  pageBuilder: (context, state) => _mainSectionPage(
                    context,
                    state,
                    const DefaultAssetsScreen(),
                  ),
                ),
                GoRoute(
                  path: adminServerSettings,
                  redirect: (context, state) {
                    return AuthState.instance.currentUser?.isRoot == true
                        ? null
                        : AppRoutes.admin;
                  },
                  pageBuilder: (context, state) => _mainSectionPage(
                    context,
                    state,
                    const ServerSettingsScreen(),
                  ),
                ),
                GoRoute(
                  path: adminAccountManagement,
                  redirect: (context, state) {
                    return AuthState.instance.currentUser?.hasAdminAccess ==
                            true
                        ? null
                        : AppRoutes.account;
                  },
                  pageBuilder: (context, state) => _mainSectionPage(
                    context,
                    state,
                    const AccountManagementScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    String? previousUri;
    router.routerDelegate.addListener(() {
      final uri = router.routerDelegate.currentConfiguration.uri.toString();
      if (uri != previousUri) {
        talker.debug('Route: $previousUri -> $uri');
        previousUri = uri;
      }
    });

    return router;
  }
}
