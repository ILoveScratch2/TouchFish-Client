import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/widgets/untrusted_image_placeholder.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('placeholder shows load button and info icon', (tester) async {
    var proceeded = false;
    await tester.pumpWidget(
      _wrap(
        UntrustedImagePlaceholder(
          uri: Uri.parse('https://evil.example.com/x.png'),
          onProceed: () => proceeded = true,
        ),
      ),
    );

    expect(find.text('Load Image'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    expect(find.text('evil.example.com'), findsOneWidget);

    await tester.tap(find.text('Load Image'));
    expect(proceeded, isTrue);
  });

  testWidgets('tapping the info icon shows the explanation dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        UntrustedImagePlaceholder(
          uri: Uri.parse('https://evil.example.com/x.png'),
          onProceed: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('About Domain Protection'), findsOneWidget);
    expect(
      find.textContaining('Third-party sites may record or leak'),
      findsOneWidget,
    );
    expect(
      find.textContaining('TouchFish Client no longer loads external images'),
      findsOneWidget,
    );
  });
}
