import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/services/local_message_store_web.dart';

void main() {
  const server = 'https://example.test';
  const uid = 1;
  late String scope;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scope = '${base64Url.encode(utf8.encode(server))}/$uid';
    LocalMessageStore.instance.configureScope(server, uid);
  });

  ChatMessage message({
    required String id,
    required String text,
    required bool isMe,
    int? senderUid,
    List<int> mentionedUids = const [],
  }) =>
      ChatMessage(
        id: id,
        mid: int.tryParse(id),
        text: text,
        timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(id) * 1000),
        isMe: isMe,
        senderUid: senderUid,
        mentionedUids: mentionedUids,
      );

  test('export -> import round-trip preserves messages', () async {
    final messages = [
      message(id: '1', text: 'hello', isMe: true, senderUid: uid),
      message(
        id: '2',
        text: 'world',
        isMe: false,
        senderUid: 2,
        mentionedUids: [uid],
      ),
    ];
    await LocalMessageStore.instance.saveMessages('U2', messages);

    final snapshot = await LocalMessageStore.instance.exportSnapshot();
    expect(snapshot['messages'], hasLength(2));

    await LocalMessageStore.instance.clearDatabase();
    final imported = await LocalMessageStore.instance.importSnapshot(snapshot);
    expect(imported, 2);

    final loaded = await LocalMessageStore.instance.loadMessages('U2');
    expect(loaded, hasLength(2));
    expect(loaded.map((m) => m.text).toSet(), {'hello', 'world'});
    final world = loaded.firstWhere((m) => m.text == 'world');
    expect(world.mentionedUids, [uid]);
    final hello = loaded.firstWhere((m) => m.text == 'hello');
    expect(hello.isMe, isTrue);
  });

  test('malformed messages are skipped instead of emptying a room', () async {
    final good = message(id: '1', text: 'kept', isMe: false, senderUid: 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'touchfish_messages/$scope/U2',
      jsonEncode([good.toJson(), 'not-a-message', 42]),
    );

    final loaded = await LocalMessageStore.instance.loadMessages('U2');

    expect(loaded, hasLength(1));
    expect(loaded.single.text, 'kept');
  });

  test('ChatMessage.fromJson tolerates malformed numeric fields', () {
    final decoded = ChatMessage.fromJson({
      'id': '1',
      'senderUid': '2',
      'timestamp': 1000.5,
      'mentionedUids': ['1', 2],
      'text': 'hi',
    });

    expect(decoded.senderUid, 2);
    expect(
      decoded.timestamp.millisecondsSinceEpoch,
      1000,
    );
    expect(decoded.mentionedUids, [2]);
  });
}
