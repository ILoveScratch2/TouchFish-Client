import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/widgets/chat_input_bar.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  Future<void> pumpInput(
    WidgetTester tester,
    TextEditingController controller,
    VoidCallback onSend,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInputBar(controller: controller, onSend: onSend),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
  }

  testWidgets('Enter mode sends with Enter and keeps Shift+Enter multiline', (
    tester,
  ) async {
    await SettingsService.instance.setValue('sendMode', 'enter');
    final controller = TextEditingController(text: 'hello');
    var sends = 0;
    await pumpInput(tester, controller, () => sends++);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(sends, 1);
    controller.dispose();
  });

  testWidgets('Ctrl+Enter mode supports Control and Command shortcuts', (
    tester,
  ) async {
    await SettingsService.instance.setValue('sendMode', 'ctrlEnter');
    final controller = TextEditingController(text: 'hello');
    var sends = 0;
    await pumpInput(tester, controller, () => sends++);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(sends, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(sends, 2);
    controller.dispose();
  });
}
