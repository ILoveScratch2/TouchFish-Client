import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/secure_credentials.dart';

const MethodChannel _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};
  var unavailable = true;

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
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('force bypasses the failure cooldown', () async {
    final secure = SecureCredentials.instance;

    expect(await secure.probe(), isFalse);

    // 冷却期内普通 probe 直接吃缓存
    unavailable = false;
    expect(await secure.probe(), isFalse);

    // 启动补偿路径用 force 立刻再试一次，不等冷却
    expect(await secure.probe(force: true), isTrue);
    expect(await secure.write('auth_token', 'v1'), isTrue);
    expect(store['auth_token'], 'v1');
  });
}
