import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/chat_model.dart';
import 'package:touchfish_client/widgets/chat_list_widget.dart';

class _OchMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _OchMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'och';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('zh'));

  @override
  bool shouldReload(_OchMaterialLocalizationsDelegate old) => false;
}

class _OchWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _OchWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'och';

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('zh'));

  @override
  bool shouldReload(_OchWidgetsLocalizationsDelegate old) => false;
}

class _OchCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _OchCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'och';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('zh'));

  @override
  bool shouldReload(_OchCupertinoLocalizationsDelegate old) => false;
}

void main() {
  testWidgets('formats a recent chat date for the och locale', (tester) async {
    final messageTime = DateTime.now().subtract(const Duration(days: 2));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('och'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          _OchMaterialLocalizationsDelegate(),
          _OchWidgetsLocalizationsDelegate(),
          _OchCupertinoLocalizationsDelegate(),
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatListWidget(
            chatRooms: [
              ChatRoom(
                id: 'room',
                name: 'Room',
                type: ChatType.direct,
                lastMessage: 'Message',
                lastMessageTime: messageTime,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(DateFormat.E('zh').format(messageTime)), findsOneWidget);
  });
}
