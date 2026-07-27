import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api/tf_api_client.dart';
import 'auth_state.dart';
import '../models/settings_service.dart';

class DraftService {
  DraftService._();

  static final instance = DraftService._();

  bool _isEnabled(String type) {
    final settingKey = type == 'chat' ? 'saveChatDrafts' : 'saveForumDrafts';
    return SettingsService.instance.getValue<bool>(settingKey, true);
  }

  String _draftGroup(String type) => type == 'chat' ? 'chat' : 'forum';

  Future<String?> _scopedKey(String namespace, String type, String id) async {
    final uid = AuthState.instance.uid;
    if (uid == null) return null;
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    final scope = base64Url.encode(utf8.encode('$baseUrl:$uid'));
    final entity = base64Url.encode(utf8.encode(id));
    return 'touchfish_${namespace}_${scope}_${type}_$entity';
  }

  Future<Map<String, dynamic>?> loadDraft(String type, String id) async {
    if (!_isEnabled(type)) return null;
    final key = await _scopedKey('draft', type, id);
    if (key == null) return null;
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDraft(
    String type,
    String id,
    Map<String, dynamic> value,
  ) async {
    if (!_isEnabled(type)) return;
    final key = await _scopedKey('draft', type, id);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final hasContent = value.values.any((item) {
      if (item is String) return item.isNotEmpty;
      if (item is Iterable) return item.isNotEmpty;
      return item != null;
    });
    if (hasContent) {
      await prefs.setString(key, jsonEncode(value));
    } else {
      await prefs.remove(key);
    }
  }

  Future<void> clearDraft(String type, String id) async {
    final key = await _scopedKey('draft', type, id);
    if (key == null) return;
    await (await SharedPreferences.getInstance()).remove(key);
  }

  Future<void> clearDraftGroup(String group) async {
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    final scope = base64Url.encode(utf8.encode('$baseUrl:$uid'));
    final prefix = 'touchfish_draft_${scope}_';
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) {
      if (!key.startsWith(prefix)) return false;
      final type = key.substring(prefix.length).split('_').first;
      return _draftGroup(type) == group;
    }).toList();
    await Future.wait(keys.map(prefs.remove));
  }

  Future<bool> isAcknowledged(String type, String id, String value) async {
    final key = await _scopedKey('ack', type, id);
    if (key == null) return false;
    return (await SharedPreferences.getInstance()).getString(key) == value;
  }

  Future<void> acknowledge(String type, String id, String value) async {
    final key = await _scopedKey('ack', type, id);
    if (key == null) return;
    await (await SharedPreferences.getInstance()).setString(key, value);
  }
}
