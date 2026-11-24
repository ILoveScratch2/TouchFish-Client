import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/widgets/custom_title_bar.dart';
import 'package:touchfish_client/widgets/window_frame.dart';

void main() {
  final skipOnNonDesktop = !WindowFrame.isDesktopWindowed;

  Widget harness({
    required void Function(BuildContext context) onPressed,
    String actionLabel = 'action',
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          WindowFrame(child: child ?? const SizedBox.shrink()),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => onPressed(context),
              child: Text(actionLabel),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('very good title bar! (made by ilovescratch2 ywd but i am qu)', (tester) async {
    await tester.pumpWidget(harness(onPressed: (_) {}));
    await tester.pump();

    final scaffoldRect = tester.getRect(find.byType(Scaffold));
    expect(scaffoldRect.top, CustomTitleBar.height);
    expect(
      scaffoldRect.bottom,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    expect(find.byType(CustomTitleBar), findsOneWidget);
  }, skip: skipOnNonDesktop);

  testWidgets('full screen page does not cover the custom title bar PLEASE help me fxxk ccf', (tester) async {
    await tester.pumpWidget(
      harness(
        actionLabel: 'open page',
        onPressed: (context) {
          Navigator.of(context, rootNavigator: true).push<void>(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const Scaffold(
                key: Key('pushed-page'),
                body: SizedBox.expand(),
              ),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('open page'));
    await tester.pumpAndSettle();

    final pageRect = tester.getRect(find.byKey(const Key('pushed-page')));
    expect(pageRect.top, CustomTitleBar.height);
    expect(find.byType(CustomTitleBar), findsOneWidget);
    expect(tester.getRect(find.byType(CustomTitleBar)).top, 0);
  }, skip: skipOnNonDesktop);

  testWidgets('bottom sheet overlay does not cover the custom title bar csp-s BOOMED! 😭', (tester) async {
    await tester.pumpWidget(
      harness(
        actionLabel: 'open sheet',
        onPressed: (context) {
          showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            builder: (_) => const SizedBox(
              key: Key('sheet-body'),
              height: 200,
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sheet-body')), findsOneWidget);
    final barrier = find.byWidgetPredicate(
      (w) => w is ModalBarrier && w.color != null,
    );
    expect(tester.getRect(barrier).top, CustomTitleBar.height);
  }, skip: skipOnNonDesktop);
}
