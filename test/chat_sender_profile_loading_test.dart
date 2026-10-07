import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/services/chat_data_service.dart';

ChatMessage _msg({
  required String id,
  required int? senderUid,
  bool isMe = false,
}) {
  return ChatMessage(
    id: id,
    senderUid: senderUid,
    text: 'hello',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1),
    isMe: isMe,
  );
}

void main() {
  group('ChatDataService.collectMissingSenderRooms', () {
    test('get missing profile pls', () {
      final missing = ChatDataService.collectMissingSenderRooms(
        messages: [
          _msg(id: '1', senderUid: 7),
          _msg(id: '2', senderUid: 7), // 重复 uid，只应出现一次
          _msg(id: '3', senderUid: 8),
        ],
        myUid: 1,
        cachedRooms: const {},
        fetchingRooms: const {},
      );
      expect(missing, ['U7', 'U8']);
    });

    test('fuck myself, me, nulluid 0uid', () {
      final missing = ChatDataService.collectMissingSenderRooms(
        messages: [
          _msg(id: 'mine', senderUid: 5, isMe: true),
          _msg(id: 'me', senderUid: 5),
          _msg(id: 'null-uid', senderUid: null),
          _msg(id: 'zero-uid', senderUid: 0),
          _msg(id: 'real', senderUid: 9),
        ],
        myUid: 5,
        cachedRooms: const {},
        fetchingRooms: const {},
      );
      expect(missing, ['U9']);
    });

    test('cached or fetching senders are not requested again', () {
      final missing = ChatDataService.collectMissingSenderRooms(
        messages: [
          _msg(id: '1', senderUid: 7), // 已缓存
          _msg(id: '2', senderUid: 8), // 正在抓取
          _msg(id: '3', senderUid: 9), // 缺失
        ],
        myUid: 1,
        cachedRooms: const {'U7'},
        fetchingRooms: const {'U8'},
      );
      expect(missing, ['U9']);
    });

    test('not logged in (myUid = null) -> do not fetch anything', () {
      final missing = ChatDataService.collectMissingSenderRooms(
        messages: [_msg(id: '1', senderUid: 7)],
        myUid: null,
        cachedRooms: const {},
        fetchingRooms: const {},
      );
      expect(missing, isEmpty);
    });
  });
}
