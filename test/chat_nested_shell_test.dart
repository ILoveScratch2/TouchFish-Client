import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/screens/chat_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  Widget wrap(GoRouter router) {
    return MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  GoRouter buildRouter(GlobalKey<State<ChatShellScreen>> shellKey) {
    return GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            ShellRoute(
              builder: (context, state, child) =>
                  ChatShellScreen(key: shellKey, child: child),
              routes: [
                GoRoute(path: '/', redirect: (_, _) => '/chat'),
                GoRoute(
                  path: '/chat',
                  builder: (_, _) => const Text('index-chat'),
                  routes: [
                    GoRoute(
                      path: ':roomId',
                      builder: (context, state) =>
                          Text('detail-${state.pathParameters['roomId']}'),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(path: '/forum', builder: (_, _) => const Text('forum')),
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

  testWidgets('wide: entering a chat room keeps the shell (list) mounted',
      (tester) async {
    await useWide(tester);
    final shellKey = GlobalKey<State<ChatShellScreen>>();
    final router = buildRouter(shellKey);
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();

    // '/' redirect 到 '/chat' 索引页
    expect(find.text('index-chat'), findsOneWidget);
    // 宽屏下聊天列表常驻在左侧
    expect(find.byType(ChatListScreen), findsOneWidget);
    final shellBefore = shellKey.currentState;
    expect(shellBefore, isNotNull);

    // 打开聊天房间：URL 前进到 /chat/:roomId
    router.go('/chat/U42');
    await tester.pumpAndSettle();

    expect(find.text('detail-U42'), findsOneWidget);
    // 关键：ChatShellScreen 未重建，左侧列表仍在
    expect(shellKey.currentState, same(shellBefore));
    expect(find.byType(ChatListScreen), findsOneWidget);

    // 切换另一个房间同样保持常驻
    router.go('/chat/G7');
    await tester.pumpAndSettle();
    expect(find.text('detail-G7'), findsOneWidget);
    expect(shellKey.currentState, same(shellBefore));

    // 返回列表页：索引页保持常驻（无重建、无重放进入动画）
    router.go('/chat');
    await tester.pumpAndSettle();
    expect(find.text('index-chat'), findsOneWidget);
    expect(shellKey.currentState, same(shellBefore));
  });

  testWidgets('narrow: shell passes through to the inner page', (tester) async {
    await useNarrow(tester);
    final shellKey = GlobalKey<State<ChatShellScreen>>();
    final router = buildRouter(shellKey);
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();

    expect(find.text('index-chat'), findsOneWidget);
    // 窄屏不渲染侧栏列表
    expect(find.byType(ChatListScreen), findsNothing);

    router.go('/chat/U1');
    await tester.pumpAndSettle();
    expect(find.text('detail-U1'), findsOneWidget);
  });

  testWidgets('narrow: detail back keeps the index page mounted',
      (tester) async {
    await useNarrow(tester);
    final shellKey = GlobalKey<State<ChatShellScreen>>();
    final router = buildRouter(shellKey);
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();

    // 给索引页挂一个可追踪状态的探针
    // （此测试通过 index widget 的 GlobalKey State 身份判断是否重建）
    final indexKey = GlobalKey<_IndexProbeState>();
    final probeRouter = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            ShellRoute(
              builder: (context, state, child) =>
                  ChatShellScreen(key: shellKey, child: child),
              routes: [
                GoRoute(path: '/', redirect: (_, _) => '/chat'),
                GoRoute(
                  path: '/chat',
                  builder: (_, _) =>
                      _IndexProbe(probeKey: indexKey, label: 'index-chat'),
                  routes: [
                    GoRoute(
                      path: ':roomId',
                      builder: (context, state) =>
                          Text('detail-${state.pathParameters['roomId']}'),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(path: '/forum', builder: (_, _) => const Text('forum')),
          ],
        ),
      ],
    );
    await tester.pumpWidget(wrap(probeRouter));
    await tester.pumpAndSettle();
    expect(indexKey.currentState, isNotNull);
    final indexBefore = indexKey.currentState;

    probeRouter.go('/chat/U1');
    await tester.pumpAndSettle();
    expect(find.text('detail-U1'), findsOneWidget);

    probeRouter.go('/chat');
    await tester.pumpAndSettle();
    expect(find.text('index-chat'), findsOneWidget);
    // 关键：索引页（列表）没有被重建
    expect(indexKey.currentState, same(indexBefore));
  });

  testWidgets('leaving and returning to the chat section remounts the shell',
      (tester) async {
    await useWide(tester);
    final shellKey = GlobalKey<State<ChatShellScreen>>();
    final router = buildRouter(shellKey);
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();

    final shellBefore = shellKey.currentState;
    router.go('/forum');
    await tester.pumpAndSettle();
    expect(find.text('forum'), findsOneWidget);
    expect(shellKey.currentState, isNull);

    router.go('/chat');
    await tester.pumpAndSettle();
    expect(find.text('index-chat'), findsOneWidget);
    expect(shellKey.currentState, isNotNull);
    expect(shellKey.currentState, isNot(same(shellBefore)));
  });

  testWidgets('narrow: entering chat from the right-side tab slides in '
      'from the left', (tester) async {
    await useNarrow(tester);
    final shellKey = GlobalKey<State<ChatShellScreen>>();
    final router = GoRouter(
      initialLocation: '/announcement',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/announcement',
              builder: (_, _) => const Text('announcement'),
            ),
            ShellRoute(
              builder: (context, state, child) =>
                  ChatShellScreen(key: shellKey, child: child),
              routes: [
                GoRoute(path: '/', redirect: (_, _) => '/chat'),
                GoRoute(
                  path: '/chat',
                  builder: (_, _) => const Text('index-chat'),
                  routes: [
                    GoRoute(
                      path: ':roomId',
                      builder: (context, state) =>
                          Text('detail-${state.pathParameters['roomId']}'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();

    router.go('/chat');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // 动画进行中：ChatShellScreen 整体应从左侧（dx<0）向右滑入
    final slide = tester.widget<SlideTransition>(
      find
          .descendant(
            of: find.byType(ChatShellScreen),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(slide.position.value.dx, lessThan(0));
    await tester.pumpAndSettle();
    expect(find.text('index-chat'), findsOneWidget);
  });
}

class _IndexProbe extends StatefulWidget {
  final GlobalKey<_IndexProbeState> probeKey;
  final String label;
  const _IndexProbe({required this.probeKey, required this.label})
      : super(key: probeKey);

  @override
  State<_IndexProbe> createState() => _IndexProbeState();
}

class _IndexProbeState extends State<_IndexProbe> {
  int mounts = 0;

  @override
  void initState() {
    super.initState();
    mounts++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}
