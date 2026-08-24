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

  bool _applied = false;

  Future<void> applyFromSettings() async {
    if (_applied || kIsWeb || !Platform.isAndroid) return;
    _applied = true;
    final enabled = SettingsService.instance.getValue<bool>(
      _settingKey,
      false,
    );
    if (!enabled) return;
    await setEnabled(true);
  }

  Future<void> setEnabled(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('setShowWhenLocked', {
        'enabled': enabled,
      });
    } catch (error, stackTrace) {
      talker.error(
        'Failed to apply show-on-lock-screen setting',
        error,
        stackTrace,
      );
    }
  }
}
