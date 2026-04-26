import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';

/// RSA+AES crypt
class TfCrypto {
  static Uint8List generateAesKey() {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rand.nextInt(256)));
  }

  static Uint8List generateIv() {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => rand.nextInt(256)));
  }

  static RSAPublicKey parseRsaPublicKey(String pem) {
    final base64Str = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
    final bytes = Uint8List.fromList(base64.decode(base64Str));

    final asn1Parser = ASN1Parser(bytes);
    final spki = asn1Parser.nextObject() as ASN1Sequence;

    final bitString = spki.elements![1] as ASN1BitString;
    // valueBytes includes unused-bits prefix byte; skip it to get the inner DER
    final bitStringContent = Uint8List.fromList(
        (bitString.valueBytes ?? bitString.encodedBytes!).skip(bitString.valueBytes != null ? 1 : 4).toList());
    final innerParser = ASN1Parser(bitStringContent);
    final rsaSeq = innerParser.nextObject() as ASN1Sequence;

    final modulus = (rsaSeq.elements![0] as ASN1Integer).integer!;
    final exponent = (rsaSeq.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(modulus, exponent);
  }

  /// RSA+AES crypt
  static Uint8List rsaEncrypt(Uint8List data, RSAPublicKey publicKey) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine());
    cipher.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return cipher.process(data);
  }

  static Uint8List aesEncrypt(String plaintext, Uint8List key, Uint8List iv) {
    final data = Uint8List.fromList(utf8.encode(plaintext));
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    cipher.init(
      true,
      PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv), null),
    );
    return cipher.process(data);
  }

  static String aesDecrypt(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    cipher.init(
      false,
      PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv), null),
    );
    final plain = cipher.process(ciphertext);
    return utf8.decode(plain);
  }
}
