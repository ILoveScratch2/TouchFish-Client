import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/secure_credentials.dart';

const MethodChannel _channel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var platformCalls = 0;

  setUp(() {
    platformCalls = 0;
    SecureCredentials.instance.resetProbeState();
    // 模拟浏览器
    SecureCredentials.isWebPlatform = () => true;
    SecureCredentials.webIsSecureContext = () => false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      platformCalls++;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    SecureCredentials.isWebPlatform = () => kIsWeb;
    SecureCredentials.webIsSecureContext = () => true;
  });

  test('unsafe web context can be detected by ils', () async {
    var notified = 0;
    void listener() => notified++;
    SecureCredentials.instance.addListener(listener);
    addTearDown(() => SecureCredentials.instance.removeListener(listener));

    expect(await SecureCredentials.instance.probe(force: true), isFalse);
    expect(
      SecureCredentials.instance.status,
      SecureStorageStatus.insecureWebContext,
    );
    expect(SecureCredentials.instance.isInsecureWebContext, isTrue);
    expect(SecureCredentials.instance.isAvailable, isFalse);
    // 判定发生在调用插件之前
    // 不会产生异常
    expect(platformCalls, 0);
    expect(notified, 1);

    // 状态未变化时不应重复通知
    await SecureCredentials.instance.probe(force: true);
    expect(notified, 1);
  });

  test('use local storage in insecure web context', () async {
    expect(await SecureCredentials.instance.write('auth_token', 'v1'), isFalse);
    expect(await SecureCredentials.instance.read('auth_token'), isNull);
    expect(await SecureCredentials.instance.readAll(['auth_token']), isEmpty);
    await SecureCredentials.instance.delete('auth_token');
    expect(platformCalls, 0);
  });

  test('secure web context uses platform', () async {
    SecureCredentials.webIsSecureContext = () => true;
    final store = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      platformCalls++;
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

    expect(await SecureCredentials.instance.probe(force: true), isTrue);
    expect(SecureCredentials.instance.status, SecureStorageStatus.secure);
    expect(await SecureCredentials.instance.write('auth_token', 'v1'), isTrue);
    expect(store['auth_token'], 'v1');
    expect(platformCalls, greaterThan(0));
  });
}
