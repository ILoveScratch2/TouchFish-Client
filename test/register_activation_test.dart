import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/screens/register_step3_screen.dart';
import 'package:touchfish_client/services/snackbar_service.dart';

Widget _app(Future<bool> Function() resendCode) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: RegisterStep3Screen(
    username: 'tester',
    uid: 42,
    resendCode: resendCode,
  ),
);

void main() {
  testWidgets('resends once and unlocks after the resend cooldown', (
    tester,
  ) async {
    final reply = Completer<bool>();
    var requestCount = 0;
    await tester.pumpWidget(
      _app(() {
        requestCount++;
        return reply.future;
      }),
    );

    final input = find.byType(TextField);
    final resend = find.widgetWithText(TextButton, 'Resend activation code');
    await tester.enterText(input, '123456');
    await tester.tap(resend);
    await tester.pump();
    await tester.tap(resend);
    expect(requestCount, 1);

    reply.complete(true);
    await tester.pump();
    expect(tester.widget<TextField>(input).controller?.text, '');
    final waitButton = find.widgetWithText(TextButton, 'Resend in 60s');
    expect(tester.widget<TextButton>(waitButton).onPressed, isNull);

    await tester.pump(const Duration(minutes: 1));
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
  });

  testWidgets('leaves the current code and allows retry when resend fails', (
    tester,
  ) async {
    await tester.pumpWidget(_app(() async => false));

    final input = find.byType(TextField);
    final resend = find.widgetWithText(TextButton, 'Resend activation code');
    await tester.enterText(input, '123456');
    await tester.tap(resend);
    await tester.pump();

    expect(tester.widget<TextField>(input).controller?.text, '123456');
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
    expect(
      TouchFishSnackbarService.instance.message,
      'Could not request a new code. Please try again.',
    );
    await tester.pump(const Duration(seconds: 3));
  });
}
