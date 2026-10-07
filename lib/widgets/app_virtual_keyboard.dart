import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:virtual_keypad/virtual_keypad.dart';

import '../models/settings_service.dart';
import '../services/lock_screen_visibility_service.dart';

/// 应用内置软键盘的根部挂载点。
///
/// 这真的有用吗？
/// 似乎并不能帮wyf解决难以启齿之苦，但是加了很好玩。
///
class AppVirtualKeyboard extends StatefulWidget {
  const AppVirtualKeyboard({super.key});

  static final ValueNotifier<double> keyboardInset = ValueNotifier<double>(0);

  @override
  State<AppVirtualKeyboard> createState() => _AppVirtualKeyboardState();
}

class _AppVirtualKeyboardState extends State<AppVirtualKeyboard>
    with WidgetsBindingObserver {
  static const String _modeKey = 'builtInKeyboardMode';
  static const String _modeNever = 'never';
  static const String _modeLock = 'lock';
  static const String _modeAlways = 'always';

  final GlobalKey _keypadKey = GlobalKey();
  Timer? _pollTimer;
  bool _keyguardLocked = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  String get _mode =>
      SettingsService.instance.getValue<String>(_modeKey, _modeNever);

  bool get _enabled {
    switch (_mode) {
      case _modeNever:
        return false;
      case _modeAlways:
        return true;
      default:
        return _keyguardLocked;
    }
  }

  bool get _shouldPoll =>
      !kIsWeb &&
      Platform.isAndroid &&
      _mode == _modeLock &&
      _lifecycle == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SettingsService.instance.addListener(_onSettingsChanged);
    _syncPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    SettingsService.instance.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    AppVirtualKeyboard.keyboardInset.value = 0;
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    _syncPolling();
    setState(() {});
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkKeyguard(),
    );
    _checkKeyguard();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _syncPolling() {
    if (_shouldPoll) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  Future<void> _checkKeyguard() async {
    final locked = await LockScreenVisibilityService.instance
        .isKeyguardLocked();
    if (!mounted || locked == null || locked == _keyguardLocked) return;
    setState(() => _keyguardLocked = locked);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _syncPolling();
    if (state == AppLifecycleState.resumed) {
      _checkKeyguard();
    }
  }

  void _updateKeyboardInset() {
    final size = _keypadKey.currentContext?.size;
    AppVirtualKeyboard.keyboardInset.value = size?.height ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid || !_enabled) {
      if (AppVirtualKeyboard.keyboardInset.value != 0) {
        AppVirtualKeyboard.keyboardInset.value = 0;
      }
      return const SizedBox.shrink();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateKeyboardInset());
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => Align(
            alignment: Alignment.bottomCenter,
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                _updateKeyboardInset();
                return true;
              },
              child: SizeChangedLayoutNotifier(
                child: VirtualKeypad(
                  key: _keypadKey,
                  standalone: true,
                  availableLanguages: const ['en'],
                  initialLanguage: 'en',
                  enableEmojiKey: false,
                  theme: Theme.of(context).brightness == Brightness.dark
                      ? VirtualKeypadTheme.dark
                      : VirtualKeypadTheme.light,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
