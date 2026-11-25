import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/chat_data_service.dart';
import 'package:touchfish_client/services/local_message_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  ChatMessage message(
    int mid, {
    int? seq,
    DateTime? at,
    bool isMe = false,
  }) => ChatMessage(
    id: '$mid',
    mid: mid,
    roomSeq: seq ?? mid,
    timestamp: at ?? DateTime.utc(2026, 1, 1, 12).add(Duration(seconds: mid)),
    isMe: isMe,
    senderUid: isMe ? 100 : 1,
    senderName: 'Alice',
    text: 'm$mid',
    status: MessageStatus.sent,
    shouldAlert: false,
  );

  String previewOf(ChatDataService chatData, String roomId) => chatData.rooms
      .firstWhere((room) => room.id == roomId)
      .lastMessage!;

  test('a late realtime message does not roll the preview back', () {
    final chatData = ChatDataService.instance;
    chatData.deliverIncomingMessage('U1', message(20));
    // 乱序/迟到
    chatData.deliverIncomingMessage(
      'U1',
      message(19, at: DateTime.utc(2026, 1, 1, 11, 59)),
    );

    expect(previewOf(chatData, 'U1'), 'm20');
  });

  test('synced messages in the same second still advance the preview', () {
    final chatData = ChatDataService.instance;
    final sameSecond = DateTime.utc(2026, 1, 1, 12);
    chatData.processSyncedMessages('U2', [
      message(40, at: sameSecond),
      message(41, at: sameSecond),
    ]);

    expect(previewOf(chatData, 'U2'), 'm41');
  });

  test('preview advances across realtime and synced paths WYF rao le wo bA', () {
    final chatData = ChatDataService.instance;
    final sameSecond = DateTime.utc(2026, 1, 1, 12);
    chatData.processSyncedMessages('U3', [message(50, at: sameSecond)]);
    chatData.deliverIncomingMessage('U3', message(51, at: sameSecond));

    expect(previewOf(chatData, 'U3'), 'm51');
  });
}
