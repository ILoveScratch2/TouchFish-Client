import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_model.dart';

// Settings persistence - Simple, no magic
class SettingsService extends ChangeNotifier {
  static SettingsService? _instance;
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Singleton pattern - one source of truth
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  SettingsService._();

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // Get setting value - return default if not found
  T getValue<T>(String key, T defaultValue) {
    if (!_initialized) return defaultValue;

    if (T == bool) {
      return (_prefs.getBool(key) ?? defaultValue) as T;
    } else if (T == String) {
      return (_prefs.getString(key) ?? defaultValue) as T;
    } else if (T == int) {
      return (_prefs.getInt(key) ?? defaultValue) as T;
    } else if (T == double) {
      return (_prefs.getDouble(key) ?? defaultValue) as T;
    }

    return defaultValue;
  }

  // Set setting value - notify listeners
  Future<void> setValue(String key, dynamic value) async {
    if (!_initialized) await init();

    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    }

    notifyListeners();
  }

  // Get all setting items recursively
  static List<SettingItem> getAllSettingItems() {
    final List<SettingItem> allItems = [];
    for (var category in SettingsData.categories) {
      for (var item in category.items) {
        allItems.add(item);
        if (item.subItems != null) {
          allItems.addAll(item.subItems!);
        }
      }
    }
    return allItems;
  }

  // Reset all settings to default
  Future<void> resetToDefaults() async {
    if (!_initialized) await init();

    for (var item in getAllSettingItems()) {
      if (item.defaultValue != null) {
        await setValue(item.key, item.defaultValue);
      }
    }
  }
}
