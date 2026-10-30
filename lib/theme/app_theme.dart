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

    // 卡片底色
    final cardColor = cardOpacity >= 1
        ? scheme.surfaceContainer
        : scheme.surfaceContainer.withValues(alpha: cardOpacity);

    var theme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: transparentSurfaces ? Colors.transparent : null,
    );

    // 注意：这里不覆写 textTheme / primaryTextTheme
    //
    // 否则会导致大量插值问题！！

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
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
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

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),

      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: TFRadius.smRadius),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
