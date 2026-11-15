import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/settings_service.dart';
import '../utils/talker.dart';


enum TfPermissionKind { notification, batteryOptimization, camera, microphone }

enum TfPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  notApplicable,
  unknown,
}

extension TfPermissionStatusX on TfPermissionStatus {
  bool get isGranted => this == TfPermissionStatus.granted;

  bool get needsSystemSettings => this == TfPermissionStatus.permanentlyDenied;
}

class PermissionCenter {
  PermissionCenter._();

  static final PermissionCenter instance = PermissionCenter._();

  static const String batteryPromptMutedKey = 'batteryOptimizationPromptMuted';

  static const String onboardingHandledKey = 'permissionOnboardingHandled';

  static const String notificationPromptedKey = 'notificationPermissionPrompted';

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get isSupported => isAndroid;

  bool get batteryPromptMuted =>
      SettingsService.instance.getValue<bool>(batteryPromptMutedKey, false);

  bool get onboardingHandled =>
      SettingsService.instance.getValue<bool>(onboardingHandledKey, false);

  Future<void> muteBatteryPrompt() =>
      SettingsService.instance.setValue(batteryPromptMutedKey, true);

  Future<void> markOnboardingHandled() =>
      SettingsService.instance.setValue(onboardingHandledKey, true);

  Permission? _permissionOf(TfPermissionKind kind) {
    if (!isMobile) return null;
    switch (kind) {
      case TfPermissionKind.notification:
        return Permission.notification;
      case TfPermissionKind.batteryOptimization:
        // 仅 Android 有电池优化
        return isAndroid ? Permission.ignoreBatteryOptimizations : null;
      case TfPermissionKind.camera:
        return Permission.camera;
      case TfPermissionKind.microphone:
        return Permission.microphone;
    }
  }

  Future<TfPermissionStatus> statusOf(TfPermissionKind kind) async {
    final permission = _permissionOf(kind);
    if (permission == null) return TfPermissionStatus.notApplicable;
    try {
      return _map(await permission.status);
    } catch (error, stackTrace) {
      talker.error('Failed to read permission status: $kind', error, stackTrace);
      return TfPermissionStatus.unknown;
    }
  }

  /// 触发系统授权流程
  Future<TfPermissionStatus> request(TfPermissionKind kind) async {
    final permission = _permissionOf(kind);
    if (permission == null) return TfPermissionStatus.notApplicable;
    try {
      final result = await permission.request();
      if (kind == TfPermissionKind.batteryOptimization) {
        final actual = await permission.status;
        return _map(actual.isGranted ? actual : result);
      }
      return _map(result);
    } catch (error, stackTrace) {
      talker.error('Failed to request permission: $kind', error, stackTrace);
      return TfPermissionStatus.unknown;
    }
  }

  Future<bool> openSystemSettings() async {
    try {
      return await openAppSettings();
    } catch (error, stackTrace) {
      talker.error('Failed to open app settings', error, stackTrace);
      return false;
    }
  }

  TfPermissionStatus _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return TfPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) return TfPermissionStatus.permanentlyDenied;
    if (status.isRestricted) return TfPermissionStatus.restricted;
    if (status.isDenied) return TfPermissionStatus.denied;
    return TfPermissionStatus.unknown;
  }
}
