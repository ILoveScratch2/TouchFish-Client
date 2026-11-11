/// TouchFish 设计令牌（Design Tokens）
library;

import 'package:flutter/widgets.dart';

/// 间距阶梯
/// 避免 `spacing8` 这类与数值耦合的名字
abstract final class TFSpace {
  const TFSpace._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  /// 页面左右安全内边距（手机）
  static const double page = xl;

  /// 页面左右安全内边距（宽屏）
  static const double pageWide = xxxl;

  /// 区块之间的垂直间隔
  static const double section = xxl;

  /// 卡片内边距。与 [page] 同为 20
  static const double card = xl;

  /// 控件最小可点击高度（Material 无障碍下限 48）
  static const double touchTarget = 48;

  /// 列表项最小高度（紧凑型）
  static const double listItem = 56;
}

/// 圆角阶梯。语义化别名优先于数值别名。
abstract final class TFRadius {
  const TFRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double pill = 999;

  /// 语义别名
  static const double chip = sm;
  static const double control = lg;
  static const double card = lg;
  static const double input = lg;
  static const double menu = lg;
  static const double dialog = xxl;
  static const double sheet = xxl;

  static const BorderRadius xsRadius = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius inputRadius = BorderRadius.all(
    Radius.circular(input),
  );
  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius menuRadius = BorderRadius.all(
    Radius.circular(menu),
  );
  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(dialog),
  );
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}

/// 常用内边距。
abstract final class TFInsets {
  const TFInsets._();

  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: TFSpace.page);
  static const EdgeInsets pageWide = EdgeInsets.symmetric(
    horizontal: TFSpace.pageWide,
  );
  static const EdgeInsets card = EdgeInsets.all(TFSpace.card);
  static const EdgeInsets control = EdgeInsets.symmetric(
    horizontal: TFSpace.xl,
    vertical: TFSpace.md,
  );
  static const EdgeInsets input = EdgeInsets.symmetric(
    horizontal: TFSpace.lg,
    vertical: TFSpace.md,
  );
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: TFSpace.lg,
    vertical: TFSpace.sm,
  );
  static const EdgeInsets sheetHeader = EdgeInsets.only(
    top: TFSpace.lg,
    left: TFSpace.xl,
    right: TFSpace.lg,
    bottom: TFSpace.md,
  );
}

/// 尺寸常量。
abstract final class TFSize {
  const TFSize._();

  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 24;
  static const double iconXl = 32;

  static const double avatarSm = 28;
  static const double avatarMd = 40;
  static const double avatarLg = 56;

  static const double controlSm = 32;
  static const double controlMd = 40;
  static const double controlLg = 48;

  static const double divider = 1;

  /// 底部弹层默认高度占屏比。
  static const double sheetHeightFactor = 0.8;

  /// 内容最大宽度（宽屏下的阅读舒适区）。
  static const double contentMaxWidth = 720;
}

/// 动效
abstract final class TFMotion {
  const TFMotion._();

  /// 微交互：hover、按压、图标切换
  static const Duration fast = Duration(milliseconds: 150);

  /// 常规反馈：展开、淡入、选中态
  static const Duration base = Duration(milliseconds: 200);

  /// 中等幅度：列表项增删、卡片扩展
  static const Duration medium = Duration(milliseconds: 250);

  /// 页面级：全屏转场、弹层进出
  static const Duration slow = Duration(milliseconds: 300);

  /// 强调：需要被注意到的状态切换
  static const Duration emphasized = Duration(milliseconds: 500);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve decelerate = Curves.easeOut;
  static const Curve accelerate = Curves.easeIn;
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;

  /// 折叠/展开统一曲线，常用 `Curves.fastOutSlowIn` 的替代
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// 尊重系统「减少动效」设置：返回零时长
  static Duration respecting(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// 透明度阶梯，集中管理 `.withValues(alpha: ...)` 的取值
abstract final class TFAlpha {
  const TFAlpha._();

  /// 极轻描边/分隔
  static const double hairline = 0.08;

  /// 悬停底色
  static const double hover = 0.06;

  /// 按压底色
  static const double pressed = 0.10;

  /// 选中底色
  static const double selected = 0.12;

  /// 分隔线
  static const double divider = 0.16;

  /// 禁用态前景
  static const double disabled = 0.38;

  /// 半透明遮罩
  static const double scrim = 0.5;
}
