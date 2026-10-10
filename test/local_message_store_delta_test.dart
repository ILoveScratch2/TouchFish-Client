import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/services/local_message_store_web.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalMessageStore.instance.configureScope('https://example.test', 1);
  });

  ChatMessage message(int mid, String text) => ChatMessage(
    id: '$mid',
    mid: mid,
    roomSeq: mid,
    text: text,
    timestamp: DateTime.fromMillisecondsSinceEpoch(mid),
    isMe: false,
  );

  test('saveMessage upserts a single message without dropping others', () async {
    await LocalMessageStore.instance.saveMessages('U2', [
      message(1, 'a'),
      message(2, 'b'),
    ]);

    await LocalMessageStore.instance.saveMessage('U2', message(3, 'c'));
    await LocalMessageStore.instance.saveMessage('U2', message(2, 'b-updated'));

    final stored = await LocalMessageStore.instance.loadMessages('U2');

    expect(stored.map((m) => m.id), ['1', '2', '3']);
    expect(stored[1].text, 'b-updated');
  });

  test('saveMessage on a new room appends without clobbering', () async {
    await LocalMessageStore.instance.saveMessage('U9', message(1, 'first'));

    final stored = await LocalMessageStore.instance.loadMessages('U9');

    expect(stored, hasLength(1));
    expect(stored.single.text, 'first');
  });

  test('appendMessages merges a batch by message key', () async {
    await LocalMessageStore.instance.saveMessages('U2', [
      message(1, 'a'),
      message(2, 'b'),
    ]);

    await LocalMessageStore.instance.appendMessages('U2', [
      message(2, 'b2'),
      message(3, 'c'),
      message(4, 'd'),
    ]);

    final stored = await LocalMessageStore.instance.loadMessages('U2');

    expect(stored.map((m) => m.id), ['1', '2', '3', '4']);
    expect(stored.map((m) => m.text), ['a', 'b2', 'c', 'd']);
  });

  test('appendMessages ignores an empty batch', () async {
    await LocalMessageStore.instance.saveMessages('U2', [message(1, 'a')]);

    await LocalMessageStore.instance.appendMessages('U2', const []);

    final stored = await LocalMessageStore.instance.loadMessages('U2');
    expect(stored.map((m) => m.id), ['1']);
  });

  test('appendMessages upserts client-keyed pending messages', () async {
    final pending = ChatMessage(
      id: 'pending',
      clientMid: 'c1',
      text: 'pending',
      timestamp: DateTime.fromMillisecondsSinceEpoch(10),
      isMe: true,
      status: MessageStatus.pending,
    );
    await LocalMessageStore.instance.saveMessages('U2', [pending]);

    final acked = ChatMessage(
      id: '5',
      mid: 5,
      roomSeq: 5,
      clientMid: 'c1',
      text: 'pending',
      timestamp: DateTime.fromMillisecondsSinceEpoch(10),
      isMe: true,
      status: MessageStatus.sent,
    );
    await LocalMessageStore.instance.appendMessages('U2', [acked]);

    final stored = await LocalMessageStore.instance.loadMessages('U2');

    expect(stored, hasLength(1));
    expect(stored.single.mid, 5);
    expect(stored.single.status, MessageStatus.sent);
  });
}
