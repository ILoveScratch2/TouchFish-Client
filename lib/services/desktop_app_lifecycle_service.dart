import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../models/settings_service.dart';
import '../utils/talker.dart';

/// Manages desktop-app lifecycle behaviors:
/// - Keeps the app alive in the system tray when the window is closed.
/// - Restores the hidden window when the tray icon is clicked or when the app
///   is launched again.
/// - Persists window bounds (size/position) across sessions.
class DesktopAppLifecycleService with TrayListener, WindowListener {
  static final DesktopAppLifecycleService instance =
      DesktopAppLifecycleService._();

  DesktopAppLifecycleService._();

  static const String keyCloseToTray = 'closeToTray';
  static const String keyWasInTray = 'was_in_tray';
  static const String keyWindowMaximized = 'window_maximized';

  bool _initialized = false;
  bool _isQuitting = false;

  /// Whether the window was hidden to the tray during the previous session.
  bool get wasHiddenInTray => _wasHiddenInTray;
  bool _wasHiddenInTray = false;

  /// Whether closing the main window should hide to tray instead of exiting.
  bool get isCloseToTrayEnabled =>
      SettingsService.instance.getValue<bool>(keyCloseToTray, true);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      return;
    }

    windowManager.addListener(this);
    trayManager.addListener(this);

    final prefs = await SharedPreferences.getInstance();
    _wasHiddenInTray = prefs.getBool(keyWasInTray) ?? false;
  }

  /// Sets up the tray icon and intercepts window close. Must be called after
  /// the native window is fully created (i.e. inside
  /// [WindowManager.waitUntilReadyToShow]), otherwise the tray icon fails to
  /// register on Windows because the main window handle is not valid yet.
  Future<void> afterWindowReady() async {
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      return;
    }
    await _setupTray();
    await windowManager.setPreventClose(true);
    await _restoreMaximizedStateIfNeeded();
  }

  /// Restores the persisted window state (maximized) after the window is
  /// ready to be shown. Called from [main] after the window is displayed.
  Future<void> restoreWindowState() async {
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      return;
    }
    await _restoreMaximizedStateIfNeeded();
  }

  Future<void> _setupTray() async {
    try {
      // Windows only supports .ico via LoadImage, while macOS/Linux work
      // well with PNG. Use the platform-appropriate icon file.
      final iconAsset = Platform.isWindows ? 'assets/icon.ico' : 'assets/logo.png';
      await trayManager.setIcon(iconAsset);
      await trayManager.setToolTip('TouchFish Client');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(
              key: 'show',
              label: '打开 TouchFish',
              onClick: (_) => showWindow(),
            ),
            MenuItem(
              key: 'hide',
              label: '隐藏窗口',
              onClick: (_) => hideWindow(),
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'quit',
              label: '退出',
              onClick: (_) => quit(),
            ),
          ],
        ),
      );
    } catch (error, stackTrace) {
      talker.error('Failed to initialize system tray', error, stackTrace);
    }
  }

  /// Shows and focuses the main window.
  Future<void> showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyWasInTray, false);
      _wasHiddenInTray = false;
    } catch (error, stackTrace) {
      talker.error('Failed to show window', error, stackTrace);
    }
  }

  /// Hides the main window to the system tray.
  Future<void> hideWindow() async {
    try {
      await _saveWindowState();
      await windowManager.hide();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyWasInTray, true);
      _wasHiddenInTray = true;
    } catch (error, stackTrace) {
      talker.error('Failed to hide window', error, stackTrace);
    }
  }

  /// Truly quits the app.
  Future<void> quit() async {
    if (_isQuitting) return;
    _isQuitting = true;
    try {
      await _saveWindowState();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyWasInTray, false);
      await windowManager.destroy();
    } catch (error, stackTrace) {
      talker.error('Failed to quit app', error, stackTrace);
    }
  }

  // ---- WindowListener ----

  @override
  void onWindowClose() async {
    if (_isQuitting) {
      await windowManager.destroy();
      return;
    }

    await _saveWindowState();

    if (isCloseToTrayEnabled) {
      await hideWindow();
    } else {
      // Closing should still quit if close-to-tray is disabled.
      _isQuitting = true;
      await windowManager.destroy();
    }
  }

  @override
  void onWindowMoved() async {
    await _saveWindowState();
  }

  @override
  void onWindowResized() async {
    await _saveWindowState();
  }

  @override
  void onWindowMaximize() async {
    await _saveWindowState();
  }

  @override
  void onWindowUnmaximize() async {
    await _saveWindowState();
  }

  Future<void> _saveWindowState() async {
    try {
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) return;
      final isMaximized = await windowManager.isMaximized();
      final bounds = await windowManager.getBounds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('window_width', bounds.width);
      await prefs.setDouble('window_height', bounds.height);
      await prefs.setDouble('window_x', bounds.left);
      await prefs.setDouble('window_y', bounds.top);
      await prefs.setBool(keyWindowMaximized, isMaximized);
    } catch (error, stackTrace) {
      talker.error('Failed to save window state', error, stackTrace);
    }
  }

  Future<void> _restoreMaximizedStateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final wasMaximized = prefs.getBool(keyWindowMaximized) ?? false;
    if (wasMaximized) {
      try {
        await windowManager.maximize();
      } catch (error) {
        talker.debug('Could not restore maximized window state: $error');
      }
    }
  }

  /// Whether the app should immediately show the window because it was
  /// hidden to the tray during the previous session.
  static Future<bool> shouldRestoreFromTray() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyWasInTray) ?? false;
  }

  // ---- TrayListener ----

  @override
  void onTrayIconMouseDown() {
    _onTrayActivated();
  }

  @override
  void onTrayIconMouseUp() {
    _onTrayActivated();
  }

  @override
  void onTrayIconRightMouseDown() {
    // On Windows this callback fires on WM_RBUTTONUP (mouse-up), and the
    // context menu must be popped up manually because it is not shown by
    // the OS. macOS and Linux display the context menu automatically.
    // bringAppToFront=true makes TrackPopupMenu work even when the window
    // is hidden to the tray.
    if (Platform.isWindows) {
      unawaited(trayManager.popUpContextMenu(bringAppToFront: true));
    }
  }

  @override
  void onTrayIconRightMouseUp() {
    // Not used on Windows (the plugin reports right-click as mouse-down).
    // macOS/Linux handle the context menu natively.
  }

  void _onTrayActivated() {
    unawaited(showWindow());
  }
}
