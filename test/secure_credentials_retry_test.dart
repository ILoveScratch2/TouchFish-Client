import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/secure_credentials.dart';

const MethodChannel _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};
  var unavailable = true;
  final originalDelay = SecureCredentials.unavailableRetryDelay;

  setUp(() {
    store.clear();
    unavailable = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (unavailable) {
        throw MissingPluginException('secure storage not ready');
      }
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
        default:
          return null;
      }
    });
  });

  tearDown(() {
    SecureCredentials.unavailableRetryDelay = originalDelay;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('a transient probe failure is retried instead of cached forever',
      () async {
    final secure = SecureCredentials.instance;

    // 启动时 Keychain 还没解锁：探测失败
    expect(await secure.probe(), isFalse);

    // 冷却期内不重复探测
    unavailable = false;
    SecureCredentials.unavailableRetryDelay = const Duration(seconds: 30);
    expect(await secure.probe(), isFalse, reason: '冷却期内应使用缓存的 false');

    // 冷却期过后重试成功，凭据不能再落 SharedPreferences
    SecureCredentials.unavailableRetryDelay = Duration.zero;
    expect(await secure.probe(), isTrue);
    expect(await secure.write('auth_token', 'v1'), isTrue);
    expect(store['auth_token'], 'v1');
  });
}
