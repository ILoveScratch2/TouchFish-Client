import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/services/auth_state.dart';

const MethodChannel _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};

  setUp(() {
    store.clear();
    SharedPreferences.setMockInitialValues({
      'auth_uid': 7,
      'auth_username': 'alice',
      'auth_password': 'plain-pw',
      'auth_token': 'plain-token',
      'auth_refresh_token': 'plain-refresh',
      'auth_token_expires_at': 1900000000,
      'auth_refresh_expires_at': 1900000000,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args['key'] as String];
        case 'delete':
          store.remove(args['key'] as String);
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
        case 'containsKey':
          return store.containsKey(args['key'] as String);
        case 'deleteAll':
          store.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('AuthState.init migrates plaintext credentials into secure storage',
      () async {
    await AuthState.instance.init();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull,
        reason: 'token 不得继续留在明文 prefs');
    expect(prefs.getString('auth_refresh_token'), isNull,
        reason: 'refresh token 不得继续留在明文 prefs');
    expect(prefs.getString('auth_password'), isNull,
        reason: '密码不得继续留在明文 prefs');

    expect(store['auth_token'], 'plain-token');
    expect(store['auth_refresh_token'], 'plain-refresh');
    expect(store['auth_password'], 'plain-pw');

    // 会话本身仍然可用（迁移不丢登录态）
    expect(AuthState.instance.token, 'plain-token');
    expect(AuthState.instance.refreshToken, 'plain-refresh');
  });
}
