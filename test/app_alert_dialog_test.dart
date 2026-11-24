import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/widgets/app_alert_dialog.dart';
import 'package:touchfish_client/widgets/custom_title_bar.dart';
import 'package:touchfish_client/widgets/window_frame.dart';

void main() {
  Future<bool?> Function(BuildContext)? openDialog;

  Widget buildHarness({required Future<bool?> Function(BuildContext) open}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          WindowFrame(child: child ?? const SizedBox.shrink()),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open dialog'),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    openDialog = (context) => showTouchFishInfoDialog<bool>(
      context,
      message: 'preset dialog message',
      actions: [
        TouchFishDialogAction<bool>(
          label: 'Confirm',
          result: true,
          isPrimary: true,
        ),
      ],
    );
  });

  testWidgets('dialog renders below the title bar area', (tester) async {
    bool? result;
    await tester.pumpWidget(
      buildHarness(
        open: (context) async => result = await openDialog!(context),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('preset dialog message'), findsOneWidget);
    // 底层页面路由自带一个透明 ModalBarrier
    final dialogBarrier = find.byWidgetPredicate(
      (w) => w is ModalBarrier && w.color != null,
    );
    final barrierRect = tester.getRect(dialogBarrier);
    expect(barrierRect.top, CustomTitleBar.height);
    await tester.tapAt(const Offset(400, 20));
    await tester.pump();
    expect(find.text('preset dialog message'), findsOneWidget);
    await tester.tapAt(Offset(400, CustomTitleBar.height + 100));
    await tester.pumpAndSettle();
    expect(find.text('preset dialog message'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('action button returns its result', (tester) async {
    bool? result;
    await tester.pumpWidget(
      buildHarness(
        open: (context) async => result = await openDialog!(context),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('preset dialog message'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('escape key dismisses a dismissible dialog', (tester) async {
    bool? result;
    await tester.pumpWidget(
      buildHarness(
        open: (context) async => result = await openDialog!(context),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('preset dialog message'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('non-dismissible dialog ignores barrier and escape', (
    tester,
  ) async {
    openDialog = (context) => showTouchFishInfoDialog<bool>(
      context,
      message: 'blocking dialog',
      barrierDismissible: false,
    );
    await tester.pumpWidget(
      buildHarness(open: (context) async => await openDialog!(context)),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    await tester.tapAt(Offset(400, CustomTitleBar.height + 100));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('blocking dialog'), findsOneWidget);
  });

  testWidgets('showAppDialog keeps arbitrary content below the title bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        open: (context) async {
          await showAppDialog<void>(
            context,
            builder: (dialogContext, pop) => AlertDialog(
              content: const Text('custom body'),
              actions: [
                TextButton(onPressed: pop, child: const Text('close')),
              ],
            ),
          );
          return null;
        },
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('custom body'), findsOneWidget);
    final dialogBarrier = find.byWidgetPredicate(
      (w) => w is ModalBarrier && w.color != null,
    );
    expect(tester.getRect(dialogBarrier).top, CustomTitleBar.height);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(find.text('custom body'), findsNothing);
  });

  testWidgets('showAppDialog does not steal focus from autofocused field', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildHarness(
        open: (context) async {
          await showAppDialog<void>(
            context,
            builder: (dialogContext, pop) => AlertDialog(
              content: TextField(controller: controller, autofocus: true),
              actions: [
                TextButton(onPressed: pop, child: const Text('close')),
              ],
            ),
          );
          return null;
        },
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    final editable = find.byType(EditableText);
    expect(
      tester.widget<EditableText>(editable).focusNode.hasPrimaryFocus,
      isTrue,
    );
    await tester.enterText(editable, 'hello');
    expect(controller.text, 'hello');
  });
}
