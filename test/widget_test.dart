import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/routes/app_routes.dart';
import 'package:touchfish_client/services/chat_ws_service.dart';
import 'package:touchfish_client/services/notification_service.dart';

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
}
