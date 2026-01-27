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
import '../screens/announcement_screen.dart';
import '../screens/forum_screen.dart';
import '../screens/account_screen.dart';
import '../widgets/window_frame.dart';

class AppRoutes {
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String main = '/';
  static const String chat = '/chat';
  static const String announcement = '/announcement';
  static const String forum = '/forum';
  static const String account = '/account';
  static const String settings = '/settings';
  static const String register = '/register';
  static const String registerStep2 = '/register/step2';
  static const String registerStep3 = '/register/step3';
  static const String registerSuccess = '/register/success';

  static GoRouter createRouter({required bool isFirstLaunch}) {
    return GoRouter(
      initialLocation: isFirstLaunch ? welcome : login,
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
                final args = state.extra as Map<String, String?>?;
                return RegisterScreen(
                  initialUsername: args?['username'],
                  initialPassword: args?['password'],
                );
              },
            ),
            GoRoute(
              path: registerStep2,
              builder: (context, state) {
                final args = state.extra as Map<String, String>;
                return RegisterStep2Screen(
                  username: args['username']!,
                  password: args['password']!,
                );
              },
            ),
            GoRoute(
              path: registerStep3,
              builder: (context, state) {
                final args = state.extra as Map<String, String>;
                return RegisterStep3Screen(
                  username: args['username']!,
                  password: args['password']!,
                  email: args['email']!,
                );
              },
            ),
            GoRoute(
              path: registerSuccess,
              builder: (context, state) => const RegisterSuccessScreen(),
            ),
            ShellRoute(
              builder: (context, state, child) {
                return MainScreen(child: child);
              },
              routes: [
                GoRoute(
                  path: main,
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: ChatScreen(),
                  ),
                ),
                GoRoute(
                  path: chat,
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: ChatScreen(),
                  ),
                ),
                GoRoute(
                  path: announcement,
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: AnnouncementScreen(),
                  ),
                ),
                GoRoute(
                  path: forum,
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: ForumScreen(),
                  ),
                ),
                GoRoute(
                  path: account,
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: AccountScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
