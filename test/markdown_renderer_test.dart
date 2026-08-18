import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/widgets/markdown_renderer.dart';

Widget _wrap(String data) {
  return MaterialApp(
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
      body: MarkdownRenderer(data: data),
    ),
  );
}

void main() {
  testWidgets('empty block formula does not crash', (tester) async {
    // 空块公式：$$$$ 和 $$ $$ 不应抛 RangeError / 渲染崩溃
    await tester.pumpWidget(_wrap(r'before $$$$ after'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_wrap(r'before $$ $$ after'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('block formula renders as display style', (tester) async {
    const formula = r'''
before
$$
\int^{\infty}_{-\infty}e^{-x^2}\mathrm{d}x
$$
after
''';
    await tester.pumpWidget(_wrap(formula));
    await tester.pumpAndSettle();
    // 块公式不应抛异常
    expect(tester.takeException(), isNull);
  });
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
