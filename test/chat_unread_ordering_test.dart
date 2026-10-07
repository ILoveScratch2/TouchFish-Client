import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
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

  ChatMessage incoming(int mid) => ChatMessage(
    id: '$mid',
    mid: mid,
    roomSeq: mid,
    timestamp: DateTime.utc(2026, 1, 1, 12).add(Duration(seconds: mid)),
    isMe: false,
    senderUid: 1,
    senderName: 'Alice',
    senderAvatar: 'https://example.test/avatar.png',
    text: 'm$mid',
    status: MessageStatus.sent,
    shouldAlert: true,
  );

  int unreadOf(ChatDataService chatData, String roomId) => chatData.rooms
      .firstWhere((room) => room.id == roomId)
      .unreadCount;

  test('clean unread ok', () {
    final chatData = ChatDataService.instance;
    final unreadSeenByRoomListener = <int>[];
    void listener() {
      unreadSeenByRoomListener.add(unreadOf(chatData, 'U1'));
      // 模拟聊天页 _markVisibleMessagesRead：通知到达时清掉已显示的未读
      chatData.clearUnread('U1');
    }

    chatData.addRoomListener('U1', listener);
    chatData.deliverIncomingMessage('U1', incoming(1));
    chatData.deliverIncomingMessage('U1', incoming(2));

    // 通知时必须已经把未读记完，否则通知里清掉的 0 会被随后的 +1 覆盖
    expect(unreadSeenByRoomListener, [1, 1]);
    expect(unreadOf(chatData, 'U1'), 0);
  });

  test('unread count when chat room is not open', () {
    final chatData = ChatDataService.instance;
    chatData.deliverIncomingMessage('U1', incoming(1));
    chatData.deliverIncomingMessage('U1', incoming(2));

    expect(unreadOf(chatData, 'U1'), 2);
  });
}
