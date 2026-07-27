import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/widgets/markdown_renderer.dart';

void main() {
  for (final selectable in [false, true]) {
    testWidgets(
      'task lists render without negative padding when selectable is $selectable',
      (tester) async {
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
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: MarkdownRenderer(
                selectable: selectable,
                data: '''
- [ ] unchecked
- [x] checked
1. [X] ordered
   - [ ] nested
''',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_box), findsNWidgets(2));
        expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
