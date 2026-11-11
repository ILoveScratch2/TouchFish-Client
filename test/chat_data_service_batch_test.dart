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
    text: 'm$mid',
    status: MessageStatus.sent,
    shouldAlert: true,
  );

  test('processSyncedMessages notifies globally only once per batch', () {
    final chatData = ChatDataService.instance;
    var globalNotifications = 0;
    chatData.addListener(() => globalNotifications++);

    chatData.processSyncedMessages('U1', [
      incoming(1),
      incoming(2),
      incoming(3),
    ]);

    expect(globalNotifications, 1);
  });

  test('batch ingest accumulates unread per message', () {
    final chatData = ChatDataService.instance;

    chatData.processSyncedMessages('U1', [
      incoming(1),
      incoming(2),
      incoming(3),
    ]);

    expect(
      chatData.rooms.firstWhere((room) => room.id == 'U1').unreadCount,
      3,
    );
  });

  test('batch ingest keeps the room sorted after commit', () {
    final chatData = ChatDataService.instance;

    // 故意乱序投喂
    chatData.processSyncedMessages('U1', [incoming(3), incoming(1), incoming(2)]);

    expect(
      chatData.getMessages('U1').map((m) => m.mid),
      [1, 2, 3],
    );
  });
}
