import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/api/tf_crypto.dart';
import 'package:touchfish_client/services/rsa_key_trust_service.dart';

// AITester's PEM
const _testPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7n/+pzC9JOmR1AtTSdug
QeEQpAUzTmBeMufpLtLBoZ07mxHOTwcXDFwYgX8urwr3C6xQ772q+FJAAU30kmLL
JX/HpyM8CX2HolU4u5E7iztTYg7p0WNGYAXU1ZI6EGkjqlTRPppl2eNtssW4z18c
aOMgG7QGI3q1+NJxExizAMMeY7R9qko/ZeXG7/uSQDwGRkadeyB0YOZ/P8+b7kBL
kPphMOs7+1VuFFtXpcnKmA6SaiCmwaSLPn4wFGjq9DO43DDIcNUmdQoueRVVLeyT
QXrtiEB2jU44VFxfyerkbKhzRAE4772pVDcxP/K6+z8LwHp3Eo6u87w3qVeoP3lN
CQIDAQAB
-----END PUBLIC KEY-----
''';

/// 本地随便找的 res/1145/ 的 RSA 公钥，放心不是生产服务器我用真实密钥也0人会知道的。
const _serverPem = '-----BEGIN PUBLIC KEY-----\n'
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvdM0yGwJv7mt47NUM0oW\n'
    'zsn/5/kbwxWbKz//TGWVbhBLEOQ8nxNO8Sse8CSQsjQDWDGQy/UVEv4Q9cYfO0VS\n'
    'g1OC5O2a7lCB12PjM+a6CO6FDHVLdmORSAlA/B2svrLf14i+dPmrK2/s+XoYI+RY\n'
    'HVhcG75tM3lor+EQgzIjbXt0jXdU7vLd71e6DgMGf65ZDhavMiLAKXFrTZgLe+a5\n'
    'P2AitTxBXYLab+M0eTSfFqUcFCUobdBmYXNIuKSKIxtGTMzPInqV1VJKYDJ6PckW\n'
    'YgVXI2w8q8FF6MCNnaGmfqMpuOg0ZvZXHfn7JGSPpg/BpSsfby9D08LlpYGcxqU8\n'
    'IQIDAQAB\n'
    '-----END PUBLIC KEY-----\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TfCrypto', () {
    test('normalizePem produces 64-char wrapped canonical pem', () {
      final normalized = TfCrypto.normalizePem(_testPem);
      expect(normalized.startsWith('-----BEGIN PUBLIC KEY-----\n'), isTrue);
      // 末尾换行（与 cryptography 输出一致）。
      expect(normalized.endsWith('\n-----END PUBLIC KEY-----\n'), isTrue);
      expect(normalized, contains('MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA'));
      final lines = normalized
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();
      // 头 + 7 行 base64（6×64 + 8）+ 尾。
      expect(lines.length, 9);
      expect(lines[1], hasLength(64));
      expect(lines[2], hasLength(64));
      expect(lines[7], hasLength(8));
    });

    test('normalizePem is byte-identical to server pub.pem file', () {
      expect(TfCrypto.normalizePem(_serverPem), _serverPem);
    });

    test('fingerprint matches server sha256(pub_pem)', () {
      // 服务器 crypto.py: sha256(public_pem) 对同一文件的结果。
      expect(
        TfCrypto.rsaPublicKeyFingerprint(_serverPem),
        'a5140618181345397b91ef38835a41921544ba232dbbea7e6795badfdb132e68',
      );
      // 任意折行/无换行格式规范化后指纹一致。
      final singleLine = _serverPem
          .replaceAll('\n', '')
          .replaceAll('-----BEGIN PUBLIC KEY-----', '')
          .replaceAll('-----END PUBLIC KEY-----', '');
      expect(
        TfCrypto.rsaPublicKeyFingerprint(singleLine),
        'a5140618181345397b91ef38835a41921544ba232dbbea7e6795badfdb132e68',
      );
    });

    test('parseRsaPublicKey accepts normalized pem', () {
      final key = TfCrypto.parseRsaPublicKey(_testPem);
      expect(key.modulus, isNotNull);
      expect(key.exponent, isNotNull);
    });

    test('rsaPublicKeyFingerprint is a 64-char hex sha256', () {
      final sha = TfCrypto.rsaPublicKeyFingerprint(_testPem);
      expect(sha, hasLength(64));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(sha), isTrue);
      // 与规范化后的 PEM 指纹一致（指纹基于规范 PEM 文本字节）。
      expect(
        TfCrypto.rsaPublicKeyFingerprint(TfCrypto.normalizePem(_testPem)),
        sha,
      );
      // 不同密钥产生不同指纹。
      final other = _testPem.replaceRange(100, 101, 'A');
      expect(TfCrypto.rsaPublicKeyFingerprint(other), isNot(sha));
    });

    test('parseRsaPublicKey rejects garbage', () {
      expect(() => TfCrypto.parseRsaPublicKey('not a pem'), throwsA(anything));
    });
  });

  group('RsaKeyTrustService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SettingsService.instance.init();
    });

    test('saves and deletes keys per authority', () async {
      final service = RsaKeyTrustService.instance;
      await service.saveKey(_testPem, 'example.com:7001');
      final saved = await service.savedKeyFor('example.com:7001');
      expect(saved, isNotNull);
      expect(saved, TfCrypto.normalizePem(_testPem));
      expect(await service.hasSavedKey('example.com:7001'), isTrue);
      expect(await service.hasSavedKey('other.com:7001'), isFalse);

      await service.deleteKey('example.com:7001');
      expect(await service.savedKeyFor('example.com:7001'), isNull);
    });

    test('checkKey reports firstTime, matches, changed', () async {
      final service = RsaKeyTrustService.instance;
      const authority = 'example.com:7001';
      final live = TfCrypto.normalizePem(_testPem);

      final first = await service.checkKey(live, authority);
      expect(first.kind, RsaKeyCheckKind.firstTime);
      expect(first.dismissed, isFalse);
      expect(first.liveFingerprint, hasLength(64));

      await service.saveKey(_testPem, authority);
      final match = await service.checkKey(live, authority);
      expect(match.kind, RsaKeyCheckKind.matches);

      final other = _testPem.replaceRange(100, 101, 'B');
      final changed = await service.checkKey(other, authority);
      expect(changed.kind, RsaKeyCheckKind.changed);
      expect(changed.liveFingerprint, isNot(changed.savedFingerprint));
    });

    test('offline check with saved key reports matches', () async {
      final service = RsaKeyTrustService.instance;
      await service.saveKey(_testPem, 'offline.com:7001');
      final result = await service.checkKey(null, 'offline.com:7001');
      expect(result.kind, RsaKeyCheckKind.matches);
      expect(result.savedFingerprint, hasLength(64));
    });

    test('dismiss persists and marks firstTime', () async {
      final service = RsaKeyTrustService.instance;
      await service.dismissKey('dismissed.com:7001');
      final result = await service.checkKey(_testPem, 'dismissed.com:7001');
      expect(result.kind, RsaKeyCheckKind.firstTime);
      expect(result.dismissed, isTrue);
      // 保存密钥后清除 dismissed 标记。
      await service.saveKey(_testPem, 'dismissed.com:7001');
      final after = await service.checkKey(_testPem, 'dismissed.com:7001');
      expect(after.kind, RsaKeyCheckKind.matches);
      expect(after.dismissed, isFalse);
    });
  });
}
