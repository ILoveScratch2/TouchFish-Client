import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/widgets/changelog_view.dart';

void main() {
  Widget harness(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );
  }

  group('splitMarkdownIntoChunks', () {
    test('keeps short markdown in a single chunk', () {
      expect(splitMarkdownIntoChunks('1.0.0\n\n- 一条'), ['1.0.0\n\n- 一条']);
    });

    test('splits a long list without losing any item', () {
      final items = List.generate(
        60,
        (i) => '- 第 $i 条变动说明，含足够长的描述文字以便触发切分',
      );
      final chunks = splitMarkdownIntoChunks(
        items.join('\n'),
        targetChars: 400,
        maxListItemRun: 10,
      );
      expect(chunks.length, greaterThan(1));
      final rejoined = chunks.expand((c) => c.split('\n')).toList();
      expect(rejoined, items);
      expect(chunks.every((c) => c.length < 800), isTrue);
    });

    test('never splits inside a fenced code block', () {
      final body = [
        '- 条目',
        ...List.generate(20, (i) => i == 0 ? '```' : '\$ code $i'),
        '```',
        '- 后续',
      ].join('\n');
      final chunks = splitMarkdownIntoChunks(body, targetChars: 10, maxListItemRun: 2);
      final fenced = chunks.where((c) => c.contains('```')).toList();
      expect(fenced.length, 1);
      expect(fenced.single.split('```').length, 3);
    });
  });

  group('ChangelogView', () {
    testWidgets('long changelog stays bounded and scrollable', (tester) async {
      final markdown = List.generate(
        400,
        (i) => '- 第 $i 条变动说明，长度接近真实日志',
      ).join('\n');
      await tester.pumpWidget(
        harness(ChangelogView(markdown: markdown, maxHeight: 200)),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(
        tester.getSize(find.byType(ChangelogView)).height,
        lessThanOrEqualTo(200),
      );

      // lazy
      // let us learn from xianduanshu
      final before = tester.allWidgets.length;
      expect(before, lessThan(1500));
    });

    testWidgets('short changelog shrinks instead of leaving a gap', (tester) async {
      await tester.pumpWidget(
        harness(const ChangelogView(markdown: '- 一条', maxHeight: 200)),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, 0);
      expect(
        tester.getSize(find.byType(ChangelogView)).height,
        lessThan(200),
      );
    });

    testWidgets('non-scrollable preview clips instead of overflowing', (tester) async {
      final markdown = List.generate(200, (i) => '- 第 $i 条变动说明').join('\n');
      await tester.pumpWidget(
        harness(
          ChangelogView(markdown: markdown, maxHeight: 120, scrollable: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ChangelogView)).height,
        lessThanOrEqualTo(120),
      );
    });

    testWidgets('renders markdown structure verbatim', (tester) async {
      const markdown = '''
### 标题行

> 引用提示

- **加粗** 条目''';
      await tester.pumpWidget(
        harness(const ChangelogView(markdown: markdown, maxHeight: 300)),
      );
      await tester.pumpAndSettle();

      // 直接渲染原文：标题文字、引用、列表项都在，且没有残留标记符号
      expect(find.text('标题行'), findsOneWidget);
      expect(find.text('引用提示'), findsOneWidget);
      expect(find.textContaining('加粗 条目'), findsOneWidget);
      expect(find.textContaining('###'), findsNothing);
    });
  });
}
