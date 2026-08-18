import 'package:flutter/material.dart';

class TouchFishSnackbarService extends ChangeNotifier {
  static final instance = TouchFishSnackbarService._();
  TouchFishSnackbarService._();

  String? _message;
  String? get message => _message;

  void show(String message) {
    _message = message;
    notifyListeners();
  }

  void clear() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }
}
