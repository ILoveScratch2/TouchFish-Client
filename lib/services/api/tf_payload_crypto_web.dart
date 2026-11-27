import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'tf_crypto.dart';

extension type _CbcParams._(JSObject _) implements JSObject {
  external factory _CbcParams({
    required JSString name,
    required JSUint8Array iv,
  });
}

Future<Uint8List> _crypt(
  Uint8List data,
  Uint8List key,
  Uint8List iv,
  bool encrypting,
) async {
  final api = web.window.crypto.subtle;
  final usage = encrypting ? 'encrypt' : 'decrypt';
  final algorithm = 'AES-CBC'.toJS;
  final imported = await api
      .importKey('raw', key.toJS, algorithm, false, [usage.toJS].toJS)
      .toDart;
  final params = _CbcParams(name: algorithm, iv: iv.toJS);
  final result =
      await (encrypting
              ? api.encrypt(params, imported, data.toJS)
              : api.decrypt(params, imported, data.toJS))
          .toDart;
  return (result as JSArrayBuffer).toDart.asUint8List();
}

Future<Uint8List> encrypt(String text, Uint8List key, Uint8List iv) async {
  if (text.length < 16384 || !web.window.isSecureContext) {
    return TfCrypto.aesEncrypt(text, key, iv);
  }
  return _crypt(utf8.encode(text), key, iv, true);
}

Future<String> decrypt(Uint8List bytes, Uint8List key, Uint8List iv) async {
  if (bytes.length < 16384 || !web.window.isSecureContext) {
    return TfCrypto.aesDecrypt(bytes, key, iv);
  }
  return utf8.decode(await _crypt(bytes, key, iv, false));
}
