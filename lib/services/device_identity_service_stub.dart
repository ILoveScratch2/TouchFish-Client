import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设备平台
/// 0 unknown, 1 windows, 2 macos, 3 linux, 4 android, 5 ios, 6 web
class DevicePlatform {
  static const int unknown = 0;
  static const int windows = 1;
  static const int macos = 2;
  static const int linux = 3;
  static const int android = 4;
  static const int ios = 5;
  static const int web = 6;
}

class DeviceIdentity {
  final String deviceId;
  final String deviceName;
  final int platform;

  const DeviceIdentity({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });
}

const String _kInstallIdKey = 'device_install_id';

/// 回退实现：无法获取硬件标识时，使用持久化的随机安装 ID
class DeviceIdentityService {
  DeviceIdentityService._();

  static final DeviceIdentityService instance = DeviceIdentityService._();

  DeviceIdentity? _cached;

  Future<DeviceIdentity> get() async {
    final cached = _cached;
    if (cached != null) return cached;
    final identity = await _resolve();
    _cached = identity;
    return identity;
  }

  /// 允许测试注入。
  void setCachedForTest(DeviceIdentity? identity) => _cached = identity;

  Future<DeviceIdentity> _resolve() async {
    final rawId = await _persistentRandomId();
    return DeviceIdentity(
      deviceId: _hash(rawId),
      deviceName: 'Unknown device',
      platform: DevicePlatform.unknown,
    );
  }

  Future<String> _persistentRandomId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_kInstallIdKey);
      if (existing != null && existing.isNotEmpty) return existing;
      final generated = _randomId();
      await prefs.setString(_kInstallIdKey, generated);
      return generated;
    } catch (_) {
      return _randomId();
    }
  }

  static String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
