import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/screens/forum_detail_screen.dart';
import 'package:touchfish_client/screens/forum_post_detail_screen.dart';
import 'package:touchfish_client/screens/forum_screen.dart';
import 'package:touchfish_client/screens/forum_section_shell.dart';
import 'package:touchfish_client/utils/wide_screen_helper.dart';
import 'package:touchfish_client/widgets/layout/section_two_pane_shell.dart';

/// 论坛区外壳：
/// - 默认「详情在左 + 空置展开栏隐藏」：论坛列表 / 论坛详情整屏，只有打开
///   帖子才分屏（左 = 帖子列表，右 = 帖子详情），退出帖子恢复整屏；
/// - 关闭隐藏空栏后始终分栏：左栏是论坛详情（可切成论坛列表）；
/// - 窄屏或「单页风格」整屏透传子路由。
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  setUp(() async {
    await SettingsService.instance.setValue('forumHideEmptyPane', true);
    await SettingsService.instance.setValue('singlePageStyle', false);
  });

  Future<void> useSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump();
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    required String location,
    required Widget child,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ForumSectionShell(location: location, child: child),
      ),
    );
    await tester.pump();
  }

  group('ForumSectionShell.parseLocation', () {
    test('parses the forum list, detail, post and search locations', () {
      expect(
        ForumSectionShell.parseLocation('/forum'),
        (forumId: null, postId: null, isSearch: false),
      );
      expect(
        ForumSectionShell.parseLocation('/forum/42'),
        (forumId: '42', postId: null, isSearch: false),
      );
      expect(
        ForumSectionShell.parseLocation('/forum/42/post/9'),
        (forumId: '42', postId: '9', isSearch: false),
      );
      expect(
        ForumSectionShell.parseLocation('/forum/search'),
        (forumId: null, postId: null, isSearch: true),
      );
    });
  });

  group('WideScreenHelper.forumKeepsListPane', () {
    Widget probe(void Function(bool) capture) => MaterialApp(
      home: Builder(
        builder: (context) {
          capture(WideScreenHelper.forumKeepsListPane(context));
          return const SizedBox.shrink();
        },
      ),
    );

    testWidgets('wide + hide empty pane: the index page is the full list', (
      tester,
    ) async {
      await useSize(tester, const Size(1200, 800));
      bool? value;
      await tester.pumpWidget(probe((v) => value = v));
      expect(value, isFalse);

      await SettingsService.instance.setValue('forumHideEmptyPane', false);
      await tester.pumpWidget(probe((v) => value = v));
      expect(value, isTrue);
    });

    testWidgets('narrow never keeps a list pane', (tester) async {
      await useSize(tester, const Size(480, 900));
      await SettingsService.instance.setValue('forumHideEmptyPane', false);
      bool? value;
      await tester.pumpWidget(probe((v) => value = v));
      expect(value, isFalse);
    });
  });

  testWidgets('defaults: the detail is full screen until a post opens', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));
    await pumpShell(
      tester,
      location: '/forum/42',
      child: const Text('post-page'),
    );

    expect(find.byType(SectionTwoPaneShell), findsOneWidget);
    expect(
      tester.widget<ForumDetailScreen>(find.byType(ForumDetailScreen)).isAside,
      isFalse,
    );
    // 整屏时不再渲染子路由里的详情页；右栏内容不出现。
    expect(find.text('post-page'), findsNothing);

    // 打开帖子：分屏，并且是同一个详情状态（不重建、不重新拉取）。
    final detailState = tester.state(find.byType(ForumDetailScreen));
    await pumpShell(
      tester,
      location: '/forum/42/post/9',
      child: const Text('post-page'),
    );

    expect(find.text('post-page'), findsOneWidget);
    expect(
      tester.widget<ForumDetailScreen>(find.byType(ForumDetailScreen)).isAside,
      isTrue,
    );
    expect(tester.state(find.byType(ForumDetailScreen)), same(detailState));

    // 退出帖子：回到整屏详情，状态依旧是同一个。
    await pumpShell(
      tester,
      location: '/forum/42',
      child: const Text('post-page'),
    );
    expect(find.text('post-page'), findsNothing);
    expect(
      tester.widget<ForumDetailScreen>(find.byType(ForumDetailScreen)).isAside,
      isFalse,
    );
    expect(tester.state(find.byType(ForumDetailScreen)), same(detailState));
  });

  testWidgets('the left pane detail knows which post is open', (tester) async {
    await useSize(tester, const Size(1200, 800));
    ForumDetailScreen detail() =>
        tester.widget<ForumDetailScreen>(find.byType(ForumDetailScreen));

    await pumpShell(
      tester,
      location: '/forum/42',
      child: const Text('post-page'),
    );
    expect(detail().openPostId, isNull);

    await pumpShell(
      tester,
      location: '/forum/42/post/9',
      child: const Text('post-page'),
    );
    expect(detail().openPostId, '9');

    // 帖子关闭：id 变回 null，详情页据此刷新列表快照。
    await pumpShell(
      tester,
      location: '/forum/42',
      child: const Text('post-page'),
    );
    expect(detail().openPostId, isNull);
  });

  testWidgets('keeping the empty pane: left detail, right post hint', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));
    await SettingsService.instance.setValue('forumHideEmptyPane', false);
    await pumpShell(
      tester,
      location: '/forum/42',
      child: const Text('post-page'),
    );

    expect(
      tester.widget<ForumDetailScreen>(find.byType(ForumDetailScreen)).isAside,
      isTrue,
    );
    expect(find.text('Select a post to read it'), findsOneWidget);
    expect(find.text('post-page'), findsNothing);
  });

  testWidgets('a selected forum always keeps its post list in the left pane', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));
    await SettingsService.instance.setValue('forumHideEmptyPane', false);
    await pumpShell(
      tester,
      location: '/forum/42/post/9',
      child: const Text('post-page'),
    );

    // 左栏是帖子列表（不是论坛列表），右栏是帖子——点下一篇不用退出详情。
    expect(find.byType(ForumScreen), findsNothing);
    expect(
      tester.widget<ForumDetailScreen>(find.byType(ForumDetailScreen)).isAside,
      isTrue,
    );
    expect(find.text('post-page'), findsOneWidget);
  });

  testWidgets('the split toggle does not remount the shell or the detail', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));
    await SettingsService.instance.setValue('forumHideEmptyPane', false);
    await pumpShell(
      tester,
      location: '/forum/42',
      child: const Text('post-page'),
    );
    final shell = tester.state(find.byType(SectionTwoPaneShell));
    final detail = tester.state(find.byType(ForumDetailScreen));

    // 收起 / 展开空置的展开栏：只是一次布局变化，不重建任何一栏。
    await SettingsService.instance.setValue('forumHideEmptyPane', true);
    await tester.pump();
    expect(tester.state(find.byType(SectionTwoPaneShell)), same(shell));
    expect(tester.state(find.byType(ForumDetailScreen)), same(detail));

    await SettingsService.instance.setValue('forumHideEmptyPane', false);
    await tester.pump();
    expect(tester.state(find.byType(SectionTwoPaneShell)), same(shell));
    expect(tester.state(find.byType(ForumDetailScreen)), same(detail));
  });

  testWidgets('the full screen button expands this post only', (tester) async {
    await useSize(tester, const Size(1200, 800));
    // 真实帖子页才带那个按钮；测试里请求必然失败，但 AppBar 照常渲染。
    Widget post(String id) => ForumPostDetailScreen(
      key: ValueKey('post-42-$id'),
      forumId: '42',
      postId: id,
    );
    bool split() => tester
        .widget<SectionTwoPaneShell>(find.byType(SectionTwoPaneShell))
        .twoPane;

    await pumpShell(tester, location: '/forum/42/post/1', child: post('1'));
    expect(split(), isTrue);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);

    // 点右上角的整屏按钮：帖子独占整屏（即原来的整页效果）。
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    expect(split(), isFalse);
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

    // 换一篇帖子：整屏只是"这一次查看"的临时状态，新帖子回到分屏。
    await pumpShell(tester, location: '/forum/42/post/2', child: post('2'));
    expect(split(), isTrue);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('narrow passes the route content through', (tester) async {
    await useSize(tester, const Size(480, 900));
    await pumpShell(
      tester,
      location: '/forum/42/post/9',
      child: const Text('post-page'),
    );

    expect(find.byType(ForumScreen), findsNothing);
    expect(find.byType(ForumDetailScreen), findsNothing);
    expect(find.text('post-page'), findsOneWidget);
  });

  testWidgets('single-page style passes the route content through', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));
    await SettingsService.instance.setValue('singlePageStyle', true);
    await pumpShell(
      tester,
      location: '/forum/42/post/9',
      child: const Text('post-page'),
    );

    expect(find.byType(ForumDetailScreen), findsNothing);
    expect(find.text('post-page'), findsOneWidget);
  });

  testWidgets('leaving a post returns to the forum, not to the previous post', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));

    // 详情页会一直转圈（测试里请求必然失败），不能用 pumpAndSettle。
    Future<void> settle() async {
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final router = GoRouter(
      initialLocation: '/forum/42',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              ForumSectionShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/forum',
              builder: (_, _) => const Text('forum-index'),
              routes: [
                GoRoute(
                  path: ':forumId',
                  builder: (context, state) => ForumDetailScreen(
                    forumId: state.pathParameters['forumId']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'post/:postId',
                      builder: (context, state) => Text(
                        'post-${state.pathParameters['postId']}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await settle();

    expect(
      tester.widget<ForumDetailScreen>(find.byType(ForumDetailScreen)).isAside,
      isFalse,
    );

    // 分屏下点开帖子是 go（替换），所以第二个帖子不会叠在第一个上面。
    router.go('/forum/42/post/1');
    await settle();
    expect(find.text('post-1'), findsOneWidget);

    router.go('/forum/42/post/2');
    await settle();
    expect(find.text('post-2'), findsOneWidget);
    expect(find.text('post-1'), findsNothing);

    // 退出帖子（与 ForumPostDetailScreen._leavePost 的兜底一致）。
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/forum/42');
    }
    await settle();
    expect(find.text('post-1'), findsNothing);
    expect(find.text('post-2'), findsNothing);
    expect(find.byType(ForumDetailScreen), findsOneWidget);
    expect(
      tester.widget<ForumDetailScreen>(find.byType(ForumDetailScreen)).isAside,
      isFalse,
    );
  });
}
