import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:virtual_keypad/virtual_keypad.dart';

import '../models/settings_service.dart';
import '../services/lock_screen_visibility_service.dart';

/// 这真的有用吗？
/// 似乎并不能帮wyf解决难以启齿之苦，但是加了很好玩
class AppVirtualKeyboard extends StatefulWidget {
  const AppVirtualKeyboard({super.key});

  @override
  State<AppVirtualKeyboard> createState() => _AppVirtualKeyboardState();
}

class _AppVirtualKeyboardState extends State<AppVirtualKeyboard>
    with WidgetsBindingObserver {
  static const String _modeKey = 'builtInKeyboardMode';
  static const String _modeNever = 'never';
  static const String _modeLock = 'lock';
  static const String _modeAlways = 'always';

  Timer? _pollTimer;
  bool _keyguardLocked = false;

  String get _mode =>
      SettingsService.instance.getValue<String>(_modeKey, _modeLock);

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
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    _syncPolling();
    setState(() {});
  }

  void _syncPolling() {
    final needsPolling = !kIsWeb && Platform.isAndroid && _mode == _modeLock;
    if (needsPolling) {
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: 2),
        (_) => _checkKeyguard(),
      );
      _checkKeyguard();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _checkKeyguard() async {
    final locked = await LockScreenVisibilityService.instance.isKeyguardLocked();
    if (!mounted || locked == null || locked == _keyguardLocked) return;
    setState(() => _keyguardLocked = locked);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkKeyguard();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) return const SizedBox.shrink();
    if (!_enabled) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: VirtualKeypad(
        standalone: true,
        availableLanguages: const ['en'],
        initialLanguage: 'en',
        enableEmojiKey: false,
        theme: Theme.of(context).brightness == Brightness.dark
            ? VirtualKeypadTheme.dark
            : VirtualKeypadTheme.light,
      ),
    );
  }
}
