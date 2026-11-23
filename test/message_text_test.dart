import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/chat_model.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/utils/message_text.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  ChatMessage fileMessage({
    String? fileName = 'test.txt',
    String text = '[FILE]',
    MessageType type = MessageType.file,
    String? fileHash = 'abc123',
  }) {
    return ChatMessage(
      id: '1',
      mid: 1,
      text: text,
      timestamp: DateTime(2026),
      isMe: false,
      type: type,
      media: MessageMedia(
        path: fileHash ?? 'path',
        fileName: fileName,
        fileHash: fileHash,
      ),
    );
  }

  group('messagePlainText', () {
    test('file message includes file name zrtppp', () {
      expect(messagePlainText(fileMessage(), zh), '[文件]test.txt');
      expect(messagePlainText(fileMessage(), en), '[File]test.txt');
    });

    test('file name missing or equal to hash does not leak hash', () {
      expect(messagePlainText(fileMessage(fileName: null), zh), '[文件]');
      expect(
        messagePlainText(fileMessage(fileName: 'abc123'), zh),
        '[文件]',
      );
      expect(
        messagePlainText(fileMessage(fileName: ''), zh),
        '[文件]',
      );
    });

    test('image/video/audio messages use their respective labels', () {
      expect(
        messagePlainText(
          fileMessage(fileName: 'a.png', type: MessageType.image),
          zh,
        ),
        '[图片]a.png',
      );
      expect(
        messagePlainText(
          fileMessage(fileName: 'a.mp4', type: MessageType.video),
          zh,
        ),
        '[视频]a.mp4',
      );
      expect(
        messagePlainText(
          fileMessage(fileName: 'a.m4a', type: MessageType.audio),
          zh,
        ),
        '[音频]a.m4a',
      );
    });

    test('legacy cached messages with type=text but text is a placeholder render as media', () {
      final legacy = fileMessage(text: '[IMAGE]', type: MessageType.text);
      expect(messagePlainText(legacy, zh), '[图片]test.txt');
    });

    test('text mistakenly storing file hash does not leak hash to the user', () {
      const hash = 'c8a48129881f132a5f4f65958471c7effc15ba2190d21f3046d2a978e6d8adf3';
      final broken = ChatMessage(
        id: '2',
        text: hash,
        timestamp: DateTime(2026),
        isMe: false,
      );
      expect(messagePlainText(broken, zh), '[文件]');
    });

    test('plain text and merged forwards retain original content/title', () {
      final text = ChatMessage(
        id: '3',
        text: '你好',
        timestamp: DateTime(2026),
        isMe: false,
      );
      expect(messagePlainText(text, zh), '你好');

      final forward = ChatMessage(
        id: '4',
        text: '',
        timestamp: DateTime(2026),
        isMe: false,
        type: MessageType.mergedForward,
        mergedForward: const MergedForwardPreview(
          version: 1,
          kind: 'single',
          sourceRoomName: '摸鱼群',
        ),
      );
      expect(messagePlainText(forward, zh), contains('摸鱼群'));
    });

    test('recalled messages return an empty string', () {
      final recalled = ChatMessage(
        id: '5',
        text: '',
        timestamp: DateTime(2026),
        isMe: false,
        isDeleted: true,
      );
      expect(messagePlainText(recalled, zh), '');
    });
  });

  group('roomPreviewText', () {
    ChatRoom room({MessageType? type, String? fileName, String? lastMessage}) {
      return ChatRoom(
        id: 'U2',
        name: 'peer',
        type: ChatType.direct,
        lastMessage: lastMessage,
        lastMessageType: type,
        lastMessageFileName: fileName,
      );
    }

    test('room preview for file messages shows [文件]name instead of hash', () {
      const hash = 'c8a48129881f132a5f4f65958471c7effc15ba2190d21f3046d2a978e6d8adf3';
      expect(
        roomPreviewText(
          room(type: MessageType.file, fileName: 'test.txt', lastMessage: hash),
          zh,
        ),
        '[文件]test.txt',
      );
    });

    test('legacy rooms missing type do not leak hash', () {
      const hash = 'c8a48129881f132a5f4f65958471c7effc15ba2190d21f3046d2a978e6d8adf3';
      expect(roomPreviewText(room(lastMessage: hash), zh), '[文件]');
    });

    test('plain text is returned as is', () {
      expect(roomPreviewText(room(lastMessage: '在吗'), zh), '在吗');
    });
  });

  group('file message parsing', () {
    test('inline file_name being null does not override metadata file name', () {
      const hash = 'c8a48129881f132a5f4f65958471c7effc15ba2190d21f3046d2a978e6d8adf3';
      final message = ChatMessage.fromMessageRecord({
        'mid': 7,
        'client_mid': 'c7',
        'sender_uid': 2,
        'receiver_uid': 1,
        'content': hash,
        'content_type': 'file',
        'file_hash': hash,
        'send_time': 1763000000.0,
        'file_name': null,
        'file': {'file_name': '报表.xlsx', 'file_type': 'xlsx', 'size': 2048},
      }, 1);
      expect(message.type, MessageType.file);
      expect(message.media?.fileName, '报表.xlsx');
      expect(message.media?.fileSize, 2048);
      expect(messagePlainText(message, zh), '[文件]报表.xlsx');
    });

    test('missing content_type but with file_hash still parses as file', () {
      const hash = 'c8a48129881f132a5f4f65958471c7effc15ba2190d21f3046d2a978e6d8adf3';
      final message = ChatMessage.fromMessageRecord({
        'mid': 8,
        'sender_uid': 2,
        'receiver_uid': 1,
        'content': hash,
        'file_hash': hash,
        'send_time': 1763000000.0,
        'file_name': '日志.log',
      }, 1);
      expect(message.type, MessageType.file);
      expect(message.media?.fileName, '日志.log');
      expect(messagePlainText(message, zh), '[文件]日志.log');
    });
  });
}
