/// TouchFish 主题构造
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class TFTheme {
  const TFTheme._();

  /// 构造亮/暗主题
  static ThemeData build({
    required ColorScheme scheme,
    String? fontFamily,
    required double cardOpacity,
    required bool transparentSurfaces,
  }) {
    final isDark = scheme.brightness == Brightness.dark;

    // 表面层级
    final cardBase = scheme.surfaceContainerLow;
    final cardColor = cardOpacity >= 1
        ? cardBase
        : cardBase.withValues(alpha: cardOpacity);
    // 浮层方向相反
    final overlayColor = isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;

    var theme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: transparentSurfaces ? Colors.transparent : null,
    );

    // 注意：这里不覆写 textTheme / primaryTextTheme
    //
    // 否则会导致大量插值问题！！

    // AppBar 标题从 M3 默认 22sp/w400 改成 16sp/w600，似乎实测比较统一
    final titleSource = theme.textTheme.titleLarge;

    theme = theme.copyWith(
      // ----------  AppBar 的默认观感 ----------
      appBarTheme: AppBarThemeData(
        backgroundColor: transparentSurfaces ? Colors.transparent : scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        titleTextStyle: TextStyle(
          inherit: false,
          fontFamily: titleSource?.fontFamily,
          fontFamilyFallback: titleSource?.fontFamilyFallback,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          height: 1.3,
          color: scheme.onSurface,
        ),
      ),

      // ---------- 滚动条：桌面端细悬停加粗无轨 ----------
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.resolveWith((states) {
          final active =
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged);
          return active ? 8 : 4;
        }),
        radius: const Radius.circular(TFRadius.pill),
        crossAxisMargin: 2,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final active =
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged);
          return scheme.onSurfaceVariant.withValues(alpha: active ? 0.55 : 0.32);
        }),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        trackVisibility: const WidgetStatePropertyAll(false),
      ),

      // ---------- 卡片 ----------
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: const EdgeInsets.all(TFSpace.xs),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: TFRadius.cardRadius),
      ),

      // ----------  对话框 ----------
      dialogTheme: DialogThemeData(
        backgroundColor: overlayColor,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 24,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: TFRadius.dialogRadius,
        ),
      ),

      // ----------  底部弹层 ----------
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: overlayColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 3,
        modalBarrierColor: Colors.black.withValues(alpha: TFAlpha.scrim),
        // 拖拽指示条交给 SheetScaffold
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: TFRadius.sheetRadius,
        ),
      ),

      // ----------  SnackBar 的默认观感 ----------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? scheme.surfaceContainerHighest
            : scheme.inverseSurface,
        elevation: 0,
        insetPadding: const EdgeInsets.all(TFSpace.lg),
        shape: const RoundedRectangleBorder(borderRadius: TFRadius.smRadius),
        actionTextColor: isDark ? scheme.primary : scheme.inversePrimary,
      ),

      // ---------- 输入框 ----------
      // 这里不配置 `inputDecorationTheme`。
      //
      // 各个框所需的样式不同，没有全局的。

      // ---------- 列表项 ----------
      // 只统一颜色，不覆盖 contentPadding / minVerticalPadding
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: const RoundedRectangleBorder(borderRadius: TFRadius.smRadius),
      ),

      // 分隔线保持 M3 默认的 `outlineVariant` 不透明度
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: TFSize.divider,
      ),

      // 键盘焦点与悬停的可见反馈
      focusColor: scheme.primary.withValues(alpha: 0.12),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          // 只加视觉反馈
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.18);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),

      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: TFRadius.smRadius),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: overlayColor,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: TFRadius.menuRadius),
      ),

      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: const FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: const FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: const FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );

    return theme;
  }
}
