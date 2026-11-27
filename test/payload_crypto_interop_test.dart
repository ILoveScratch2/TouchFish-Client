import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/api/tf_crypto.dart';
import 'package:touchfish_client/services/api/tf_payload_crypto.dart'
    as payload;

void main() {
  test(
    'small and large HTTP envelopes match the existing CBC wire format',
    () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final iv = Uint8List.fromList(List.generate(16, (i) => 255 - i));
      for (final count in [0, 1, 16, 16383, 16384, 65536]) {
        final text = '文🌱a' * count;
        final reference = TfCrypto.aesEncrypt(text, key, iv);
        expect(await payload.encrypt(text, key, iv), orderedEquals(reference));
        expect(await payload.decrypt(reference, key, iv), text);
      }
    },
  );
}
