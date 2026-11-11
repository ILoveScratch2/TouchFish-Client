import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/services/notification_service.dart';
import 'package:touchfish_client/widgets/account/inbox_summary_card.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    NotificationService.instance.debugReplaceNotifications(
      const [],
      unreadCount: 0,
    );
  });

  Future<GoRouter> pumpCard(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/account',
      routes: [
        GoRoute(
          path: '/account',
          builder: (_, _) => const Scaffold(
            body: Center(child: InboxSummaryCard()),
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const Scaffold(body: Text('通知页')),
        ),
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
    return router;
  }

  testWidgets('ok for enter notifications if no jch', (tester) async {
    await pumpCard(tester);

    expect(find.text('查看全部通知'), findsOneWidget);
    await tester.tap(find.text('查看全部通知'));
    await tester.pumpAndSettle();

    expect(find.text('通知页'), findsOneWidget);
  });

  testWidgets('ok for enter notifications if have unread', (tester) async {
    NotificationService.instance.debugReplaceNotifications(
      const [],
      unreadCount: 3,
    );
    await pumpCard(tester);

    expect(find.text('通知'), findsOneWidget);
    await tester.tap(find.text('通知'));
    await tester.pumpAndSettle();

    expect(find.text('通知页'), findsOneWidget);
  });
}
