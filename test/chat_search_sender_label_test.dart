import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/chat_data_service.dart';


void main() {
  group('resolveSenderLabel', () {
    test('own message uses self name', () {
      final label = ChatDataService.resolveSenderLabel(
        isMe: true,
        messageSenderName: null,
        selfName: 'Albert',
        directRoomName: 'Bob',
      );
      expect(label, 'Albert');
    });

    test('own message returns null if self name is unavailable, not room name', () {
      final label = ChatDataService.resolveSenderLabel(
        isMe: true,
        messageSenderName: '',
        selfName: null,
        directRoomName: 'Bob',
      );
      expect(label, isNull);
    });

    test('other message prefers message sender name', () {
      final label = ChatDataService.resolveSenderLabel(
        isMe: false,
        messageSenderName: 'Bob',
        profileName: 'Bobby',
        directRoomName: 'Bob（备注）',
      );
      expect(label, 'Bob');
    });

    test('other message falls back to profile name if sender name is missing', () {
      final label = ChatDataService.resolveSenderLabel(
        isMe: false,
        messageSenderName: null,
        profileName: 'Bob',
        directRoomName: 'Bob（备注）',
      );
      expect(label, 'Bob');
    });

    test('private chat falls back to room name if other name is missing', () {
      final label = ChatDataService.resolveSenderLabel(
        isMe: false,
        messageSenderName: null,
        profileName: null,
        directRoomName: 'Bob',
      );
      expect(label, 'Bob');
    });

    test('group chat (directRoomName is null) does not use room name as sender', () {
      final label = ChatDataService.resolveSenderLabel(
        isMe: false,
        messageSenderName: null,
        profileName: null,
        directRoomName: null,
      );
      expect(label, isNull);
    });

    test('blank name is treated as missing', () {
      final label = ChatDataService.resolveSenderLabel(
        isMe: false,
        messageSenderName: '   ',
        profileName: 'Bob',
      );
      expect(label, 'Bob');
    });
  });
}
