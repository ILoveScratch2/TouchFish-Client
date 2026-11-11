import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/routes/app_routes.dart';
import 'package:touchfish_client/screens/forum_detail_screen.dart';
import 'package:touchfish_client/screens/forum_post_detail_screen.dart';

/// 真实论坛路由表（`AppRoutes.forumSectionRoutes`）：
/// 换论坛 / 换帖子必须重建页面 State。
///
/// 嵌套路由只换 path 参数时 Flutter 会复用同一个 State（`initState` 不再跑），
/// 页面就会停在上一个帖子 / 上一个论坛的数据上——在分屏里表现为
/// "点了左侧另一个帖子，右栏不切换"。
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  setUp(() async {
    await SettingsService.instance.setValue('forumHideEmptyPane', true);
    await SettingsService.instance.setValue('singlePageStyle', false);
  });

  GoRouter buildRouter(String initial) => GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: AppRoutes.forumSectionRoutes(),
      ),
    ],
  );

  Future<void> pumpRouter(
    WidgetTester tester,
    GoRouter router,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
    // 论坛页会一直转圈（测试里请求必然失败），不能用 pumpAndSettle。
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('switching posts in the split rebuilds the post page', (
    tester,
  ) async {
    final router = buildRouter('/forum/42/post/1');
    await pumpRouter(tester, router, const Size(1200, 800));

    expect(find.byType(ForumPostDetailScreen), findsOneWidget);
    final first = tester.state(find.byType(ForumPostDetailScreen));

    router.go('/forum/42/post/2');
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      tester.widget<ForumPostDetailScreen>(find.byType(ForumPostDetailScreen))
          .postId,
      '2',
    );
    expect(tester.state(find.byType(ForumPostDetailScreen)), isNot(same(first)));
  });

  testWidgets('switching forums rebuilds the detail (wide, shell-owned)', (
    tester,
  ) async {
    final router = buildRouter('/forum/42');
    await pumpRouter(tester, router, const Size(1200, 800));

    expect(find.byType(ForumDetailScreen), findsOneWidget);
    final first = tester.state(find.byType(ForumDetailScreen));

    router.go('/forum/43');
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      tester.widget<ForumDetailScreen>(find.byType(ForumDetailScreen)).forumId,
      '43',
    );
    expect(tester.state(find.byType(ForumDetailScreen)), isNot(same(first)));
  });

  testWidgets('switching forums rebuilds the detail (narrow, route page)', (
    tester,
  ) async {
    final router = buildRouter('/forum/42');
    await pumpRouter(tester, router, const Size(480, 900));

    final first = tester.state(find.byType(ForumDetailScreen));

    router.go('/forum/43');
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.state(find.byType(ForumDetailScreen)), isNot(same(first)));
  });
}
