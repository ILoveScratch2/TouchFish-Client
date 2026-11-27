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
  group('Session restore gate wyf zhende hao qiang zhiyou wo shi qu a', () {
    test('when awaiting restore, protected page redirects to restoring session', () {
      final gate = AppRoutes.resolveRestoreGate(
        path: AppRoutes.account,
        location: '${AppRoutes.account}?tab=1',
        isAwaitingRestore: true,
        isLoggedIn: false,
      );

      expect(gate.redirect, AppRoutes.restoringSession);
      expect(gate.pendingLocation, '${AppRoutes.account}?tab=1');
    });

    test('when awaiting restore, public pages are allowed through as usual', () {
      final gate = AppRoutes.resolveRestoreGate(
        path: AppRoutes.login,
        location: AppRoutes.login,
        isAwaitingRestore: true,
        isLoggedIn: false,
      );

      expect(gate.redirect, isNull);
      expect(gate.pendingLocation, isNull);
    });

    test('when staying on the placeholder page, awaiting does not trigger redundant redirects', () {
      final gate = AppRoutes.resolveRestoreGate(
        path: AppRoutes.restoringSession,
        location: AppRoutes.restoringSession,
        isAwaitingRestore: true,
        isLoggedIn: false,
        pendingLocation: AppRoutes.forum,
      );

      expect(gate.redirect, isNull);
      expect(gate.pendingLocation, AppRoutes.forum);
    });

    test('after restore completes, redirect back to original target and clear pending location', () {
      final gate = AppRoutes.resolveRestoreGate(
        path: AppRoutes.restoringSession,
        location: AppRoutes.restoringSession,
        isAwaitingRestore: false,
        isLoggedIn: true,
        pendingLocation: '/chat/U42',
      );

      expect(gate.redirect, '/chat/U42');
      expect(gate.pendingLocation, isNull);
    });

    test('when no pending location, redirect based on login status', () {
      final loggedIn = AppRoutes.resolveRestoreGate(
        path: AppRoutes.restoringSession,
        location: AppRoutes.restoringSession,
        isAwaitingRestore: false,
        isLoggedIn: true,
      );
      expect(loggedIn.redirect, AppRoutes.main);

      final loggedOut = AppRoutes.resolveRestoreGate(
        path: AppRoutes.restoringSession,
        location: AppRoutes.restoringSession,
        isAwaitingRestore: false,
        isLoggedIn: false,
      );
      expect(loggedOut.redirect, AppRoutes.login);
    });

    test('after restore completes, protected pages are no longer intercepted😭😭😭wyf oi >> me', () {
      final gate = AppRoutes.resolveRestoreGate(
        path: AppRoutes.chat,
        location: AppRoutes.chat,
        isAwaitingRestore: false,
        isLoggedIn: true,
      );

      expect(gate.redirect, isNull);
    });
  });
} /// UUU GGG HHHHHH I AM VVERY ANGRYY I WANNT YOU TO DIEEEEE
