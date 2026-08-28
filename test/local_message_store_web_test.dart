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

  test('orders by roomSeq before timestamps (immune to clock skew)', () async {
    final serverT = DateTime.utc(2026, 1, 1, 12);
    await LocalMessageStore.instance.saveMessages('U2', [
      ChatMessage(
        id: '1',
        mid: 1,
        roomSeq: 1,
        text: 'a',
        timestamp: serverT,
        isMe: false,
      ),
      ChatMessage(
        id: '3',
        mid: 3,
        roomSeq: 3,
        text: 'c',
        timestamp: serverT.add(const Duration(seconds: 2)),
        isMe: false,
      ),
      ChatMessage(
        id: '2',
        mid: 2,
        roomSeq: 2,
        text: 'b',
        timestamp: serverT.add(const Duration(seconds: 1)),
        isMe: false,
      ),
    ]);

    final stored = await LocalMessageStore.instance.loadMessages('U2');

    expect(stored.map((message) => message.id), ['1', '2', '3']);
  });

  test('pending message without roomSeq sorts after confirmed ones', () async {
    final serverT = DateTime.utc(2026, 1, 1, 12);
    await LocalMessageStore.instance.saveMessages('U2', [
      ChatMessage(
        id: '1',
        mid: 1,
        roomSeq: 1,
        text: 'confirmed',
        timestamp: serverT,
        isMe: false,
      ),
      ChatMessage(
        id: 'pending',
        clientMid: 'c2',
        text: 'pending',
        timestamp: serverT.add(const Duration(minutes: 5)),
        isMe: true,
        status: MessageStatus.pending,
      ),
    ]);

    final stored = await LocalMessageStore.instance.loadMessages('U2');

    expect(stored.map((message) => message.id), ['1', 'pending']);
  });

  test('deleteMessage removes only the matching local message', () async {
    final serverT = DateTime.utc(2026, 1, 1, 12);
    final failed = ChatMessage(
      id: 'c2',
      clientMid: 'c2',
      text: 'failed',
      timestamp: serverT,
      isMe: true,
      status: MessageStatus.failed,
    );
    final confirmed = ChatMessage(
      id: '1',
      mid: 1,
      roomSeq: 1,
      text: 'confirmed',
      timestamp: serverT.subtract(const Duration(minutes: 1)),
      isMe: false,
    );
    await LocalMessageStore.instance.saveMessages('U2', [confirmed, failed]);

    await LocalMessageStore.instance.deleteMessage('U2', failed);

    final stored = await LocalMessageStore.instance.loadMessages('U2');
    expect(stored.map((message) => message.id), ['1']);
    expect(stored.any((message) => message.clientMid == 'c2'), isFalse);
  });

  test('deleteMessage by id removes messages without a clientMid', () async {
    final target = ChatMessage(
      id: '42',
      text: 'local',
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      isMe: true,
      status: MessageStatus.failed,
    );
    final other = ChatMessage(
      id: '43',
      text: 'keep',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1),
      isMe: true,
    );
    await LocalMessageStore.instance.saveMessages('U2', [target, other]);

    await LocalMessageStore.instance.deleteMessage('U2', target);

    final stored = await LocalMessageStore.instance.loadMessages('U2');
    expect(stored.map((message) => message.id), ['43']);
  });
}
