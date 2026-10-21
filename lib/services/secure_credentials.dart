import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/talker.dart';

/// 敏感凭据（登录密码 / JWT / refresh token）的加密存储。
///
/// - Android: Keystore（EncryptedSharedPreferences）
/// - iOS / macOS: Keychain
/// - Windows: Credential Manager；Linux: libsecret
/// - Web: WebCrypto（需要 HTTPS 或 localhost 这类安全上下文）
///
/// 平台不支持时 [isAvailable] 为 false，调用方需要自行决定降级策略
/// （[AuthState] 的降级是：token / refresh token / 密码都退回 SharedPreferences，
///  也就是和接入本类之前一样明文落盘——legacy 模式重新登录需要密码，
///  不能为了“看起来安全”直接把登录态丢掉）。
class SecureCredentials {
  SecureCredentials._();

  static final SecureCredentials instance = SecureCredentials._();

  static const String _probeKey = '__touchfish_secure_probe__';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// 探测失败后多久允许重试。
  ///
  /// 不能把 `false` 永久缓存：Keychain / libsecret 可能只是启动时还没解锁，
  /// 冻结失败会让本次进程余下的所有凭据都退回 SharedPreferences 明文。
  @visibleForTesting
  static Duration unavailableRetryDelay = const Duration(seconds: 30);

  bool? _available;
  DateTime? _unavailableAt;

  bool get isAvailable => _available == true;

  /// 探测当前平台是否真的可用（插件缺失、缺少密钥环、非安全上下文都会失败）。
  /// 成功的结果会缓存；失败只缓存 [unavailableRetryDelay] 这么久。
  ///
  /// [force] 会跳过失败冷却（用于启动时凭据读不到的唯一一次补救探测）。
  Future<bool> probe({bool force = false}) async {
    if (_available == true) return true;
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
      if (!ok) {
        talker.warning('SecureCredentials: probe returned unexpected value');
      }
    } catch (e) {
      _available = false;
      _unavailableAt = DateTime.now();
      talker.warning('SecureCredentials unavailable, falling back: $e');
    }
    return _available!;
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
