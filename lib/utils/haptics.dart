import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

/// 触觉反馈统一入口
abstract final class Haptics {
  const Haptics._();

  static bool enabled = true;
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static void selection() {
    if (!enabled || !_supported) return;
    HapticFeedback.selectionClick();
  }

  static void light() {
    if (!enabled || !_supported) return;
    HapticFeedback.lightImpact();
  }

  static void medium() {
    if (!enabled || !_supported) return;
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (!enabled || !_supported) return;
    HapticFeedback.heavyImpact();
  }
}
