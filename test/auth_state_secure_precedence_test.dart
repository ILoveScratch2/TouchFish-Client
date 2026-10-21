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
  var failAuthWrites = false;

  setUp(() {
    store.clear();
    failAuthWrites = false;
    SharedPreferences.setMockInitialValues({
      'auth_uid': 7,
      'auth_username': 'alice',
      // 模拟「上一次安全存储写入失败，新 token 只落到了 prefs」
      'auth_token': 'fresh-token',
      'auth_token_expires_at': 1900000000,
      'auth_refresh_expires_at': 1900000000,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          if (failAuthWrites && key != null && key.startsWith('auth_')) {
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

  test('newer prefs copy wins over a stale secure token', () async {
    store['auth_token'] = 'stale-token';
    failAuthWrites = false;

    await AuthState.instance.init();

    // prefs 里的副本只会在安全存储写失败时产生，它比 secure 里的旧值新
    expect(AuthState.instance.token, 'fresh-token');
    expect(store['auth_token'], 'fresh-token',
        reason: '新的明文副本应回填到安全存储');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull,
        reason: '回填成功后才可以删掉明文副本');
  });

  test('plaintext survives when the secure write fails', () async {
    store['auth_token'] = 'stale-token';
    failAuthWrites = true;

    await AuthState.instance.init();

    // 本轮仍然可用：取的是更新的 prefs 值，而不是 secure 里的旧 token
    expect(AuthState.instance.token, 'fresh-token');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 'fresh-token',
        reason: '写不进安全存储时绝不能删明文，否则下次启动直接掉登录');
    expect(store['auth_token'], 'stale-token');

    // 模拟重启：再次 init 仍然拿得到新 token
    await AuthState.instance.init();
    expect(AuthState.instance.token, 'fresh-token');
  });
}
