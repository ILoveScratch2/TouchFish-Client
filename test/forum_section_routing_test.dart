import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/widgets/layout/section_two_pane_shell.dart';

/// 镜像 `AppRoutes` 中论坛区的嵌套路由结构，验证：
/// - `search` 静态段优先于 `:forumId` 动态段；
/// - 详情/发帖是 `/forum` 的嵌套子路由（进入时不重建常驻列表壳）；
/// - 宽屏下左侧列表常驻、右侧切换详情；窄屏透传。
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  GoRouter buildRouter(GlobalKey<State<SectionTwoPaneShell>> shellKey) {
    return GoRouter(
      initialLocation: '/forum',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            ShellRoute(
              builder: (context, state, child) =>
                  SectionTwoPaneShell(
                key: shellKey,
                storageKeyPrefix: 'forum_test',
                list: const Text('forum-list'),
                child: child,
              ),
              routes: [
                GoRoute(
                  path: '/forum',
                  builder: (_, _) => const Text('forum-index'),
                  routes: [
                    GoRoute(
                      path: 'search',
                      builder: (_, _) => const Text('forum-search'),
                    ),
                    GoRoute(
                      path: ':forumId',
                      builder: (context, state) => Text(
                        'forum-detail-${state.pathParameters['forumId']}',
                      ),
                      routes: [
                        GoRoute(
                          path: 'post/:postId',
                          builder: (context, state) => Text(
                            'post-${state.pathParameters['forumId']}-'
                            '${state.pathParameters['postId']}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> useWide(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump();
  }

  Future<void> useNarrow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump();
  }

  testWidgets('static /forum/search wins over :forumId', (tester) async {
    await useWide(tester);
    final router = buildRouter(GlobalKey<State<SectionTwoPaneShell>>());
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/forum/search');
    await tester.pumpAndSettle();
    expect(find.text('forum-search'), findsOneWidget);
    expect(find.text('forum-detail-search'), findsNothing);
  });

  testWidgets('wide: detail/post render in right pane, list stays mounted',
      (tester) async {
    await useWide(tester);
    final shellKey = GlobalKey<State<SectionTwoPaneShell>>();
    final router = buildRouter(shellKey);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('forum-index'), findsOneWidget);
    expect(find.text('forum-list'), findsOneWidget);
    final shellBefore = shellKey.currentState;

    router.go('/forum/F1');
    await tester.pumpAndSettle();
    expect(find.text('forum-detail-F1'), findsOneWidget);
    // 壳未重建，左侧列表常驻
    expect(shellKey.currentState, same(shellBefore));
    expect(find.text('forum-list'), findsOneWidget);

    router.go('/forum/F1/post/P9');
    await tester.pumpAndSettle();
    expect(find.text('post-F1-P9'), findsOneWidget);
    expect(shellKey.currentState, same(shellBefore));

    router.go('/forum');
    await tester.pumpAndSettle();
    expect(find.text('forum-index'), findsOneWidget);
    expect(shellKey.currentState, same(shellBefore));
  });

  testWidgets('narrow: shell passes through, no persistent list',
      (tester) async {
    await useNarrow(tester);
    final router = buildRouter(GlobalKey<State<SectionTwoPaneShell>>());
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('forum-index'), findsOneWidget);
    expect(find.text('forum-list'), findsNothing);

    router.go('/forum/F1');
    await tester.pumpAndSettle();
    expect(find.text('forum-detail-F1'), findsOneWidget);
    expect(find.text('forum-list'), findsNothing);
  });
}
