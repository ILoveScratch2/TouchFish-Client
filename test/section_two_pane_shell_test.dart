import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/utils/wide_screen_helper.dart';
import 'package:touchfish_client/widgets/layout/section_two_pane_shell.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  group('WideScreenHelper tiered breakpoints', () {
    test('auto mode: compact / medium / expanded', () {
      // 默认导航阈值 600、分栏阈值 1000
      expect(
        WideScreenHelper.sizeClassWithWidth(500),
        WindowSizeClass.compact,
      );
      expect(
        WideScreenHelper.sizeClassWithWidth(700),
        WindowSizeClass.medium,
      );
      expect(
        WideScreenHelper.sizeClassWithWidth(1200),
        WindowSizeClass.expanded,
      );
    });

    test('isWide preserved (>= threshold)', () {
      expect(WideScreenHelper.isWideWithWidth(500), isFalse);
      expect(WideScreenHelper.isWideWithWidth(700), isTrue);
      expect(WideScreenHelper.isWideWithWidth(1200), isTrue);
    });

    test('isExpandedWithWidth only true at expanded', () {
      expect(WideScreenHelper.isExpandedWithWidth(700), isFalse);
      expect(WideScreenHelper.isExpandedWithWidth(1000), isTrue);
    });

    test('expanded also has to cross the user threshold', () async {
      // 用户把导航阈值调到分栏阈值之上时，1050 既不算 expanded
      // 也不算 medium（medium 也要求跨过阈值）——否则会出现「导航栏还没
      // 变宽，两栏却先并排」。
      await SettingsService.instance.setValue('wideScreenThreshold', 1100);
      expect(
        WideScreenHelper.sizeClassWithWidth(1050),
        WindowSizeClass.compact,
      );
      expect(WideScreenHelper.isWideWithWidth(1050), isFalse);
      expect(WideScreenHelper.isExpandedWithWidth(1050), isFalse);
      // 跨过用户阈值之后才回到 expanded。
      expect(
        WideScreenHelper.sizeClassWithWidth(1150),
        WindowSizeClass.expanded,
      );
      await SettingsService.instance.setValue('wideScreenThreshold', 600);
    });

    test('split threshold is configurable', () async {
      await SettingsService.instance.setValue('wideScreenThreshold', 600);

      // 分栏阈值调到 800：800 宽即可并排（同时仍要跨过导航阈值 600）。
      await SettingsService.instance.setValue('splitScreenThreshold', 800);
      expect(WideScreenHelper.splitThreshold, 800);
      expect(WideScreenHelper.isExpandedWithWidth(800), isTrue);
      expect(WideScreenHelper.isExpandedWithWidth(799), isFalse);

      // 调到比导航阈值还高时，以两者中较大的为准。
      await SettingsService.instance.setValue('splitScreenThreshold', 1100);
      expect(WideScreenHelper.isExpandedWithWidth(1050), isFalse);
      expect(WideScreenHelper.isExpandedWithWidth(1100), isTrue);

      // 越界值钳回可用范围，避免极端设置把右栏挤没。
      await SettingsService.instance.setValue('splitScreenThreshold', 5000);
      expect(WideScreenHelper.splitThreshold, 1200);
      await SettingsService.instance.setValue('splitScreenThreshold', 1000);
    });
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  Future<void> useSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump();
  }

  Widget buildShell({bool twoPane = true, String prefix = 'test_layout'}) =>
      SectionTwoPaneShell(
        storageKeyPrefix: prefix,
        twoPane: twoPane,
        list: const Text('left-list'),
        child: const Text('right-detail'),
      );

  testWidgets('wide + two pane: renders persistent list + child', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));
    await tester.pumpWidget(wrap(buildShell()));
    await tester.pumpAndSettle();

    expect(find.text('left-list'), findsOneWidget);
    expect(find.text('right-detail'), findsOneWidget);
  });

  testWidgets('wide + single pane: only the list fills the screen', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));
    await tester.pumpWidget(wrap(buildShell(twoPane: false)));
    await tester.pumpAndSettle();

    expect(find.text('left-list'), findsOneWidget);
    expect(find.text('right-detail'), findsNothing);
  });

  testWidgets('narrow: passes through to child only', (tester) async {
    await useSize(tester, const Size(480, 900));
    await tester.pumpWidget(wrap(buildShell()));
    await tester.pumpAndSettle();

    expect(find.text('left-list'), findsNothing);
    expect(find.text('right-detail'), findsOneWidget);
  });

  testWidgets('medium: still single pane, passes through to child only', (
    tester,
  ) async {
    // medium（默认 600–999）放得下导航栏 + 列表，但并排两栏太挤。
    await useSize(tester, const Size(800, 900));
    await tester.pumpWidget(wrap(buildShell()));
    await tester.pumpAndSettle();

    expect(find.text('left-list'), findsNothing);
    expect(find.text('right-detail'), findsOneWidget);
  });

  testWidgets('wide: enter animation wraps shell in a SlideTransition', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));
    await tester.pumpWidget(wrap(buildShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final slide = tester.widget<SlideTransition>(
      find
          .descendant(
            of: find.byType(SectionTwoPaneShell),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    expect(slide.position.value.dx, lessThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('switching pane modes keeps the list state and replays nothing', (
    tester,
  ) async {
    await useSize(tester, const Size(1200, 800));
    await tester.pumpWidget(wrap(buildShell()));
    await tester.pumpAndSettle();
    final stateBefore = tester.state(find.byType(SectionTwoPaneShell));
    final listStateBefore = tester.element(find.text('left-list'));

    // 切到单栏再切回分栏：外壳与列表都不重建（不重播入场动画）。
    await tester.pumpWidget(wrap(buildShell(twoPane: false)));
    await tester.pumpAndSettle();
    expect(find.text('right-detail'), findsNothing);
    expect(tester.state(find.byType(SectionTwoPaneShell)), same(stateBefore));
    expect(tester.element(find.text('left-list')), same(listStateBefore));

    await tester.pumpWidget(wrap(buildShell()));
    await tester.pumpAndSettle();
    expect(find.text('right-detail'), findsOneWidget);
    expect(tester.state(find.byType(SectionTwoPaneShell)), same(stateBefore));
    expect(tester.element(find.text('left-list')), same(listStateBefore));
  });

  testWidgets('drag below the minimum width snaps back before persisting', (
    tester,
  ) async {
    const prefix = 'test_drag_width';
    await useSize(tester, const Size(1200, 800));
    await tester.pumpWidget(wrap(buildShell(prefix: prefix)));
    await tester.pumpAndSettle();

    // 拖拽把手在左栏右边缘（默认宽 320）。往左拖 90：落到约 230，
    // 低于 minWidth(260) 但没到 collapseThreshold(200)，所以不该折叠 ——
    // 这种中间值以前会被原样存进 prefs，下次挂载再被 _restore 顶回 260。
    await tester.dragFrom(const Offset(326, 400), const Offset(-90, 0));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('${prefix}_width'), 260);
    expect(prefs.getBool('${prefix}_collapsed'), isFalse);

    // 重新挂载（重走 _restore）后宽度不跳：持久化的值已经落在合法范围内。
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(wrap(buildShell(prefix: prefix)));
    await tester.pumpAndSettle();

    final leftPane = tester
        .widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned))
        .first;
    expect(leftPane.right, 1200 - 260);
  });

  testWidgets('dragging all the way collapses into the icon rail', (
    tester,
  ) async {
    const prefix = 'test_drag_collapse';
    await useSize(tester, const Size(1200, 800));
    await tester.pumpWidget(wrap(buildShell(prefix: prefix)));
    await tester.pumpAndSettle();

    // 拖到远低于 collapseThreshold(200)：收尾应折叠成图标栏（宽 72）。
    await tester.dragFrom(const Offset(326, 400), const Offset(-400, 0));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('${prefix}_collapsed'), isTrue);
    final leftPane = tester
        .widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned))
        .first;
    expect(leftPane.right, 1200 - 72);
  });
}
