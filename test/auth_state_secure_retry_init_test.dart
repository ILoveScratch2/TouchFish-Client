import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/services/auth_state.dart';

const MethodChannel _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};
  var failedProbeWrites = 1;

  setUp(() {
    store
      ..clear()
      ..['auth_token'] = 'secret-token'
      ..['auth_refresh_token'] = 'secret-refresh';
    failedProbeWrites = 1;
    SharedPreferences.setMockInitialValues({
      'auth_uid': 7,
      'auth_username': 'alice',
      'auth_token_expires_at': 1900000000,
      'auth_refresh_expires_at': 1900000000,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          // 启动时第一次探测写失败（Keychain 未解锁 / 插件还没就绪），之后恢复
          if (key == '__touchfish_secure_probe__' && failedProbeWrites > 0) {
            failedProbeWrites--;
            throw PlatformException(code: 'not_available');
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
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('init force-retries secure storage when the first probe fails', () async {
    // 凭据只在安全存储里：prefs 里只有 uid。
    await AuthState.instance.init();

    // 之前这里会静默变成未登录；现在启动时会强制重探一次并重读凭据。
    expect(AuthState.instance.token, 'secret-token');
    expect(AuthState.instance.refreshToken, 'secret-refresh');
    expect(AuthState.instance.isJwtMode, isTrue);
    expect(AuthState.instance.hasStoredCredentials, isTrue);
    expect(AuthState.instance.rememberedUid, 7);
  });
}
