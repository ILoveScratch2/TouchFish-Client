import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/settings_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/widgets/command_palette.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  group('command palette setting', () {
    test('the settings key exists in the model and defaults to on', () {
      final matches = SettingsData.categories
          .expand((category) => category.items)
          .where((item) => item.key == commandPaletteEnabledKey)
          .toList();

      // 键名对不上就是「开关永远无效」：面板读的是默认值，设置页改的是另一个键。
      expect(matches, hasLength(1), reason: '设置项 key 必须与命令面板常量一致');
      expect(matches.single.defaultValue, isTrue, reason: '默认开启');
    });

    test('the gate follows the setting', () async {
      final service = SettingsService.instance;
      await service.setValue(commandPaletteEnabledKey, false);
      expect(commandPaletteEnabled, isFalse);
      await service.setValue(commandPaletteEnabledKey, true);
      expect(commandPaletteEnabled, isTrue);
    });
  });

  group('filterCommands', () {
    final items = <CommandPaletteItem>[
      CommandPaletteItem(
        icon: Icons.chat,
        title: 'Alpha Room',
        subtitle: 'hello there',
        keywords: const ['alpha'],
        onSelect: () {},
      ),
      CommandPaletteItem(
        icon: Icons.group,
        title: 'Beta Group',
        keywords: const ['team'],
        onSelect: () {},
      ),
      CommandPaletteItem(
        icon: Icons.settings,
        title: 'Settings',
        onSelect: () {},
      ),
    ];

    test('blank query returns nothing', () {
      expect(filterCommands(items, ''), isEmpty);
      expect(filterCommands(items, '   '), isEmpty);
    });

    test('title match ranks above keyword/subtitle matches', () {
      final result = filterCommands(items, 'set');
      expect(result.first.title, 'Settings');
    });

    test('matches keywords case-insensitively', () {
      final result = filterCommands(items, 'TEAM');
      expect(result.map((e) => e.title), contains('Beta Group'));
    });

    test('matches subtitle text', () {
      final result = filterCommands(items, 'hello');
      expect(result.map((e) => e.title), contains('Alpha Room'));
    });

    test('blank-ish non-match returns empty', () {
      expect(filterCommands(items, 'zzzzz'), isEmpty);
    });

    test('fuzzy subsequence matches scattered characters', () {
      final result = filterCommands(items, 'aroom');
      expect(result.map((e) => e.title), contains('Alpha Room'));
    });
  });

  group('command palette dialog', () {
    List<CommandPaletteItem> sampleItems(void Function(String) onSelected) => [
      CommandPaletteItem(
        icon: Icons.chat,
        title: 'Alpha Room',
        onSelect: () => onSelected('Alpha Room'),
      ),
      CommandPaletteItem(
        icon: Icons.group,
        title: 'Beta Group',
        onSelect: () => onSelected('Beta Group'),
      ),
    ];

    Widget buildApp(List<CommandPaletteItem> items) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showCommandPalette(context, items: items),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('filters by query and selects on tap', (tester) async {
      String? selected;
      await tester.pumpWidget(buildApp(sampleItems((t) => selected = t)));
      await open(tester);

      expect(find.byType(TextField), findsOneWidget);
      // 空查询不显示任何结果。
      expect(find.text('Alpha Room'), findsNothing);

      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pump();
      expect(find.text('Alpha Room'), findsOneWidget);
      expect(find.text('Beta Group'), findsNothing);

      await tester.tap(find.text('Alpha Room'));
      await tester.pumpAndSettle();
      expect(selected, 'Alpha Room');
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('opens with the search field focused', (tester) async {
      await tester.pumpWidget(buildApp(sampleItems((_) {})));
      await open(tester);

      // 不能靠 tester.enterText 强行聚焦：打开面板后用户应当能直接打字。
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(
        editable.focusNode.hasFocus,
        isTrue,
        reason: '命令面板打开后焦点必须在输入框上（外层容器不得抢焦点）',
      );
    });

    testWidgets('escape dismisses without selecting', (tester) async {
      String? selected;
      await tester.pumpWidget(buildApp(sampleItems((t) => selected = t)));
      await open(tester);
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('arrow down moves focus, enter activates focused item', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(buildApp(sampleItems((t) => selected = t)));
      await open(tester);
      await tester.enterText(find.byType(TextField), 'o');
      await tester.pump();
      // 两项都含 'o'，按标题排序：Alpha Room 在前、Beta Group 在后。
      expect(find.text('Alpha Room'), findsOneWidget);
      expect(find.text('Beta Group'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(selected, 'Beta Group');
    });

    testWidgets('shows empty hint when nothing matches', (tester) async {
      await tester.pumpWidget(buildApp(sampleItems((_) {})));
      await open(tester);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text('No matching results'), findsOneWidget);
    });

    testWidgets('cannot be summoned while disabled in settings', (tester) async {
      final service = SettingsService.instance;
      await service.setValue(commandPaletteEnabledKey, false);
      addTearDown(() => service.setValue(commandPaletteEnabledKey, true));

      String? selected;
      await tester.pumpWidget(buildApp(sampleItems((t) => selected = t)));
      await open(tester);

      expect(find.byType(TextField), findsNothing);
      expect(selected, isNull);
    });
  });

  group('command palette navigation', () {
    /// 最小路由：一个常驻 Section + 一个主壳之外的整屏子页面（如 /settings）。
    GoRouter buildRouter() => GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(path: '/chat', builder: (_, _) => const Text('chat-home')),
        GoRoute(
          path: '/settings',
          builder: (_, _) => Scaffold(
            appBar: AppBar(),
            body: const Text('settings-page'),
          ),
        ),
      ],
    );

    testWidgets('sub-page commands push so the target keeps a way back', (
      tester,
    ) async {
      final router = buildRouter();
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('chat-home'));
      unawaited(
        showCommandPalette(context, items: buildDefaultCommands(context)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Settings');
      await tester.pump();
      // 用 ListTile 定位结果项：find.text 也会匹配输入框里刚敲进去的那串字。
      final tile = find.widgetWithText(ListTile, 'Settings');
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.text('settings-page'), findsOneWidget);
      // 用 go 会把整叠路由替换成这一页：栈底没有上一页，AppBar 连返回键都不出，
      // 用户就困在里面了（/settings、/about 这些都在主壳之外）。
      expect(find.byType(BackButton), findsOneWidget);
      expect(router.canPop(), isTrue);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('chat-home'), findsOneWidget);
    });
  });
}
