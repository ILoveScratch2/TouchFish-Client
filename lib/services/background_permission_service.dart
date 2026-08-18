import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/talker.dart';

/// Manages Android permissions that let the app keep running in the
/// background (battery-optimization exemption) and the foreground
/// background notification service (开机自启、常驻)。
/// On other platforms this service is a no-op.
class BackgroundPermissionService {
  BackgroundPermissionService._();
  static final BackgroundPermissionService instance =
      BackgroundPermissionService._();

  static const MethodChannel _channel = MethodChannel(
    'touchfish/background_notification',
  );

  bool _requested = false;
  bool _serviceStarted = false;

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

  /// Starts the Android foreground background notification service.
  /// This lets the app receive and display chat notifications even when
  /// the main process is killed. Like WeChat.
  Future<void> startBackgroundService() async {
    if (kIsWeb || !Platform.isAndroid || _serviceStarted) return;
    _serviceStarted = true;
    try {
      await _channel.invokeMethod('startBackgroundService');
      talker.info('Android background notification service started.');
    } catch (error, stackTrace) {
      _serviceStarted = false;
      talker.error(
        'Failed to start Android background notification service',
        error,
        stackTrace,
      );
    }
  }

  /// Stops the Android background notification service.
  Future<void> stopBackgroundService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    _serviceStarted = false;
    try {
      await _channel.invokeMethod('stopBackgroundService');
      talker.info('Android background notification service stopped.');
    } catch (error, stackTrace) {
      talker.error(
        'Failed to stop Android background notification service',
        error,
        stackTrace,
      );
    }
  }
}