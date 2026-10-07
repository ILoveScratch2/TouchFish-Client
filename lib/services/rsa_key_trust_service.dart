import 'package:flutter/foundation.dart';

import '../models/settings_service.dart';
import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'api/tf_crypto.dart';

/// TOFU = Trust On First Use（首次使用即信任），是 SSH、Signal 等软件常用的一种信任模型。
/// 这就是 wyf 的天才设计！
class RsaKeyTrustService extends ChangeNotifier {
  RsaKeyTrustService._();

  static final RsaKeyTrustService instance = RsaKeyTrustService._();

  static const String kSavedKeysKey = 'savedRsaKeysV1';
  static const String kDismissedKeysKey = 'dismissedRsaKeysV1';

  Map<String, String> _savedKeys = {};
  Set<String> _dismissed = {};
  bool _loaded = false;

  Map<String, String> _loadSavedKeys() {
    final json = SettingsService.instance.getJsonValue(kSavedKeysKey);
    if (json == null) return {};
    return json.map(
      (key, value) => MapEntry(key, value.toString()),
    );
  }

  Set<String> _loadDismissed() {
    final raw = SettingsService.instance.getValue<String>(
      kDismissedKeysKey,
      '',
    );
    if (raw.trim().isEmpty) return {};
    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Future<void> _persistSavedKeys() async {
    await SettingsService.instance.setJsonValue(
      kSavedKeysKey,
      _savedKeys.map((key, value) => MapEntry(key, value)),
    );
  }

  Future<void> _persistDismissed() async {
    await SettingsService.instance.setValue(
      kDismissedKeysKey,
      _dismissed.join('\n'),
    );
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await SettingsService.instance.init();
    _savedKeys = _loadSavedKeys();
    _dismissed = _loadDismissed();
    _loaded = true;
  }

  static Future<String> currentAuthority() async {
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    return authorityOfBaseUrl(baseUrl);
  }

  static String authorityOfBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri != null && uri.hasAuthority) return uri.authority;
    return baseUrl;
  }

  Future<Map<String, String>> savedKeys() async {
    await _ensureLoaded();
    return Map.unmodifiable(_savedKeys);
  }

  Future<bool> hasSavedKey([String? authority]) async {
    await _ensureLoaded();
    final key = authority ?? await currentAuthority();
    return _savedKeys.containsKey(key);
  }

  Future<String?> savedKeyFor([String? authority]) async {
    await _ensureLoaded();
    final key = authority ?? await currentAuthority();
    return _savedKeys[key];
  }

  Future<String?> dismissedKeyFor([String? authority]) async {
    await _ensureLoaded();
    final key = authority ?? await currentAuthority();
    return _dismissed.contains(key) ? key : null;
  }

  Future<void> saveKey(String pem, [String? authority]) async {
    await _ensureLoaded();
    final key = authority ?? await currentAuthority();
    final normalized = TfCrypto.normalizePem(pem);
    if (normalized.isEmpty) return;
    _savedKeys[key] = normalized;
    _dismissed.remove(key);
    await _persistSavedKeys();
    await _persistDismissed();
    notifyListeners();
  }

  Future<void> deleteKey([String? authority]) async {
    await _ensureLoaded();
    final key = authority ?? await currentAuthority();
    if (_savedKeys.remove(key) != null) {
      await _persistSavedKeys();
      notifyListeners();
    }
  }

  Future<void> dismissKey([String? authority]) async {
    await _ensureLoaded();
    final key = authority ?? await currentAuthority();
    if (_dismissed.add(key)) {
      await _persistDismissed();
      notifyListeners();
    }
  }

  Future<RsaKeyCheckResult> checkKey(String? livePem, [String? authority]) async {
    final key = authority ?? await currentAuthority();
    final saved = await savedKeyFor(key);
    final dismissed = await dismissedKeyFor(key);
    if (saved == null) {
      return RsaKeyCheckResult.firstTime(
        livePem: livePem,
        dismissed: dismissed != null,
      );
    }
    if (livePem == null) {
      return RsaKeyCheckResult.matches(pem: saved);
    }
    final savedNormalized = TfCrypto.normalizePem(saved);
    final liveNormalized = TfCrypto.normalizePem(livePem);
    if (savedNormalized == liveNormalized) {
      return RsaKeyCheckResult.matches(pem: saved);
    }
    return RsaKeyCheckResult.changed(
      oldPem: saved,
      newPem: livePem,
    );
  }
}

enum RsaKeyCheckKind { firstTime, matches, changed, offline }

/// RSA 密钥校验结果。
class RsaKeyCheckResult {
  final RsaKeyCheckKind kind;

  /// 实时（服务器）PEM；离线时为 null。
  final String? livePem;

  /// 已保存的 PEM（存在时）。
  final String? savedPem;

  /// 用户此前选择过“不保存”且当前仍未保存。
  final bool dismissed;

  const RsaKeyCheckResult._({
    required this.kind,
    this.livePem,
    this.savedPem,
    this.dismissed = false,
  });

  factory RsaKeyCheckResult.firstTime({
    required String? livePem,
    required bool dismissed,
  }) => RsaKeyCheckResult._(
    kind: RsaKeyCheckKind.firstTime,
    livePem: livePem,
    dismissed: dismissed,
  );

  factory RsaKeyCheckResult.matches({required String pem}) =>
      RsaKeyCheckResult._(kind: RsaKeyCheckKind.matches, savedPem: pem);

  factory RsaKeyCheckResult.changed({
    required String oldPem,
    required String newPem,
  }) => RsaKeyCheckResult._(
    kind: RsaKeyCheckKind.changed,
    livePem: newPem,
    savedPem: oldPem,
  );

  String? get liveFingerprint =>
      livePem == null ? null : TfCrypto.rsaPublicKeyFingerprint(livePem!);

  String? get savedFingerprint =>
      savedPem == null ? null : TfCrypto.rsaPublicKeyFingerprint(savedPem!);

  void log() {
    talker.info(
      'RsaKeyTrustService check: ${kind.name} '
      '(live=$liveFingerprint, saved=$savedFingerprint)',
    );
  }
}
