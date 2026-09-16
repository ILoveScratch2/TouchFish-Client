import 'package:flutter/material.dart';

enum SnackbarType { info, success, error, warning }

class TouchFishSnackbarService extends ChangeNotifier {
  static final instance = TouchFishSnackbarService._();
  TouchFishSnackbarService._();

  String? _message;
  String? get message => _message;

  SnackbarType _type = SnackbarType.info;
  SnackbarType get type => _type;

  void show(String message, {SnackbarType type = SnackbarType.info}) {
    _message = message;
    _type = type;
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
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }
}
