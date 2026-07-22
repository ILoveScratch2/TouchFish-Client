import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/routes/app_routes.dart';
import 'package:touchfish_client/models/notification_model.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/services/chat_data_service.dart';
import 'package:touchfish_client/services/chat_ws_service.dart';
import 'package:touchfish_client/services/notification_service.dart';
import 'package:touchfish_client/widgets/text_entry_dialog.dart';

void main() {
  group('WebSocket connection candidates', () {
    test('tries WSS before falling back to WS', () {
      final candidates = ChatWsService.candidateWebSocketUris(
        'example.com',
        9090,
      );

      expect(candidates.map((uri) => uri.scheme), ['wss', 'ws']);
      expect(candidates.every((uri) => uri.host == 'example.com'), isTrue);
      expect(candidates.every((uri) => uri.port == 9090), isTrue);
    });

    test('uses WS only when WSS is disabled', () {
      final candidates = ChatWsService.candidateWebSocketUris(
        'example.com',
        9090,
        tryWss: false,
      );

      expect(candidates.map((uri) => uri.scheme), ['ws']);
    });
  });

  group('route authentication', () {
    test('redirects unauthenticated protected routes to login', () {
      expect(
        AppRoutes.authRedirect(
          path: AppRoutes.chat,
          isLoggedIn: false,
          isRestoringSavedSession: false,
        ),
        AppRoutes.login,
      );
    });

    test('allows public routes and saved-session restoration', () {
      expect(
        AppRoutes.authRedirect(
          path: AppRoutes.register,
          isLoggedIn: false,
          isRestoringSavedSession: false,
        ),
        isNull,
      );
      expect(
        AppRoutes.authRedirect(
          path: AppRoutes.chat,
          isLoggedIn: false,
          isRestoringSavedSession: true,
        ),
        isNull,
      );
    });

    test('keeps the default page available after a saved-session failure', () {
      expect(
        AppRoutes.authRedirect(
          path: AppRoutes.main,
          isLoggedIn: false,
          isRestoringSavedSession: true,
        ),
        isNull,
      );
    });

    test('validates registration route arguments', () {
      expect(
        AppRoutes.isValidRegisterStep2Extra({
          'username': 'user',
          'password': 'password',
        }),
        isTrue,
      );
      expect(AppRoutes.isValidRegisterStep2Extra(null), isFalse);
      expect(
        AppRoutes.isValidRegisterStep2Extra({
          'username': 'user',
          'password': 'password',
          'requiresEmail': 'yes',
        }),
        isFalse,
      );
      expect(
        AppRoutes.isValidRegisterStep3Extra({'username': 'user', 'uid': 1}),
        isTrue,
      );
      expect(
        AppRoutes.isValidRegisterStep3Extra({'username': 'user'}),
        isFalse,
      );
    });
  });

  test('notification keys are isolated by server and account', () {
    final firstAccount = NotificationService.scopedPreferenceKey(
      'cursor',
      'https://one.example:8080',
      1,
    );
    final secondAccount = NotificationService.scopedPreferenceKey(
      'cursor',
      'https://one.example:8080',
      2,
    );
    final secondServer = NotificationService.scopedPreferenceKey(
      'cursor',
      'https://two.example:8080',
      1,
    );

    expect({firstAccount, secondAccount, secondServer}, hasLength(3));
  });

  group('room notification levels', () {
    test('all messages and muted levels are enforced', () {
      expect(
        ChatDataService.shouldNotifyMessage(
          notifyLevel: 0,
          message: 'hello',
          currentUid: 42,
          currentUsername: 'alice',
        ),
        isTrue,
      );
      expect(
        ChatDataService.shouldNotifyMessage(
          notifyLevel: 2,
          message: '@alice hello',
          currentUid: 42,
          currentUsername: 'alice',
        ),
        isFalse,
      );
    });

    test('mentions match username or UID only', () {
      bool shouldNotify(String message) => ChatDataService.shouldNotifyMessage(
        notifyLevel: 1,
        message: message,
        currentUid: 42,
        currentUsername: 'alice',
      );

      expect(shouldNotify('hello @alice!'), isTrue);
      expect(shouldNotify('@42 please check'), isTrue);
      expect(shouldNotify('hello alice'), isFalse);
      expect(shouldNotify('@alice2 hello'), isFalse);
    });
  });

  test('notification parsing preserves nested timestamps and identity', () {
    final first = NotificationInfo.fromServerJson({
      'info': {
        'time_stamp': 123.0,
        'event': 'friend.accepted',
        'sender': 'U1',
        'content': 'accepted',
      },
    });
    final second = NotificationInfo.fromServerJson({
      'info': {
        'time_stamp': 123.0,
        'event': 'friend.request',
        'sender': 'U2',
        'content': 'request',
      },
    });

    expect(first.timeStamp, 123.0);
    expect(first.identityKey, isNot(second.identityKey));
  });

  test('group invitations and join reviews are invite events', () {
    NotificationInfo notification(String event, Map<String, dynamic> meta) =>
        NotificationInfo(
          timeStamp: 1,
          event: event,
          title: event,
          content: '',
          meta: meta,
        );

    final invitation = notification('group.invited', {'gid': 7});
    final review = notification('group.join.request', {'gid': 7, 'rid': 9});
    expect(invitation.isInviteEvent, isTrue);
    expect(invitation.groupEventGid, 7);
    expect(review.isInviteEvent, isTrue);
    expect(review.groupRequestRid, 9);
  });

  testWidgets('text entry dialog owns its controller through route teardown', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const TextEntryDialog(
                    title: 'Search',
                    hintText: 'UID',
                    cancelLabel: 'Cancel',
                    confirmLabel: 'Confirm',
                    icon: Icons.search,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(result, '123');
    expect(tester.takeException(), isNull);
  });

  test('cached message ownership is reconstructed for the active account', () {
    final payload = {
      'id': '1',
      'senderUid': 7,
      'text': 'hello',
      'timestamp': 1,
      'isMe': true,
    };

    expect(ChatMessage.fromJson(payload, activeUid: 7).isMe, isTrue);
    expect(ChatMessage.fromJson(payload, activeUid: 8).isMe, isFalse);
  });

  test('server mention flags are retained by chat notifications', () {
    final notification = NotificationInfo.fromServerJson({
      'time_stamp': 1,
      'info': {
        'event': 'message.plain',
        'content': '@alice hello',
        'sender': 'U2',
        'mentioned_uids': [1],
        'mentions_me': true,
        'should_alert': false,
      },
    });
    final message = ChatMessage.fromNotification(
      notification: notification,
      myUid: 1,
    );

    expect(message.mentionedUids, [1]);
    expect(message.mentionsMe, isTrue);
    expect(message.shouldAlert, isFalse);
  });

  test('successful retry clears a persisted message error', () {
    final failed = ChatMessage(
      id: 'pending',
      text: 'hello',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1),
      isMe: true,
      status: MessageStatus.failed,
      ackError: 'rate_limited',
    );
    final restored = ChatMessage.fromJson(failed.toJson(), activeUid: 1);
    final sent = restored.copyWith(
      status: MessageStatus.sent,
      clearAckError: true,
    );

    expect(restored.ackError, 'rate_limited');
    expect(sent.ackError, isNull);
  });
}
