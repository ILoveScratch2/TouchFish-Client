import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/talker.dart';
import 'web_secure_context_stub.dart'
    if (dart.library.js_interop) 'web_secure_context_web.dart';

/// 加密存储的可用状态
enum SecureStorageStatus {
  /// 尚未探测
  unknown,

  /// 加密存储可用
  secure,

  /// 没有可用的加密存储
  unavailable,

  /// Web 端非安全上下文
  insecureWebContext,
}

/// 敏感凭据（登录密码 / JWT / refresh token）的加密存储。
///
/// 各平台后端：
/// - Android：Keystore v10 起 RSA-OAEP 安全存储 AES-GCM 密钥
/// - iOS / macOS：Keychain 需要 entitlements keychain-access-groups
/// - Windows：Credential Manager
/// - Linux：libsecret
/// - Web：WebCrypto 使用安全上下文
///
/// 平台不支持时 [isAvailable] 为 false
class SecureCredentials extends ChangeNotifier {
  SecureCredentials._();

  static final SecureCredentials instance = SecureCredentials._();

  static const String _probeKey = '__touchfish_secure_probe__';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // 密钥解包失败时会自动清空全部数据再重试
      // 关闭该功能
      resetOnError: false,
      // v9 使用 EncryptedSharedPreferences
      // v10 使用自定义密码
      migrateOnAlgorithmChange: true,
    ),
  );

  /// 探测失败后多久允许重试
  @visibleForTesting
  static Duration unavailableRetryDelay = const Duration(seconds: 30);

  /// 平台判定与安全上下文判定
  @visibleForTesting
  static bool Function() isWebPlatform = () => kIsWeb;

  @visibleForTesting
  static bool Function() webIsSecureContext = () => isSecureWebContext;

  bool? _available;
  DateTime? _unavailableAt;
  SecureStorageStatus _status = SecureStorageStatus.unknown;

  bool get isAvailable => _available == true;

  /// 当前状态
  SecureStorageStatus get status => _status;

  /// Web 端无法使用加密存储
  bool get isInsecureWebContext =>
      _status == SecureStorageStatus.insecureWebContext;

  /// 探测当前平台是否真的可用
  ///
  /// [force] 跳过失败冷却
  Future<bool> probe({bool force = false}) async {
    if (_available == true) return true;

    // 非安全上下文的判定在冷却前
    if (_isInsecureWebContext()) {
      final changed = _status != SecureStorageStatus.insecureWebContext;
      _available = false;
      _unavailableAt = DateTime.now();
      _setStatus(SecureStorageStatus.insecureWebContext);
      if (changed) {
        talker.warning(
          'TOUCHFISH SecureCredentials: ilovescratch 温馨提醒：currently WebCrypto is not available!'
          'will use unencrypted local storage',
        );
      }
      return false;
    }

    final unavailableAt = _unavailableAt;
    if (!force &&
        _available == false &&
        unavailableAt != null &&
        DateTime.now().difference(unavailableAt) < unavailableRetryDelay) {
      return false;
    }
    try {
      await _storage.write(key: _probeKey, value: '1');
      final value = await _storage.read(key: _probeKey);
      await _storage.delete(key: _probeKey);
      final ok = value == '1';
      _available = ok;
      _unavailableAt = ok ? null : DateTime.now();
      _setStatus(
        ok ? SecureStorageStatus.secure : SecureStorageStatus.unavailable,
      );
      if (!ok) {
        talker.warning('SecureCredentials: probe returned unexpected value');
      }
    } catch (e) {
      _available = false;
      _unavailableAt = DateTime.now();
      _setStatus(SecureStorageStatus.unavailable);
      talker.warning('SecureCredentials unavailable, falling back: $e');
    }
    return _available!;
  }

  bool _isInsecureWebContext() =>
      isWebPlatform() && !webIsSecureContext();

  void _setStatus(SecureStorageStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  /// 仅测试用：清空探测缓存
  @visibleForTesting
  void resetProbeState() {
    _available = null;
    _unavailableAt = null;
    _status = SecureStorageStatus.unknown;
  }

  Future<String?> read(String key) async {
    if (!await probe()) return null;
    try {
      return await _storage.read(key: key);
    } catch (e) {
      talker.warning('SecureCredentials read $key failed: $e');
      return null;
    }
  }

  Future<Map<String, String>> readAll(Iterable<String> keys) async {
    final result = <String, String>{};
    if (!await probe()) return result;
    for (final key in keys) {
      final value = await read(key);
      if (value != null) result[key] = value;
    }
    return result;
  }

  Future<bool> write(String key, String value) async {
    if (!await probe()) return false;
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      talker.warning('SecureCredentials write $key failed: $e');
      return false;
    }
  }

  Future<void> delete(String key) async {
    if (!await probe()) return;
    try {
      await _storage.delete(key: key);
    } catch (e) {
      talker.warning('SecureCredentials delete $key failed: $e');
    }
  }
}
