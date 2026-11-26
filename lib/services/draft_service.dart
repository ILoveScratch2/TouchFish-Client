import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/tf_api_client.dart';
import 'auth_state.dart';
import '../models/file_attachment.dart';
import '../models/settings_service.dart';

/// 一条已保存的草稿
class DraftRecord {
  final String type;
  final String id;
  final Map<String, dynamic> data;
  final DateTime? updatedAt;

  const DraftRecord({
    required this.type,
    required this.id,
    required this.data,
    this.updatedAt,
  });

  String get title => (data['title'] as String?)?.trim() ?? '';

  String get content => (data['content'] as String?)?.trim() ?? '';

  List<FileAttachment> get attachments {
    final raw = data['attachments'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => FileAttachment.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}

class DraftService {
  DraftService._();

  static final instance = DraftService._();

  static const _draftPrefix = 'touchfish_draft_';

  static String _metadataKey(String draftKey) =>
      'touchfish_draftmeta_${draftKey.substring(_draftPrefix.length)}';

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
      await prefs.setInt(
        _metadataKey(key),
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(key);
      await prefs.remove(_metadataKey(key));
    }
  }

  Future<void> clearDraft(String type, String id) async {
    final key = await _scopedKey('draft', type, id);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove(_metadataKey(key));
  }

  /// 列出本地草稿
  Future<List<DraftRecord>> listDrafts({String? type}) async {
    final uid = AuthState.instance.uid;
    if (uid == null) return const [];
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    final scope = base64Url.encode(utf8.encode('$baseUrl:$uid'));
    final prefs = await SharedPreferences.getInstance();
    return readDraftRecords(prefs, scope: scope, type: type);
  }

  @visibleForTesting
  static List<DraftRecord> readDraftRecords(
    SharedPreferences prefs, {
    required String scope,
    String? type,
  }) {
    final prefix = '$_draftPrefix${scope}_';
    final records = <DraftRecord>[];
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      final rest = key.substring(prefix.length);
      final draftType = _readDraftType(rest);
      if (draftType == null || (type != null && draftType != type)) continue;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;

      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        continue;
      }

      final encodedId = rest.substring(draftType.length + 1);
      final id = _decodeId(encodedId);
      if (id == null) continue;
      final savedAt = prefs.getInt(_metadataKey(key));
      records.add(
        DraftRecord(
          type: draftType,
          id: id,
          data: data,
          updatedAt: savedAt == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(savedAt),
        ),
      );
    }

    records.sort((a, b) {
      final left = a.updatedAt;
      final right = b.updatedAt;
      if (left == null && right == null) return a.id.compareTo(b.id);
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return records;
  }

  static String? _readDraftType(String suffix) {
    // The type and the base64url ID can both contain underscores.
    for (final type in const ['forum_post', 'forum_comment', 'forum_create']) {
      if (suffix.startsWith('${type}_')) return type;
    }
    final separator = suffix.indexOf('_');
    return separator > 0 ? suffix.substring(0, separator) : null;
  }

  static String? _decodeId(String encoded) {
    try {
      return utf8.decode(base64Url.decode(encoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraftGroup(String group) async {
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    final scope = base64Url.encode(utf8.encode('$baseUrl:$uid'));
    final prefix = '$_draftPrefix${scope}_';
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) {
      if (!key.startsWith(prefix)) return false;
      final type = _readDraftType(key.substring(prefix.length));
      return type != null && _draftGroup(type) == group;
    }).toList();
    await Future.wait([
      for (final key in keys) ...[
        prefs.remove(key),
        prefs.remove(_metadataKey(key)),
      ],
    ]);
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
