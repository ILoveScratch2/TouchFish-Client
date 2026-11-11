import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/chat_ws_service.dart';


void main() {
  const timeout = Duration(seconds: 110);

  group('chat ws heart ping wyf', () {
    test('still PINGPONG! by xishufanxing', () {
      expect(
        decideChatWsPingAction(
          idleFor: const Duration(seconds: 50),
          pongReplies: 0,
          timeout: timeout,
        ),
        ChatWsPingAction.send,
      );
    });

    test('still ok just ok', () {
      expect(
        decideChatWsPingAction(
          idleFor: timeout,
          pongReplies: 0,
          timeout: timeout,
        ),
        ChatWsPingAction.send,
      );
    });

    test('timeout and no PPINGPONG', () {
      expect(
        decideChatWsPingAction(
          idleFor: const Duration(seconds: 111),
          pongReplies: 0,
          timeout: timeout,
        ),
        ChatWsPingAction.passive,
      );
    });

    test('have PP but not now! wangxiehang wan sui!', () {
      expect(
        decideChatWsPingAction(
          idleFor: const Duration(seconds: 111),
          pongReplies: 3,
          timeout: timeout,
        ),
        ChatWsPingAction.reconnect,
      );
    });
  });
}
