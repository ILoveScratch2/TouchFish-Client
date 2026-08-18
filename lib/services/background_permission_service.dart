import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/talker.dart';

/// Requests Android permissions that let the app keep running in the
/// background (battery-optimization exemption). On other platforms this
/// service is a no-op.
class BackgroundPermissionService {
  BackgroundPermissionService._();
  static final BackgroundPermissionService instance =
      BackgroundPermissionService._();

  bool _requested = false;

  /// Requests battery-optimization exemption on Android so the app is
  /// less likely to be killed while running in the background.
  Future<void> requestBackgroundPermissions() async {
    if (_requested || kIsWeb || !Platform.isAndroid) return;
    _requested = true;

    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) return;

      final result = await Permission.ignoreBatteryOptimizations.request();
      talker.info(
        'Android background (battery optimization) permission: $result',
      );
    } catch (error, stackTrace) {
      talker.error(
        'Failed to request Android background permission',
        error,
        stackTrace,
      );
    }
  }
}