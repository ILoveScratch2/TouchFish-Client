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
    SharedPreferences.setMockInitialValues({'chat_list_collapsed': true});
    ChatDataService.instance.rooms
      ..clear()
      ..add(ChatRoom(id: 'room', name: 'Test room', type: ChatType.direct));
  });

  tearDown(() {
    ChatDataService.instance.rooms.clear();
  });

  Widget app(Widget home) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  testWidgets('collapsed shell preserves a 64 pixel content rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(const ChatShellScreen(child: SizedBox())));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Card).first).width, 64);
  });

  testWidgets('collapsed room button and avatar keep circular dimensions', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 64,
            height: 600,
            child: ChatListScreen(
              isAside: true,
              isCollapsed: true,
              isHovering: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final roomButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Test room',
    );
    expect(tester.getSize(roomButton), const Size(48, 48));
    expect(
      tester.getSize(
        find.descendant(of: roomButton, matching: find.byType(CircleAvatar)),
      ),
      const Size(36, 36),
    );
  });
}
