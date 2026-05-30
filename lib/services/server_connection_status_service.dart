import 'dart:async';

import 'package:flutter/foundation.dart';

enum ServerConnectionBannerPhase { hidden, connecting, disconnected, connected }

class ServerConnectionStatusService extends ChangeNotifier {
  static final ServerConnectionStatusService instance =
      ServerConnectionStatusService._();

  ServerConnectionStatusService._();

  static const _connectedDisplayDuration = Duration(seconds: 2);

  ServerConnectionBannerPhase _phase = ServerConnectionBannerPhase.hidden;
  Future<bool> Function()? _retryHandler;
  Timer? _hideTimer;
  bool _isProbing = false;

  ServerConnectionBannerPhase get phase => _phase;
  bool get isVisible => _phase != ServerConnectionBannerPhase.hidden;
  bool get isProbing => _isProbing;

  void reportReachable() {
    if (_phase == ServerConnectionBannerPhase.hidden && !_isProbing) {
      return;
    }

    _hideTimer?.cancel();
    _setPhase(ServerConnectionBannerPhase.connected);
    _hideTimer = Timer(_connectedDisplayDuration, () {
      _setPhase(ServerConnectionBannerPhase.hidden);
    });
  }

  void reportConnectionLost({required Future<bool> Function() retryHandler}) {
    _retryHandler = retryHandler;

    if (_isProbing) {
      return;
    }

    _hideTimer?.cancel();
    _setPhase(ServerConnectionBannerPhase.connecting);
    _isProbing = true;
    unawaited(_runProbe());
  }

  Future<void> retryConnection() async {
    if (_retryHandler == null || _isProbing) {
      return;
    }

    _hideTimer?.cancel();
    _setPhase(ServerConnectionBannerPhase.connecting);
    _isProbing = true;
    await _runProbe();
  }

  Future<void> _runProbe() async {
    final retryHandler = _retryHandler;
    if (retryHandler == null) {
      _isProbing = false;
      _setPhase(ServerConnectionBannerPhase.disconnected);
      return;
    }

    try {
      final isReachable = await retryHandler();
      if (isReachable) {
        reportReachable();
      } else {
        _setPhase(ServerConnectionBannerPhase.disconnected);
      }
    } catch (_) {
      _setPhase(ServerConnectionBannerPhase.disconnected);
    } finally {
      _isProbing = false;
    }
  }

  void _setPhase(ServerConnectionBannerPhase value) {
    if (_phase == value) {
      return;
    }
    _phase = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}