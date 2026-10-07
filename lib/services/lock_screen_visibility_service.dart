import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/settings_service.dart';
import '../utils/talker.dart';

/// 虽然 useless 但是还是加一个比较好玩！
class LockScreenVisibilityService {
  LockScreenVisibilityService._();
  static final LockScreenVisibilityService instance =
      LockScreenVisibilityService._();

  static const MethodChannel _channel = MethodChannel('touchfish/lock_screen');

  static const String _settingKey = 'showOnLockScreen';

  // lock your mother lock
  Future<void> applyFromSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final enabled = SettingsService.instance.getValue<bool>(_settingKey, false);
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await setEnabled(enabled)) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  /// 设置锁屏上层显示状态；成功返回 true。
  Future<bool> setEnabled(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      await _channel.invokeMethod<bool>('setShowWhenLocked', {
        'enabled': enabled,
      });
      return true;
    } catch (error, stackTrace) {
      talker.error(
        'Failed to apply show-on-lock-screen setting',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<bool?> isKeyguardLocked() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<bool>('isKeyguardLocked');
    } catch (error, stackTrace) {
      talker.error('Failed to read keyguard state', error, stackTrace);
      return null;
    }
  }
}
