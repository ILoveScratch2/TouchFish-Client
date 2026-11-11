import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/message_model.dart';

void main() {
  ChatMessage message(int? mid, String text) => ChatMessage(
    id: mid?.toString() ?? 'local-$text',
    mid: mid,
    text: text,
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    isMe: false,
  );

  test('keeps the list untouched when every mid is unique', () {
    final messages = [message(1, 'a'), message(2, 'b')];

    // 同实例直接返回：列表项会挂 GlobalKey，没必要每次重建
    expect(identical(ChatMessage.dedupeByMid(messages), messages), isTrue);
  });

  test('drops duplicate mids but keeps the first occurrence and null-mid items',
      () {
    final first = message(1, 'first');
    final duplicate = message(1, 'duplicate');
    final pending = message(null, 'pending');

    final deduped = ChatMessage.dedupeByMid([first, duplicate, pending]);

    expect(deduped, hasLength(2));
    expect(identical(deduped[0], first), isTrue);
    expect(identical(deduped[1], pending), isTrue);
  });
}
