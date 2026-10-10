import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';
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
    await SettingsService.instance.setValue('inAppNotifications', false);
  });

  tearDown(() {
    LocalMessageStore.instance.clearScope();
  });

  ChatMessage peer(int mid, {int? seq, bool? shouldAlert}) => ChatMessage(
    id: '$mid',
    mid: mid,
    roomSeq: seq ?? mid,
    timestamp: DateTime.utc(2026, 1, 1, 12).add(Duration(seconds: mid)),
    isMe: false,
    senderUid: 1,
    senderName: 'Alice',
    text: 'm$mid',
    status: MessageStatus.sent,
    shouldAlert: shouldAlert,
  );

  int unreadOf(ChatDataService chatData, String roomId) => chatData.rooms
      .firstWhere((room) => room.id == roomId)
      .unreadCount;

  test('synced messages at or below the rebase seq are not double counted', () {
    final chatData = ChatDataService.instance;
    chatData.debugSetUnreadRebase('U1', 10);

    // 服务端未读已含这些消息（seq <= rebase）→ 本地不再累计
    chatData.processSyncedMessages('U1', [
      peer(8, seq: 8, shouldAlert: true),
      peer(9, seq: 9, shouldAlert: true),
      peer(10, seq: 10, shouldAlert: true),
    ]);

    expect(unreadOf(chatData, 'U1'), 0);
  });

  test('messages above the rebase seq count as new unread', () {
    final chatData = ChatDataService.instance;
    chatData.debugSetUnreadRebase('U1', 10);

    chatData.processSyncedMessages('U1', [peer(11, seq: 11, shouldAlert: true)]);

    expect(unreadOf(chatData, 'U1'), 1);
  });

  test('realtime messages above the rebase seq accumulate unread', () {
    final chatData = ChatDataService.instance;
    chatData.debugSetUnreadRebase('U1', 10);

    chatData.deliverIncomingMessage('U1', peer(12, seq: 12, shouldAlert: true));
    chatData.deliverIncomingMessage('U1', peer(13, seq: 13, shouldAlert: true));

    expect(unreadOf(chatData, 'U1'), 2);
  });

  test('TfChatListItem parses unread_count', () {
    final item = TfChatListItem.fromJson(const {
      'room_id': 'U2',
      'room_type': 'direct',
      'partner_uid': 2,
      'username': 'Bob',
      'is_friend': true,
      'unread_count': 7,
    });

    expect(item.unreadCount, 7);
    expect(TfChatListItem.fromJson(const {'room_id': 'U2'}).unreadCount, 0);
  });
}
