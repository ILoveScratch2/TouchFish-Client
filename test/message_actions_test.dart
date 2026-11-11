import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/widgets/message_bubble.dart';

/// 消息动作的单一事实源（[buildMessageActions]）：撤回/删除的消息不该再提供
/// 「复制」——那时 text 只剩占位文案。
void main() {
  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  ChatMessage message({required bool deleted}) => ChatMessage(
    id: 'm1',
    mid: 1,
    text: deleted ? 'message recalled' : 'hello',
    timestamp: DateTime(2026, 1, 1),
    isMe: false,
    isDeleted: deleted,
  );

  List<MessageAction> actionsFor(BuildContext context, ChatMessage m) =>
      buildMessageActions(
        context,
        message: m,
        canRecall: false,
        canPin: false,
        essenceEnabled: false,
        isPinned: false,
        isEssence: false,
      );

  testWidgets('a normal message can be copied', (tester) async {
    final context = await pumpContext(tester);
    final kinds = actionsFor(context, message(deleted: false))
        .map((a) => a.kind)
        .toList();

    expect(kinds, contains(MessageActionKind.copy));
  });

  testWidgets('a recalled message offers neither copy nor an empty sheet', (
    tester,
  ) async {
    final context = await pumpContext(tester);
    final actions = actionsFor(context, message(deleted: true));

    expect(
      actions.map((a) => a.kind),
      isNot(contains(MessageActionKind.copy)),
    );
    // 没有任何动作时调用方不该再弹菜单，这里保证判断依据是空列表。
    expect(actions, isEmpty);
  });
}
