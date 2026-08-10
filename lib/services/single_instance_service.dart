import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/talker.dart';

/// Ensures that only one instance of the TouchFish desktop app runs at a time.
///
/// The first (primary) instance binds to a fixed loopback TCP port and keeps
/// it open for the lifetime of the process. Any subsequent launch attempts to
/// connect to that port:
///   - On success, it signals the primary instance to show its window and
///     then exits immediately.
///   - On failure (connection refused), it becomes the new primary instance
///     and starts listening.
class SingleInstanceService {
  static final SingleInstanceService instance = SingleInstanceService._();

  SingleInstanceService._();

  /// Loopback port used for single-instance detection. Chosen to be unlikely
  /// to collide with common services.
  static const int _port = 47832;
  static const String _host = '127.0.0.1';
  static const String _signalShowWindow = 'show_window';

  ServerSocket? _serverSocket;
  bool _isPrimary = true;

  /// Whether this process is the first/primary instance.
  bool get isPrimary => _isPrimary;

  /// Checks for an existing instance and, if one is already running, notifies
  /// it to show the main window and returns `false` (the caller should then
  /// exit). If no instance is running, starts the listener and returns `true`.
  ///
  /// Only meaningful on desktop platforms.
  Future<bool> tryAcquireSingleInstance() async {
    if (kIsWeb) return true;

    // Try to reach an already-running instance.
    try {
      final socket = await Socket.connect(
        _host,
        _port,
        timeout: const Duration(milliseconds: 500),
      );
      // An instance is already running — tell it to bring its window forward.
      socket.add(utf8.encode(_signalShowWindow));
      await socket.flush();
      await socket.close();
      _isPrimary = false;
      talker.info(
        'Another TouchFish instance is already running; notifying it to show the window.',
      );
      return false;
    } on SocketException {
      // No instance is listening — this process becomes the primary.
    } catch (error, stackTrace) {
      talker.warning('Single instance probe failed: $error', error, stackTrace);
      // Be conservative: treat as primary if the probe was inconclusive.
    }

    // Become the primary instance by binding the port.
    try {
      _serverSocket = await ServerSocket.bind(_host, _port, shared: false);
      _serverSocket!.listen(
        _onClientConnected,
        onError: (Object error, StackTrace stackTrace) {
          talker.warning('Single instance listener error: $error');
        },
      );
      _isPrimary = true;
      talker.info('TouchFish single-instance listener started on port $_port.');
    } catch (error, stackTrace) {
      // Binding failed unexpectedly — still continue as primary so the app
      // works, but the single-instance guarantee may be degraded.
      talker.error(
        'Failed to bind single-instance listener: $error',
        error,
        stackTrace,
      );
      _isPrimary = true;
    }
    return true;
  }

  void _onClientConnected(Socket client) {
    client.listen(
      (data) {
        final message = utf8.decode(data, allowMalformed: true);
        if (message.contains(_signalShowWindow)) {
          talker.info(
            'Received show-window signal from a second TouchFish instance',
          );
          _notifyShowWindow();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        talker.warning('Single instance client error: $error');
      },
      onDone: () {
        client.close();
      },
      cancelOnError: true,
    );
  }

  /// Callback invoked when another instance requests the main window to be
  /// shown. Wired up by [main] to [DesktopAppLifecycleService.showWindow].
  void Function()? onShowWindowRequested;

  void _notifyShowWindow() {
    onShowWindowRequested?.call();
  }

  /// Releases the bound port. Call during shutdown if needed.
  Future<void> dispose() async {
    await _serverSocket?.close();
    _serverSocket = null;
  }
}