import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/l10n/app_localizations_zh.dart';
import 'package:touchfish_client/widgets/external_auth_ticket_dialog.dart';

void main() {
  final l10n = AppLocalizationsZh();

  Widget harness({
    Future<bool> Function()? onOpen,
    ValueChanged<String?>? onResult,
  }) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final ticket = await ExternalAuthTicketDialog.show(
                  context,
                  onOpenAuthorizePage: onOpen,
                );
                onResult?.call(ticket);
              },
              child: const Text('open dialog'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ask user to open authorize page and show ticket input by mjz', (tester) async {
    await tester.pumpWidget(harness(onOpen: () async => true));
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.externalAuthManualHintWithOpen), findsOneWidget);
    expect(find.text(l10n.externalAuthManualOpenPage), findsOneWidget);
    expect(find.text(l10n.externalAuthManualFieldLabel), findsOneWidget);
    expect(find.text(l10n.externalAuthManualPaste), findsOneWidget);
  });

  testWidgets('use basic hint when native fallback entry has no open authorize page button majingzhi', (tester) async {
    await tester.pumpWidget(harness(onOpen: null));
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.externalAuthManualHint), findsOneWidget);
    expect(find.text(l10n.externalAuthManualOpenPage), findsNothing);
    expect(find.text(l10n.externalAuthManualHintWithOpen), findsNothing);
  });

  testWidgets('tapping open authorize page triggers the callback majingzhi', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      harness(
        onOpen: () async {
          opened++;
          return true;
        },
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.externalAuthManualOpenPage));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text(l10n.externalAuthManualOpenFailed), findsNothing);
  });

  testWidgets('show visible hint when popup is blocked majingzhi', (tester) async {
    await tester.pumpWidget(harness(onOpen: () async => false));
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.externalAuthManualOpenPage));
    await tester.pumpAndSettle();

    expect(find.text(l10n.externalAuthManualOpenFailed), findsOneWidget);
  });

  testWidgets('return input value after entering ticket modejingzi', (tester) async {
    String? result;
    await tester.pumpWidget(
      harness(onOpen: () async => true, onResult: (value) => result = value),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  ticket-abc  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.externalAuthManualConfirm));
    await tester.pumpAndSettle();

    expect(result, 'ticket-abc');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('do not allow submission when input is empty haveNoJZ', (tester) async {
    await tester.pumpWidget(harness(onOpen: () async => true));
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.externalAuthManualConfirm),
    );
    expect(button.onPressed, isNull);
  });
}
