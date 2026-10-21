import 'dart:async';

import 'package:flutter/material.dart';

enum SnackbarType { info, success, error, warning }

class TouchFishSnackbarService extends ChangeNotifier {
  static final instance = TouchFishSnackbarService._();
  TouchFishSnackbarService._();

  static const _displayDuration = Duration(seconds: 3);

  String? _message;
  String? get message => _message;

  SnackbarType _type = SnackbarType.info;
  SnackbarType get type => _type;

  Timer? _clearTimer;

  void show(String message, {SnackbarType type = SnackbarType.info}) {
    _message = message;
    _type = type;
    // 超时放在 service 侧：放在 widget 的 build 里会被任何重建重置，
    // 高频重建时提示条可能永远不消失。
    _clearTimer?.cancel();
    _clearTimer = Timer(_displayDuration, clear);
    notifyListeners();
  }

  void showSuccess(String message) {
    show(message, type: SnackbarType.success);
  }

  void showError(String message) {
    show(message, type: SnackbarType.error);
  }

  void showWarning(String message) {
    show(message, type: SnackbarType.warning);
  }

  void clear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }
}
