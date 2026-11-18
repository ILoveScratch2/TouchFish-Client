import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../models/settings_service.dart';
import '../routes/app_routes.dart';
import '../utils/talker.dart';

/// 自动检查更新偏好
class UpdatePreferences {
  UpdatePreferences._();

  static const String autoCheckKey = 'appUpdateAutoCheckEnabled';
  static const String setupHandledKey = 'appUpdateSetupHandled';

  static bool get autoCheckEnabled =>
      SettingsService.instance.getValue<bool>(autoCheckKey, true);

  static Future<void> setAutoCheckEnabled(bool value) =>
      SettingsService.instance.setValue(autoCheckKey, value);

  /// 首次引导是否已完成
  static bool get setupHandled =>
      SettingsService.instance.getValue<bool>(setupHandledKey, false);

  static Future<void> markSetupHandled() =>
      SettingsService.instance.setValue(setupHandledKey, true);

  /// Web 端没有更新
  static bool get isSupported => !kIsWeb;

  static bool get shouldAutoCheck => !kIsWeb && autoCheckEnabled;

  static bool get shouldOfferSetup => !kIsWeb && !setupHandled;
}

/// 首次展示更新偏好的引导页
Future<bool> maybeShowUpdatePreferencePrompt(BuildContext context) async {
  if (!UpdatePreferences.shouldOfferSetup) return false;
  if (!context.mounted) return false;
  talker.info('Showing update preference setup.');
  context.push(AppRoutes.updateSetup);
  return true;
}
