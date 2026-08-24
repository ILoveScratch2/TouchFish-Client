import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/app_state.dart';

/// 在无 BuildContext 的环境（服务、托盘、系统通知等）解析当前语言实例。
///
/// 规则与 [MaterialApp.locale] 一致：
/// 1. 显式设置的语言（设置里的 language）优先；
/// 2. 否则跟随系统语言，映射到 zh/en/och 之一；
/// 3. 无法识别时回退简体中文。
AppLocalizations currentAppLocalizations() {
  final locale = AppState.instance.locale;
  if (locale != null) return lookupAppLocalizations(locale);

  final sys = WidgetsBinding.instance.platformDispatcher.locale;
  final mapped = switch (sys.languageCode) {
    'en' => const Locale('en'),
    'och' => const Locale('och'),
    _ => const Locale('zh'),
  };
  return lookupAppLocalizations(mapped);
}
