import 'package:flutter/material.dart';
import '../models/settings_service.dart';

/// 窗口宽度分档。
///
/// - [compact]：窄屏，单栏布局。
/// - [medium]：中等宽度，可容纳「导航栏 + 列表」但两侧分栏偏挤。
/// - [expanded]：宽屏，可容纳完整的「导航栏 + 列表 + 详情」三栏。
enum WindowSizeClass { compact, medium, expanded }

/// 宽屏/窄屏布局判断的统一入口。
///
/// 用户可在设置中强制宽屏/窄屏，或调整自动切换的宽度阈值。
/// 全应用的断点判断都应使用本工具，避免各界面硬编码。
///
/// 分工（三档模型的接线方式）：
/// - 导航形态（底部导航 ↔ 侧栏导航）用 [isWide]：medium 档就已经放得下
///   「导航栏 + 列表」。
/// - 「列表 + 详情」两栏（聊天分栏、论坛分栏、论坛详情的双列）用
///   [isExpanded]：只有 expanded 档才并排，medium 档两侧太挤。
class WideScreenHelper {
  static const double defaultThreshold = 600;
  static const double minThreshold = 400;
  static const double maxThreshold = 1200;

  /// 从 [medium] 进入 [expanded] 的宽度阈值默认值（用户可在设置里改）。
  ///
  /// 与用户可调的 [threshold] 相互独立，且**两项都要跨过**才算 [expanded]：
  /// 先出现侧栏导航（medium），窗口再宽一些才并排「列表 + 详情」。
  static const double defaultSplitThreshold = 1000;

  static const String _modeKey = 'layoutMode';
  static const String _thresholdKey = 'wideScreenThreshold';
  static const String _splitThresholdKey = 'splitScreenThreshold';
  static const String _singlePageKey = 'singlePageStyle';
  static const String _forumHideEmptyKey = 'forumHideEmptyPane';
  static const String _auto = 'auto';
  static const String _forceWide = 'forceWide';
  static const String _forceNarrow = 'forceNarrow';

  static String get layoutMode =>
      SettingsService.instance.getValue<String>(_modeKey, _auto);

  /// 「单页风格」（默认关）：开启后论坛区不使用宽屏常驻分栏，
  /// 恢复整屏列表 → 整屏详情的 push 导航。
  static bool get singlePageStyle =>
      SettingsService.instance.getValue<bool>(_singlePageKey, false);

  /// 空置的展开栏是否隐藏（默认是）：论坛列表与论坛详情独占整屏，
  /// 只有打开帖子时才分屏；关闭后始终保留空栏占位。
  static bool get forumHideEmptyPane =>
      SettingsService.instance.getValue<bool>(_forumHideEmptyKey, true);

  static int get threshold => (SettingsService.instance
          .getValue<int>(_thresholdKey, defaultThreshold.round())
          .toDouble()
          .clamp(minThreshold, maxThreshold))
      .round();

  /// 「列表 + 详情」并排所需的最小窗口宽度（默认 [defaultSplitThreshold]）。
  static int get splitThreshold => (SettingsService.instance
          .getValue<int>(_splitThresholdKey, defaultSplitThreshold.round())
          .toDouble()
          .clamp(minThreshold, maxThreshold))
      .round();

  /// 依据宽度与用户设置解析分档。
  static WindowSizeClass sizeClassWithWidth(double width) {
    switch (layoutMode) {
      case _forceWide:
        return WindowSizeClass.expanded;
      case _forceNarrow:
        return WindowSizeClass.compact;
      default:
        // expanded 必须同时跨过导航阈值与分栏阈值，否则用户把导航阈值调高
        // 时会出现「导航栏还没变宽却先并排两栏」。
        if (width >= splitThreshold && width >= threshold) {
          return WindowSizeClass.expanded;
        }
        if (width >= threshold) return WindowSizeClass.medium;
        return WindowSizeClass.compact;
    }
  }

  static WindowSizeClass sizeClassOf(BuildContext context) =>
      sizeClassWithWidth(MediaQuery.sizeOf(context).width);

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

  /// 是否足够宽以容纳「列表 + 详情」两栏（即 [expanded] 档）。
  static bool isExpandedWithWidth(double width) =>
      sizeClassWithWidth(width) == WindowSizeClass.expanded;

  static bool isExpanded(BuildContext context) =>
      sizeClassOf(context) == WindowSizeClass.expanded;

  /// 论坛区是否使用宽屏分栏（左常驻列表 / 右详情）。非 [expanded] 档（即
  /// 窄屏或 medium）或「单页风格」开关打开时为假——此时论坛区整屏 push，
  /// 不含常驻左栏。
  static bool forumTwoPane(BuildContext context) =>
      !singlePageStyle && isExpanded(context);

  /// 论坛索引页（`/forum`）是否保留「选择论坛」占位——即左栏是否常驻论坛
  /// 列表。空置展开栏被隐藏时索引页整屏显示论坛列表，无需占位。
  static bool forumKeepsListPane(BuildContext context) =>
      forumTwoPane(context) && !forumHideEmptyPane;
}
