import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/services/local_message_store_web.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalMessageStore.instance.configureScope('https://example.test', 1);
  });

  test('loads recent and older message pages with a stable cursor', () async {
    final messages = [
      for (var index = 0; index < 5; index++)
        ChatMessage(
          id: '$index',
          mid: index,
          text: 'message $index',
          timestamp: DateTime.fromMillisecondsSinceEpoch(index ~/ 2),
          isMe: false,
        ),
    ];
    await LocalMessageStore.instance.saveMessages('U2', messages);

    final recent = await LocalMessageStore.instance.loadMessages(
      'U2',
      limit: 3,
    );
    final older = await LocalMessageStore.instance.loadMessages(
      'U2',
      limit: 3,
      before: recent.first,
    );

    expect(recent.map((message) => message.id), ['2', '3', '4']);
    expect(older.map((message) => message.id), ['0', '1']);
  });

  test(
    'saving a visible page does not replace older persisted messages',
    () async {
      final messages = [
        for (var index = 0; index < 5; index++)
          ChatMessage(
            id: '$index',
            mid: index,
            text: 'message $index',
            timestamp: DateTime.fromMillisecondsSinceEpoch(index),
            isMe: false,
          ),
      ];
      await LocalMessageStore.instance.saveMessages('U2', messages);
      await LocalMessageStore.instance.saveMessages('U2', [
        messages.last.copyWith(text: 'updated'),
      ]);

      final stored = await LocalMessageStore.instance.loadMessages('U2');

      expect(stored, hasLength(5));
      expect(stored.last.text, 'updated');
    },
  );

  test('findMessageByMid locates a persisted message by server mid', () async {
    final messages = [
      for (var index = 0; index < 5; index++)
        ChatMessage(
          id: '$index',
          mid: index,
          text: 'message $index',
          timestamp: DateTime.fromMillisecondsSinceEpoch(index),
          isMe: false,
        ),
    ];
    await LocalMessageStore.instance.saveMessages('U2', messages);

    final found = await LocalMessageStore.instance.findMessageByMid('U2', 3);

    expect(found, isNotNull);
    expect(found!.mid, 3);
    expect(found.text, 'message 3');
  });

  test('findMessageByMid returns null for an unknown mid', () async {
    final messages = [
      ChatMessage(
        id: '0',
        mid: 0,
        text: 'hello',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        isMe: false,
      ),
    ];
    await LocalMessageStore.instance.saveMessages('U2', messages);

    final missing =
        await LocalMessageStore.instance.findMessageByMid('U2', 42);

    expect(missing, isNull);
  });
}
