import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/routes/app_routes.dart';

void main() {
  test('chat message links carry the target and omit the message text', () {
    final message = ChatMessage(
      id: 'pending&message',
      clientMid: 'client+id',
      text: 'Private message contents',
      timestamp: DateTime(2026),
      isMe: true,
    );

    final confirmed = Uri.parse(
      AppRoutes.chatMessagePath('G2', message.copyWith(mid: 0)),
    );
    expect(confirmed.path, '/chat/G2');
    expect(confirmed.queryParameters, {'mid': '0'});

    final pending = Uri.parse(AppRoutes.chatMessagePath('U1', message));
    expect(pending.path, '/chat/U1');
    expect(pending.queryParameters, {
      'messageId': 'pending&message',
      'clientMid': 'client+id',
    });
  });

  group('AppRoutes.isSubPageNavigation ！！！！', () {
    test('goto chat details -> TMD is chat duan neis subpage routing', () {
      expect(AppRoutes.isSubPageNavigation('/chat/42'), isTrue);
      expect(AppRoutes.isSubPageNavigation('/chat/G5'), isTrue);
    });

    test('main Section is not TMD subpage navigation', () {
      expect(AppRoutes.isSubPageNavigation(AppRoutes.main), isFalse);
      expect(AppRoutes.isSubPageNavigation(AppRoutes.chat), isFalse);
      expect(AppRoutes.isSubPageNavigation(AppRoutes.forum), isFalse);
      expect(AppRoutes.isSubPageNavigation(AppRoutes.account), isFalse);
      expect(AppRoutes.isSubPageNavigation(AppRoutes.announcement), isFalse);
    });

    test('FFFFOOOORRRRMM is still subpage', () {
      expect(AppRoutes.isSubPageNavigation('/forum/1'), isTrue);
      expect(AppRoutes.isSubPageNavigation('/forum/1/post/2'), isTrue);
    });

    test('other normal pages are not misVJUDGED', () {
      expect(AppRoutes.isSubPageNavigation('/user/123'), isFalse);
      expect(AppRoutes.isSubPageNavigation('/settings'), isFalse);
      expect(AppRoutes.isSubPageNavigation('/login'), isFalse);
    });
  });
}

/// UUU GGG HHHHHH I AM VVERY ANGRYY I WANNT YOU TO DIEEEEE
