import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/theme/app_theme.dart';
import 'package:touchfish_client/theme/tokens.dart';

/// 主题层回归测试。
///
/// 背景：主题层曾两次引入「TextStyle 的 inherit 不一致」问题——
/// 把 `theme.textTheme.*` 写进子主题的 `textStyle` 字段后，
/// `AnimatedDefaultTextStyle` 在做 `TextStyle.lerp` 时抛
/// `Failed to interpolate TextStyles with different inherit values`。
/// 断言在 debug 下被吞掉，表现为列表变宽、行高异常，极难排查。
///
/// 本测试把常见 Material 组件放在自定义主题里跑一遍，确保：
/// 1. 不抛异常（等于守住 inherit 一致性）；
/// 2. 关键几何尺寸与 M3 默认主题完全一致（等于守住"不要顺手改默认值"）。
ThemeData _baseline(ColorScheme scheme) =>
    ThemeData(colorScheme: scheme, useMaterial3: true);

ThemeData _themed(ColorScheme scheme) => TFTheme.build(
  scheme: scheme,
  fontFamily: null,
  cardOpacity: 1,
  transparentSurfaces: false,
);

Widget _probe() => Scaffold(
  appBar: AppBar(title: const Text('页面标题')),
  body: ListView(
    children: [
      const Card(
        margin: EdgeInsets.all(4),
        child: ListTile(
          leading: SizedBox(width: 40, height: 40),
          title: Text('标题'),
          subtitle: Text('副标题'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
      const Divider(),
      const ListTile(title: Text('无 leading 的项')),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Chip(label: Text('chip')),
      ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: TextField(decoration: InputDecoration(hintText: 'hint')),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: FilledButton(onPressed: () {}, child: const Text('按钮')),
      ),
    ],
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('主题构建不产生插值异常（$brightness）', (tester) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      );

      await tester.pumpWidget(
        MaterialApp(theme: _themed(scheme), home: _probe()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('列表项/输入框几何与默认主题一致（$brightness）', (tester) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      );
      final sizes = <String, Size>{};

      for (final entry in {
        'baseline': _baseline(scheme),
        'themed': _themed(scheme),
      }.entries) {
        await tester.pumpWidget(
          MaterialApp(theme: entry.value, home: _probe()),
        );
        await tester.pumpAndSettle();
        sizes[entry.key] = tester.getSize(find.byType(ListTile).first);
      }

      expect(sizes['themed'], sizes['baseline']);
    });
  }

  testWidgets('对话框与弹层使用浮层色且带 elevation', (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final theme = _themed(scheme);

    expect(theme.dialogTheme.backgroundColor, scheme.surfaceContainerLowest);
    expect(theme.dialogTheme.elevation, greaterThan(0));
    expect(theme.bottomSheetTheme.backgroundColor, scheme.surfaceContainerLowest);
    expect(theme.popupMenuTheme.elevation, greaterThan(0));
  });

  testWidgets('卡片底色比页面深，保证卡片可辨识', (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final theme = _themed(scheme);

    expect(theme.cardTheme.color, scheme.surfaceContainerLow);
    expect(
      theme.cardTheme.color,
      isNot(theme.scaffoldBackgroundColor ?? scheme.surface),
      reason: '卡片底色与页面同色时卡片会隐形',
    );
  });

  testWidgets('AppBar 标题收到 16sp/w600', (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final style = _themed(scheme).appBarTheme.titleTextStyle;

    expect(style?.fontSize, 16);
    expect(style?.fontWeight, FontWeight.w600);
    expect(style?.inherit, isFalse, reason: 'inherit 必须为 false，否则插值崩溃');
  });

  test('圆角归成两个家族', () {
    expect(TFRadius.card, 20);
    expect(TFRadius.input, 20);
    expect(TFRadius.control, 20);
    expect(TFRadius.menu, 20);
    expect(TFRadius.dialog, 28);
    expect(TFRadius.sheet, 28);
    expect(TFSpace.card, 20);
  });
}
