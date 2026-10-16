import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/widgets/layout/responsive_sidebar.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  Future<void> useSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump();
  }

  Widget host() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => ResponsiveSidebar.show<String>(
                context: context,
                width: 320,
                builder: (ctx, close) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('panel-body'),
                    TextButton(
                      onPressed: () => close('done'),
                      child: const Text('close'),
                    ),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('wide: renders an inline right-side panel', (tester) async {
    await useSize(tester, const Size(1200, 800));
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('panel-body'), findsOneWidget);
    // 宽屏走 showGeneralDialog（右侧面板），不是 bottom sheet
    expect(find.byType(BottomSheet), findsNothing);
    final panelBox = tester.getRect(find.text('panel-body'));
    // 面板贴右：中心偏右半屏
    expect(panelBox.center.dx, greaterThan(600));
  });

  testWidgets('narrow: degrades to a bottom sheet', (tester) async {
    await useSize(tester, const Size(480, 900));
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('panel-body'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('close callback pops and returns the result', (tester) async {
    await useSize(tester, const Size(1200, 800));
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(find.text('panel-body'), findsNothing);
  });
}
