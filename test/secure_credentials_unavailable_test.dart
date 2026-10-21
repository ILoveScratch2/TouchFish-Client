import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/secure_credentials.dart';

const MethodChannel _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      throw MissingPluginException('secure storage unavailable');
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('SecureCredentials degrades safely when the plugin is unavailable',
      () async {
    final secure = SecureCredentials.instance;
    expect(await secure.probe(), isFalse);
    expect(await secure.read('auth_token'), isNull);
    expect(await secure.write('auth_token', 'value'), isFalse);
    // 删除不得抛异常：登出路径必须始终能走完
    await expectLater(secure.delete('auth_token'), completes);
  });
}
