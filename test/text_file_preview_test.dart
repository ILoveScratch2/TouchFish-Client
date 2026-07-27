import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/file_attachment.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/widgets/file_attachment_view.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'automaticPreviewMaxMiB': 10});
    await SettingsService.instance.init();
  });

  testWidgets('renders text in the Solian-style inline preview', (
    tester,
  ) async {
    const content = 'first line\nsecond line';
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
          body: Center(
            child: SizedBox(
              width: 360,
              child: FileAttachmentView(
                attachment: const FileAttachment(
                  hash: 'log-hash',
                  fileName: 'server.log',
                  fileSize: 22,
                  mimeType: 'text/plain',
                ),
                bytes: utf8.encode(content),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectable = tester.widget<SelectableText>(
      find.widgetWithText(SelectableText, content),
    );
    expect(selectable.style?.fontFamily, 'monospace');
    expect(selectable.style?.fontSize, 14);
    expect(find.text('server.log'), findsOneWidget);
    expect(tester.getSize(find.byType(SelectableText)).height, greaterThan(0));
  });
}
