import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设备平台枚举
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

/// 原生平台实现：优先使用设备硬件标识
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
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        final rawId = info.id.isNotEmpty ? info.id : info.fingerprint;
        return DeviceIdentity(
          deviceId: _hash(rawId),
          deviceName: info.device.isNotEmpty ? info.device : info.model,
          platform: DevicePlatform.android,
        );
      }
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return DeviceIdentity(
          deviceId: _hash(info.identifierForVendor ?? info.utsname.machine),
          deviceName: info.name.isNotEmpty ? info.name : info.model,
          platform: DevicePlatform.ios,
        );
      }
      if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        return DeviceIdentity(
          deviceId: _hash(info.systemGUID ?? info.computerName),
          deviceName: info.computerName,
          platform: DevicePlatform.macos,
        );
      }
      if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        return DeviceIdentity(
          deviceId: _hash(info.deviceId),
          deviceName: info.computerName,
          platform: DevicePlatform.windows,
        );
      }
      if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        return DeviceIdentity(
          deviceId: _hash(info.machineId ?? info.id),
          deviceName: info.prettyName.isNotEmpty ? info.prettyName : info.name,
          platform: DevicePlatform.linux,
        );
      }
    } catch (_) {
      // 平台信息不可用时回退。
    }
    final raw = await _persistentRandomId();
    return DeviceIdentity(
      deviceId: _hash(raw),
      deviceName: Platform.localHostname,
      platform: DevicePlatform.unknown,
    );
  }

  String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

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
}
