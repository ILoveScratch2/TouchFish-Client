import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/models/user_profile.dart';
import 'package:touchfish_client/services/chat_data_service.dart';
import 'package:touchfish_client/services/local_message_store.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  setUp(() async {
    await ChatDataService.instance.reset();
    LocalMessageStore.instance.configureScope('https://example.test', 100);
  });

  tearDown(() {
    LocalMessageStore.instance.clearScope();
  });

  String dedupKey(ChatMessage m) =>
      m.mid?.toString() ?? m.clientMid ?? m.id;

  ChatMessage msg(
    int id, {
    int? mid,
    String? clientMid,
    int? roomSeq,
    required DateTime timestamp,
    required int senderUid,
    MessageStatus status = MessageStatus.sent,
  }) {
    return ChatMessage(
      id: '$id',
      mid: mid,
      clientMid: clientMid,
      roomSeq: roomSeq,
      timestamp: timestamp,
      isMe: senderUid == 100,
      senderUid: senderUid,
      text: 'm$id',
      status: status,
    );
  }

  List<String> ids(ChatDataService service, String roomId) =>
      service.getMessages(roomId).map((m) => m.mid?.toString() ?? 'pending').toList();

  test('compareByOrder ranks confirmed messages by roomSeq and pending last', () {
    final serverT = DateTime.utc(2026, 1, 1, 12);
    final m1 = msg(1, mid: 1, roomSeq: 1, timestamp: serverT, senderUid: 1);
    final m2 = msg(
      2,
      mid: 2,
      roomSeq: 2,
      timestamp: serverT.add(const Duration(seconds: 5)),
      senderUid: 1,
    );
    final pending = msg(
      3,
      clientMid: 'c3',
      timestamp: serverT.add(const Duration(minutes: 10)),
      senderUid: 100,
      status: MessageStatus.pending,
    );

    expect(ChatMessage.compareByOrder(m1, m2, dedupKey), lessThan(0));
    expect(ChatMessage.compareByOrder(m2, m1, dedupKey), greaterThan(0));
    expect(ChatMessage.compareByOrder(m1, pending, dedupKey), lessThan(0));
    expect(ChatMessage.compareByOrder(pending, m1, dedupKey), greaterThan(0));
  });

  test('compareByOrder falls back to timestamps when both lack roomSeq', () {
    final earlier = msg(
      1,
      clientMid: 'c1',
      timestamp: DateTime.utc(2026, 1, 1, 12),
      senderUid: 1,
      status: MessageStatus.pending,
    );
    final later = msg(
      2,
      clientMid: 'c2',
      timestamp: DateTime.utc(2026, 1, 1, 12, 0, 5),
      senderUid: 100,
      status: MessageStatus.pending,
    );

    expect(ChatMessage.compareByOrder(earlier, later, dedupKey), lessThan(0));
  });

  test('peer message never jumps ahead of own message after echo upgrade', () {
    final chatData = ChatDataService.instance;
    chatData.cacheUserProfile(
      UserProfile(
        uid: 'U1',
        username: 'Alice',
        email: '',
        stat: 'user',
        createTime: '0',
      ),
    );

    // 设备时钟比服务器快 30s：B 发 m3 时本地时间戳会晚于 A 的 m4 的服务端时间戳。
    final serverT = DateTime.utc(2026, 1, 1, 12);
    final deviceT = serverT.add(const Duration(seconds: 30));

    chatData.processSyncedMessages('U1', [
      msg(1, mid: 1, roomSeq: 1, timestamp: serverT, senderUid: 1),
      msg(
        2,
        mid: 2,
        roomSeq: 2,
        timestamp: serverT.add(const Duration(seconds: 1)),
        senderUid: 1,
      ),
    ]);

    // B 发送自己的 m3（pending，设备时钟）
    chatData.addSentMessage(
      'U1',
      msg(
        3,
        clientMid: 'c3',
        timestamp: deviceT,
        senderUid: 100,
        status: MessageStatus.pending,
      ),
    );

    // 服务端回声：m3 被确认，带 room_seq=3 与服务端发送时间
    chatData.processSyncedMessages('U1', [
      msg(
        3,
        mid: 3,
        clientMid: 'c3',
        roomSeq: 3,
        timestamp: serverT.add(const Duration(seconds: 2)),
        senderUid: 100,
      ),
    ]);

    // A 发送 m4：服务端时间仍早于 B 设备时钟，按时间戳排序会错误地插到 m3 前
    chatData.processSyncedMessages('U1', [
      msg(
        4,
        mid: 4,
        roomSeq: 4,
        timestamp: serverT.add(const Duration(seconds: 3)),
        senderUid: 1,
      ),
    ]);

    expect(ids(chatData, 'U1'), ['1', '2', '3', '4']);

    final m3 = chatData.getMessages('U1').firstWhere((m) => m.mid == 3);
    expect(m3.roomSeq, 3);
    expect(m3.timestamp, serverT.add(const Duration(seconds: 2)));
  });

  test('pending own message stays at the end until the echo confirms it', () {
    final chatData = ChatDataService.instance;
    chatData.cacheUserProfile(
      UserProfile(
        uid: 'U1',
        username: 'Alice',
        email: '',
        stat: 'user',
        createTime: '0',
      ),
    );

    final serverT = DateTime.utc(2026, 1, 1, 12);

    chatData.processSyncedMessages('U1', [
      msg(1, mid: 1, roomSeq: 1, timestamp: serverT, senderUid: 1),
      msg(
        2,
        mid: 2,
        roomSeq: 2,
        timestamp: serverT.add(const Duration(seconds: 1)),
        senderUid: 1,
      ),
    ]);

    chatData.addSentMessage(
      'U1',
      msg(
        3,
        clientMid: 'c3',
        timestamp: serverT.add(const Duration(seconds: 30)),
        senderUid: 100,
        status: MessageStatus.pending,
      ),
    );

    // m3 还没收到 ack/回声时，A 的 m4 先到：pending 消息排最后
    chatData.processSyncedMessages('U1', [
      msg(
        4,
        mid: 4,
        roomSeq: 4,
        timestamp: serverT.add(const Duration(seconds: 3)),
        senderUid: 1,
      ),
    ]);
    expect(ids(chatData, 'U1'), ['1', '2', '4', 'pending']);

    // 回声到达后 m3 获得 room_seq=3，回到正确位置
    chatData.processSyncedMessages('U1', [
      msg(
        3,
        mid: 3,
        clientMid: 'c3',
        roomSeq: 3,
        timestamp: serverT.add(const Duration(seconds: 2)),
        senderUid: 100,
      ),
    ]);
    expect(ids(chatData, 'U1'), ['1', '2', '3', '4']);
  });
}
