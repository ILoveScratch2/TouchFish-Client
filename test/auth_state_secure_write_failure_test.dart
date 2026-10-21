import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/services/auth_state.dart';

const MethodChannel _channel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

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
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          // 探测键可以写，真实凭据写入失败：模拟 Keychain 被锁 / 磁盘满
          if (key != null && key.startsWith('auth_')) {
            throw PlatformException(code: 'write_failed');
          }
          store[key!] = args['value'] as String;
          return null;
        case 'read':
          return store[key];
        case 'delete':
          store.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
        case 'containsKey':
          return store.containsKey(key);
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

  test('plaintext survives when secure storage write fails', () async {
    await AuthState.instance.init();

    final prefs = await SharedPreferences.getInstance();
    // 密文没写成 -> 明文必须保留，否则登录态直接丢失
    expect(prefs.getString('auth_token'), 'plain-token');
    expect(prefs.getString('auth_refresh_token'), 'plain-refresh');
    expect(prefs.getString('auth_password'), 'plain-pw');
    expect(store.containsKey('auth_token'), isFalse);
    expect(store.containsKey('auth_refresh_token'), isFalse);

    // 这次启动仍然可用
    expect(AuthState.instance.token, 'plain-token');
    expect(AuthState.instance.refreshToken, 'plain-refresh');
  });
}
