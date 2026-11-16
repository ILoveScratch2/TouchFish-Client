import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../models/settings_service.dart';
import '../routes/app_routes.dart';
import '../utils/talker.dart';

/// 自动检查更新的偏好。
///
/// 与权限中心的做法保持一致：开关落在 [SettingsService]（SharedPreferences），
/// 默认开启，因此老用户升级后行为不变；关闭后启动时不再访问版本接口，
/// 但仍可从「设置 - 关于」手动检查。
class UpdatePreferences {
  UpdatePreferences._();

  static const String autoCheckKey = 'appUpdateAutoCheckEnabled';
  static const String setupHandledKey = 'appUpdateSetupHandled';

  /// 默认开启：无人为干预时按原行为在启动时检查一次。
  static bool get autoCheckEnabled =>
      SettingsService.instance.getValue<bool>(autoCheckKey, true);

  static Future<void> setAutoCheckEnabled(bool value) =>
      SettingsService.instance.setValue(autoCheckKey, value);

  /// 首次引导是否已完成（用户点过继续或跳过）。
  static bool get setupHandled =>
      SettingsService.instance.getValue<bool>(setupHandledKey, false);

  static Future<void> markSetupHandled() =>
      SettingsService.instance.setValue(setupHandledKey, true);

  /// 启动时是否真的要联网检查：网页端没有更新渠道，直接跳过。
  static bool get shouldAutoCheck => !kIsWeb && autoCheckEnabled;
}

/// 首次展示更新偏好的引导页；已展示过则什么都不做。
///
/// 返回是否真的跳转了，便于调用方决定后续导航。
Future<bool> maybeShowUpdatePreferencePrompt(BuildContext context) async {
  if (UpdatePreferences.setupHandled) return false;
  if (!context.mounted) return false;
  talker.info('Showing update preference setup.');
  context.push(AppRoutes.updateSetup);
  return true;
}
