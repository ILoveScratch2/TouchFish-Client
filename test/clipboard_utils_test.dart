import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:touchfish_client/utils/clipboard_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = SystemChannels.platform;

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mockSetData(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'Clipboard.setData') {
        return handler(call);
      }
      return null;
    });
  }

  group('copyTextToClipboard', () {
    test('returns true and forwards the text on success', () async {
      String? copied;
      mockSetData((call) {
        copied = (call.arguments as Map)['text'] as String?;
        return null;
      });

      final ok = await copyTextToClipboard('hello');

      expect(ok, isTrue);
      expect(copied, 'hello');
    });

    test('returns false without throwing when the platform rejects', () async {
      // Simulates the Web non-secure-context failure (StateError from the
      // engine's clipboard strategy).
      mockSetData((_) => throw StateError('Clipboard is not available'));

      final ok = await copyTextToClipboard('hello');

      expect(ok, isFalse);
    });
  });

  group('readTextFromClipboard', () {
    test('returns the text on success', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': 'pasted'};
        }
        return null;
      });

      final text = await readTextFromClipboard();

      expect(text, 'pasted');
    });

    test('returns null without throwing when the platform rejects', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'Clipboard.getData') {
          throw StateError('Clipboard is not available');
        }
        return null;
      });

      final text = await readTextFromClipboard();

      expect(text, isNull);
    });
  });
}
