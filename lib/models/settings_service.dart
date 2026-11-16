import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'settings_model.dart';
import '../utils/talker.dart';

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

  /// 单设置项变更
  final Map<String, ValueNotifier<int>> _keyRevisions = {};

  ValueListenable<int> revisionOf(String key) =>
      _keyRevisions.putIfAbsent(key, () => ValueNotifier<int>(0));

  void _bumpRevision(String key) {
    final notifier = _keyRevisions[key];
    if (notifier != null) notifier.value++;
  }

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

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

  Map<String, dynamic>? getJsonValue(String key) {
    if (!_initialized) return null;
    final jsonString = _prefs.getString(key);
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      talker.error('Failed to decode JSON setting for key: $key', e);
      return null;
    }
  }

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

    _bumpRevision(key);
    notifyListeners();
  }

  // Set JSON value
  Future<void> setJsonValue(String key, Map<String, dynamic>? value) async {
    if (!_initialized) await init();

    if (value != null) {
      final jsonString = jsonEncode(value);
      await _prefs.setString(key, jsonString);
    } else {
      await _prefs.remove(key);
    }

    _bumpRevision(key);
    notifyListeners();
  }

  Future<void> remove(String key) async {
    if (!_initialized) await init();
    await _prefs.remove(key);
    _bumpRevision(key);
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

  Future<void> resetToDefaults() async {
    if (!_initialized) await init();

    for (var item in getAllSettingItems()) {
      if (item.defaultValue != null) {
        await setValue(item.key, item.defaultValue);
      }
    }
  }
}
