import 'package:flutter/material.dart';
import '../models/settings_service.dart';

/// 宽屏/窄屏布局判断的统一入口。
///
/// 用户可在设置中强制宽屏/窄屏，或调整自动切换的宽度阈值。
/// 全应用的断点判断都应使用本工具，避免各界面硬编码。
class WideScreenHelper {
  static const double defaultThreshold = 600;
  static const double minThreshold = 400;
  static const double maxThreshold = 1200;

  static const String _modeKey = 'layoutMode';
  static const String _thresholdKey = 'wideScreenThreshold';
  static const String _auto = 'auto';
  static const String _forceWide = 'forceWide';
  static const String _forceNarrow = 'forceNarrow';

  static String get layoutMode =>
      SettingsService.instance.getValue<String>(_modeKey, _auto);

  static int get threshold => (SettingsService.instance
          .getValue<int>(_thresholdKey, defaultThreshold.round())
          .toDouble()
          .clamp(minThreshold, maxThreshold))
      .round();

  static bool isWideWithWidth(double width) {
    switch (layoutMode) {
      case _forceWide:
        return true;
      case _forceNarrow:
        return false;
      default:
        return width >= threshold;
    }
  }

  static bool isWide(BuildContext context) =>
      isWideWithWidth(MediaQuery.sizeOf(context).width);
}
