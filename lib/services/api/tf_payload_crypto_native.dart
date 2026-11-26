import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'tf_crypto.dart';

final _waiting = Queue<Completer<void>>();
var _active = 0;

// Two workers leave the UI isolate responsive during bursts of large replies.
// A completing worker hands its slot to the oldest queued request.
Future<T> _runLarge<T>(T Function() operation) async {
  if (_active < 2) {
    _active++;
  } else {
    final turn = Completer<void>();
    _waiting.addLast(turn);
    await turn.future;
  }
  try {
    return await Isolate.run(operation);
  } finally {
    if (_waiting.isEmpty) {
      _active--;
    } else {
      _waiting.removeFirst().complete();
    }
  }
}

// Small messages cost less than starting an isolate. Keep larger blocks off
// the UI isolate so a single upload cannot occupy it across multiple frames.
Future<Uint8List> encrypt(String text, Uint8List key, Uint8List iv) async {
  if (text.length < 16384) return TfCrypto.aesEncrypt(text, key, iv);
  return _runLarge(() => TfCrypto.aesEncrypt(text, key, iv));
}

Future<String> decrypt(Uint8List bytes, Uint8List key, Uint8List iv) async {
  if (bytes.length < 16384) return TfCrypto.aesDecrypt(bytes, key, iv);
  return _runLarge(() => TfCrypto.aesDecrypt(bytes, key, iv));
}
