import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/widgets/app_alert_dialog.dart';
import 'package:touchfish_client/widgets/custom_title_bar.dart';

void main() {
  int titleBarTaps = 0;
  Future<bool?> Function(BuildContext)? openDialog;

  Widget buildHarness({required Future<bool?> Function(BuildContext) open}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              GestureDetector(
                key: const Key('fake-title-bar'),
                behavior: HitTestBehavior.opaque,
                onTap: () => titleBarTaps++,
                child: Container(
                  height: CustomTitleBar.height,
                  color: Colors.amber,
                ),
              ),
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: () => open(context),
                    child: const Text('open dialog'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  setUp(() {
    titleBarTaps = 0;
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
    var result;
    await tester.pumpWidget(
      buildHarness(
        open: (context) async => result = await openDialog!(context),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('preset dialog message'), findsOneWidget);
    // 底层页面路由自带一个透明 ModalBarrier，这里只找弹窗自己的屏障。
    final dialogBarrier = find.byWidgetPredicate(
      (w) => w is ModalBarrier && w.color != null,
    );
    final barrierRect = tester.getRect(dialogBarrier);
    expect(barrierRect.top, CustomTitleBar.height);
    await tester.tapAt(const Offset(400, 20));
    expect(titleBarTaps, 1);
    expect(find.text('preset dialog message'), findsOneWidget);
    await tester.tapAt(Offset(400, CustomTitleBar.height + 100));
    await tester.pumpAndSettle();
    expect(find.text('preset dialog message'), findsNothing);
    expect(result, isNull);
  });

  testWidgets('action button returns its result', (tester) async {
    var result;
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
    var result;
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
}
