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

  /// 去除 PEM 头尾标记与空白
  /// 因为服务器就是这样算的，@wyf
  static String normalizePem(String pem) {
    final body = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '')
        .trim();
    if (body.isEmpty) return '';
    final buffer = StringBuffer('-----BEGIN PUBLIC KEY-----\n');
    for (var i = 0; i < body.length; i += 64) {
      final end = min(i + 64, body.length);
      buffer.writeln(body.substring(i, end));
    }
    buffer.write('-----END PUBLIC KEY-----\n');
    return buffer.toString();
  }

  /// PEM 内容（不含头尾标记）的原始 DER 字节。
  static Uint8List _pemBodyBytes(String pem) {
    final base64Str = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '')
        .trim();
    return Uint8List.fromList(base64.decode(base64Str));
  }

  /// 计算 RSA 公钥指纹：对规范 PEM 文本（UTF-8 字节）求 SHA-256，
  /// 返回小写 hex
  static String rsaPublicKeyFingerprint(String pem) {
    final normalized = normalizePem(pem);
    final digest = SHA256Digest();
    final bytes = Uint8List.fromList(utf8.encode(normalized));
    final hash = Uint8List(digest.digestSize);
    digest.update(bytes, 0, bytes.length);
    digest.doFinal(hash, 0);
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static RSAPublicKey parseRsaPublicKey(String pem) {
    final bytes = _pemBodyBytes(pem);

    final asn1Parser = ASN1Parser(bytes);
    final spki = asn1Parser.nextObject() as ASN1Sequence;

    final bitString = spki.elements![1] as ASN1BitString;
    // valueBytes includes unused-bits prefix byte; skip it to get the inner DER
    final bitStringContent = Uint8List.fromList(
      (bitString.valueBytes ?? bitString.encodedBytes!)
          .skip(bitString.valueBytes != null ? 1 : 4)
          .toList(),
    );
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
        ParametersWithIV(KeyParameter(key), iv),
        null,
      ),
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
        ParametersWithIV(KeyParameter(key), iv),
        null,
      ),
    );
    final plain = cipher.process(ciphertext);
    return utf8.decode(plain);
  }
}
