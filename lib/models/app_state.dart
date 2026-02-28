import 'package:flutter/material.dart';
import 'settings_service.dart';

class AppState extends ChangeNotifier {
  static AppState? _instance;
  final _settingsService = SettingsService.instance;

  static AppState get instance {
    _instance ??= AppState._();
    return _instance!;
  }

  AppState._() {
    _settingsService.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    notifyListeners();
  }

  Locale? get locale {
    final lang = _settingsService.getValue<String>('language', 'system');
    if (lang == 'system') return null;
    return Locale(lang);
  }

  ThemeMode get themeMode {
    final theme = _settingsService.getValue<String>('theme', 'system');
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String get themeColorKey {
    return _settingsService.getValue<String>('themeColor', 'blue');
  }

  Color get themeColor {
    final color = themeColorKey;
    switch (color) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'custom':
        if (customSeedColor != null) {
          return Color(customSeedColor!);
        }
        return const Color(0xFF6750A4);
      default:
        return const Color(0xFF6750A4);
    }
  }
  int? get customSeedColor {
    final customColors = _settingsService.getJsonValue('customColors');
    return customColors?['seedColor'] as int?;
  }
  Map<String, int>? get customColors {
    final json = _settingsService.getJsonValue('customColors');
    if (json == null) return null;
    return json.map((key, value) => MapEntry(key, value as int));
  }

  double get cardOpacity {
    return _settingsService.getValue<double>('cardOpacity', 1.0);
  }

  double get windowOpacity {
    return _settingsService.getValue<double>('windowOpacity', 1.0);
  }

  String? get backgroundImagePath {
    return _settingsService.getValue<String>('backgroundImagePath', '');
  }

  String? get fontFamily {
    final font = _settingsService.getValue<String>('fontFamily', 'HarmonyOS Sans SC');
    if (font == 'System Default') return null;
    if (font == '__custom__') {
      final customFontName =
          _settingsService.getValue<String>('customFontName', '');
      if (customFontName.isEmpty) return null;
      return customFontName;
    }
    return font;
  }

  bool get animationsEnabled {
    return _settingsService.getValue<bool>('enableAnimations', true);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
