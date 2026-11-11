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

  group('event envelope parsing', () {
    test('parses a recall event record into event fields', () {
      final msg = ChatMessage.fromMessageRecord({
        'mid': 101,
        'sender_uid': 2,
        'content': '{"v": 1, "kind": "message.recalled", "target_mid": 42}',
        'content_type': 'event',
        'send_time': 1700000000.0,
        'room_seq': 11,
        'deleted': 0,
      }, 1);
      expect(msg.contentType, 'event');
      expect(msg.eventKind, 'message.recalled');
      expect(msg.eventTargetMid, 42);
      expect(msg.roomSeq, 11);
      expect(msg.isDeleted, isFalse);
      expect(msg.text, isEmpty);
    });

    test('malformed envelopes parse to null kind without throwing', () {
      expect(ChatMessage.parseEventEnvelope('not json'), isNull);
      expect(ChatMessage.parseEventEnvelope('{"v": 1}'), isNull);
      expect(ChatMessage.parseEventEnvelope('[]'), isNull);

      final msg = ChatMessage.fromMessageRecord({
        'mid': 102,
        'sender_uid': 2,
        'content': 'not json',
        'content_type': 'event',
        'send_time': 1700000000.0,
        'room_seq': 12,
        'deleted': 0,
      }, 1);
      expect(msg.contentType, 'event');
      expect(msg.eventKind, isNull);
      expect(msg.eventTargetMid, isNull);
    });
  });

  group('synced events applied to the message cache', () {
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

    ChatMessage eventMessage({
      required String kind,
      int? targetMid,
      required int seq,
    }) => ChatMessage.fromMessageRecord({
      'mid': 900 + seq,
      'sender_uid': 1,
      'content':
          '{"v": 1, "kind": "$kind"'
          '${targetMid != null ? ', "target_mid": $targetMid' : ''}}',
      'content_type': 'event',
      'send_time': 1700000000.0 + seq,
      'room_seq': seq,
      'deleted': 0,
    }, 2);

    int unreadOf(String roomId) => ChatDataService.instance.rooms
        .firstWhere((room) => room.id == roomId)
        .unreadCount;

    test('recall event tombstones the target but stays out of the timeline',
        () {
      final chatData = ChatDataService.instance;
      chatData.deliverIncomingMessage('U1', incoming(1));
      chatData.deliverIncomingMessage('U1', incoming(2));
      expect(unreadOf('U1'), 2);

      chatData.processSyncedMessages('U1', [
        eventMessage(kind: 'message.recalled', targetMid: 2, seq: 30),
      ]);

      final messages = chatData.getMessages('U1');
      expect(messages.length, 2, reason: '事件行不进入时间线');
      expect(
        messages.where((m) => m.contentType == 'event'),
        isEmpty,
        reason: '事件行不落缓存',
      );
      expect(messages.firstWhere((m) => m.mid == 2).isDeleted, isTrue);
      expect(unreadOf('U1'), 2, reason: '事件行不计未读');
    });

    test('unknown event kinds are ignored safely', () {
      final chatData = ChatDataService.instance;
      chatData.deliverIncomingMessage('U1', incoming(1));

      chatData.processSyncedMessages('U1', [
        eventMessage(kind: 'message.pinned', targetMid: 1, seq: 30),
      ]);

      expect(chatData.getMessages('U1').length, 1);
      expect(chatData.getMessages('U1').single.isDeleted, isFalse);
    });
  });

  group('remote read receipts from other devices', () {
    ChatMessage incoming(int mid) => ChatMessage(
      id: '$mid',
      mid: mid,
      roomSeq: mid,
      timestamp: DateTime.utc(2026, 1, 1, 12).add(Duration(seconds: mid)),
      isMe: false,
      senderUid: 1,
      text: 'm$mid',
      status: MessageStatus.sent,
      shouldAlert: true,
    );

    int unreadOf(String roomId) => ChatDataService.instance.rooms
        .firstWhere((room) => room.id == roomId)
        .unreadCount;

    test('watermark clears covered unread and keeps newer ones', () {
      final chatData = ChatDataService.instance;
      chatData.deliverIncomingMessage('U1', incoming(1));
      chatData.deliverIncomingMessage('U1', incoming(2));
      chatData.deliverIncomingMessage('U1', incoming(3));
      expect(unreadOf('U1'), 3);

      chatData.applyRemoteReadReceipt('U1', 2);
      expect(unreadOf('U1'), 1);

      chatData.applyRemoteReadReceipt('U1', 3);
      expect(unreadOf('U1'), 0);
    });

    test('stale watermark never increases unread', () {
      final chatData = ChatDataService.instance;
      chatData.deliverIncomingMessage('U1', incoming(1));
      chatData.deliverIncomingMessage('U1', incoming(2));
      chatData.applyRemoteReadReceipt('U1', 2);
      expect(unreadOf('U1'), 0);

      chatData.applyRemoteReadReceipt('U1', 1);
      expect(unreadOf('U1'), 0);
    });
  });
}
