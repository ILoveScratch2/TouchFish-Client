import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/screens/universal_search_screen.dart';

void main() {
  testWidgets('renders three tabs and the start hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const UniversalSearchScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    // 空查询时展示起始提示，而非「无结果」
    expect(find.text('Enter keywords to start searching'), findsOneWidget);
  });
}
