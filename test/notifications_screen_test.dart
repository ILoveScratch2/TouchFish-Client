import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/notification_model.dart';
import 'package:touchfish_client/screens/notifications_screen.dart';
import 'package:touchfish_client/services/notification_service.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ok render empty state notification', (tester) async {
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
        GoRoute(path: '/account', builder: (_, _) => const Scaffold(body: SizedBox())),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('返回'), findsOneWidget);
    expect(
      find.text('公告、处罚、好友申请等系统通知都会出现在这里'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter for all notification', (tester) async {
    NotificationService.instance.debugReplaceNotifications([
      NotificationInfo(
        id: 1,
        timeStamp: 1,
        event: 'punishment.created',
        title: '你收到一条警告',
        content: '理由：刷屏',
        meta: const {'punishment_id': 1},
      ),
      NotificationInfo(
        id: 2,
        timeStamp: 2,
        event: 'forum.post.deleted',
        title: '帖子已删除',
        content: '内容',
      ),
      NotificationInfo(
        id: 3,
        timeStamp: 3,
        event: 'custom.thing',
        title: '自定义事件',
        content: '任意类型也要能显示',
      ),
    ]);

    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
        GoRoute(path: '/account', builder: (_, _) => const Scaffold(body: SizedBox())),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '构建期不应有异常');
    expect(find.text('你收到一条警告'), findsOneWidget);
    expect(find.text('帖子已删除'), findsOneWidget);
    expect(find.text('自定义事件'), findsOneWidget);

    expect(find.text('其它'), findsOneWidget);

    expect(find.text('共 3 条 · 未读 3 条'), findsOneWidget);


    await tester.tap(find.widgetWithText(FilterChip, '系统'));
    await tester.pumpAndSettle();
    expect(find.text('你收到一条警告'), findsOneWidget);
    expect(find.text('自定义事件'), findsOneWidget);
    expect(find.text('帖子已删除'), findsNothing);


    await tester.tap(find.widgetWithText(FilterChip, '论坛'));
    await tester.pumpAndSettle();
    expect(find.text('帖子已删除'), findsOneWidget);
    expect(find.text('你收到一条警告'), findsNothing);

    NotificationService.instance.debugReplaceNotifications(const []);
  });

  testWidgets('read notifications still appear in the list', (tester) async {
    NotificationService.instance.debugReplaceNotifications([
      NotificationInfo(
        id: 11,
        timeStamp: 5,
        readAt: 5,
        event: 'punishment.created',
        title: '你收到一条警告',
        content: '理由：刷屏',
        meta: const {'punishment_id': 1},
      ),
      NotificationInfo(
        id: 12,
        timeStamp: 6,
        event: 'announcement.created',
        title: '公告标题',
        content: '公告内容',
      ),
    ]);

    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
        GoRoute(path: '/account', builder: (_, _) => const Scaffold(body: SizedBox())),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('你收到一条警告'), findsOneWidget);
    expect(find.text('公告标题'), findsOneWidget);
    expect(find.text('未读'), findsOneWidget);
    expect(tester.takeException(), isNull);

    NotificationService.instance.debugReplaceNotifications(const []);
  });

  testWidgets('nomore please notification', (tester) async {
    NotificationService.instance.debugReplaceNotifications([
      NotificationInfo(
        id: 21,
        timeStamp: 7,
        event: 'announcement.created',
        title: '公告标题',
        content: '公告内容',
      ),
    ]);
    NotificationService.instance.debugSetHasMore(false);

    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
        GoRoute(path: '/account', builder: (_, _) => const Scaffold(body: SizedBox())),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有更多通知了'), findsOneWidget);

    NotificationService.instance.debugReplaceNotifications(const []);
    NotificationService.instance.debugSetHasMore(true);
  });
}
