import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/secure_credentials.dart';

const MethodChannel _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};

  setUp(() {
    store.clear();
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

  test('concurrent credential operations share one platform probe', () async {
    final secure = SecureCredentials.instance;
    secure.resetProbeState();
    final entered = Completer<void>();
    final resume = Completer<void>();
    var writes = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'write') {
        writes++;
        if (!entered.isCompleted) entered.complete();
        await resume.future;
      }
      return call.method == 'read' ? '1' : null;
    });
    final checks = List.generate(16, (_) => secure.probe());
    await entered.future;
    resume.complete();
    expect(await Future.wait(checks), everyElement(isTrue));
    expect(writes, 1);
  });

  test('SecureCredentials writes and reads through the platform store',
      () async {
    final secure = SecureCredentials.instance;
    expect(await secure.probe(), isTrue);

    expect(await secure.write('auth_token', 'token-value'), isTrue);
    expect(store['auth_token'], 'token-value');
    expect(await secure.read('auth_token'), 'token-value');

    final all = await secure.readAll(['auth_token', 'missing']);
    expect(all, {'auth_token': 'token-value'});

    await secure.delete('auth_token');
    expect(store.containsKey('auth_token'), isFalse);
  });
}
