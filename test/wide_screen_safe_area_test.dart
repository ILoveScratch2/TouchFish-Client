import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/chat_model.dart';
import 'package:touchfish_client/screens/chat_screen.dart';
import 'package:touchfish_client/services/chat_data_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChatDataService.instance.rooms
      ..clear()
      ..add(ChatRoom(id: 'room', name: 'Test room', type: ChatType.direct));
  });

  tearDown(() {
    ChatDataService.instance.rooms.clear();
  });

  Widget appWithStatusBar(Widget home, {double statusBar = 24}) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          padding: EdgeInsets.only(top: statusBar),
        ),
        child: home,
      ),
    );
  }

  testWidgets('wide chat shell insets content below the status bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      appWithStatusBar(const ChatShellScreen(child: SizedBox())),
    );
    await tester.pumpAndSettle();

    // 聊天列表卡片（含顶部搜索/邀请按钮）必须位于状态栏安全区之下。
    final cardTop = tester.getTopLeft(find.byType(Card).first).dy;
    expect(cardTop, greaterThanOrEqualTo(24));

    // 顶部的搜索按钮（右侧工具栏）同样不被状态栏遮挡。
    final searchButton = find.byTooltip('搜索群聊');
    expect(searchButton, findsOneWidget);
    final buttonTop = tester.getTopLeft(searchButton).dy;
    expect(buttonTop, greaterThanOrEqualTo(24));
  });
}
