import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/local_message_search_result.dart';

class LocalMessageStore {
  static LocalMessageStore? _instance;
  static LocalMessageStore get instance => _instance ??= LocalMessageStore._();
  LocalMessageStore._();
  String? _scope;

  void configureScope(String serverAddress, int uid) {
    final encoded = base64Url.encode(utf8.encode(serverAddress));
    _scope = '$encoded/$uid';
  }

  void clearScope() => _scope = null;

  String? get currentScope => _scope;

  String _requireScope() {
    final scope = _scope;
    if (scope == null) {
      throw StateError('LocalMessageStore scope is not configured');
    }
    return scope;
  }

  String _key(String scope, String roomId) =>
      'touchfish_messages/$scope/$roomId';
  int _scopeUid(String scope) => int.parse(scope.split('/').last);

  String _messageKey(ChatMessage message) =>
      message.clientMid?.isNotEmpty == true
      ? 'client:${message.clientMid}'
      : 'id:${message.id}';

  int _compareMessages(ChatMessage a, ChatMessage b) {
    final byTime = a.timestamp.compareTo(b.timestamp);
    return byTime != 0 ? byTime : _messageKey(a).compareTo(_messageKey(b));
  }

  Future<List<ChatMessage>> _loadMessages(
    SharedPreferences prefs,
    String scope,
    String roomId,
  ) async {
    final raw = prefs.getString(_key(scope, roomId));
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map(
          (e) => ChatMessage.fromJson(
            Map<String, dynamic>.from(e as Map),
            activeUid: _scopeUid(scope),
          ),
        )
        .toList();
  }

  Future<List<ChatMessage>> loadMessages(
    String roomId, {
    int? limit,
    ChatMessage? before,
  }) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final messages = await _loadMessages(prefs, scope, roomId);
    messages.sort(_compareMessages);
    final filtered = before == null
        ? messages
        : messages.where((message) => _compareMessages(message, before) < 0);
    final result = filtered.toList();
    if (limit == null || result.length <= limit) return result;
    return result.sublist(result.length - limit);
  }

  Future<void> saveMessages(String roomId, List<ChatMessage> messages) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadMessages(prefs, scope, roomId);
    final merged = <String, ChatMessage>{
      for (final message in existing) _messageKey(message): message,
      for (final message in messages) _messageKey(message): message,
    }.values.toList()..sort(_compareMessages);
    await prefs.setString(
      _key(scope, roomId),
      jsonEncode(merged.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> appendMessage(String roomId, ChatMessage message) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final messages = await _loadMessages(prefs, scope, roomId);
    if (!messages.any(
      (e) =>
          e.id == message.id ||
          (e.clientMid != null && e.clientMid == message.clientMid),
    )) {
      await prefs.setString(
        _key(scope, roomId),
        jsonEncode([...messages, message].map((e) => e.toJson()).toList()),
      );
    }
  }

  Future<void> deleteRoom(String roomId) async {
    final scope = _requireScope();
    await (await SharedPreferences.getInstance()).remove(_key(scope, roomId));
  }

  Future<Map<String, ({int messages, int bytes})>> roomStats() async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'touchfish_messages/$scope/';
    final result = <String, ({int messages, int bytes})>{};
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final raw = prefs.getString(key) ?? '[]';
      var count = 0;
      try {
        count = (jsonDecode(raw) as List<dynamic>).length;
      } catch (_) {}
      result[key.substring(prefix.length)] = (
        messages: count,
        bytes: utf8.encode(raw).length,
      );
    }
    return result;
  }

  Future<int> databaseSize() async {
    final stats = await roomStats();
    return stats.values.fold<int>(0, (sum, value) => sum + value.bytes);
  }

  Future<Map<String, dynamic>> exportSnapshot() async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'touchfish_messages/$scope/';
    final messages = <Map<String, dynamic>>[];
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final roomId = key.substring(prefix.length);
      for (final message in await _loadMessages(prefs, scope, roomId)) {
        messages.add({'roomId': roomId, 'messageKey': _messageKey(message), 'timestamp': message.timestamp.millisecondsSinceEpoch, 'payload': message.toJson()});
      }
    }
    return {'server': scope, 'messages': messages};
  }

  Future<int> importSnapshot(Map<String, dynamic> snapshot) async {
    final messages = snapshot['messages'];
    if (messages is! List) return 0;
    var count = 0;
    for (final raw in messages.whereType<Map>()) {
      final roomId = raw['roomId']?.toString();
      final payload = raw['payload'];
      if (roomId == null || payload is! Map) continue;
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(payload), activeUid: _scopeUid(_requireScope()));
      await saveMessages(roomId, [message]);
      count++;
    }
    return count;
  }

  Future<String?> databasePath() async => null;

  Future<int?> getRoomSyncMid(String roomId) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('touchfish_sync_mid/$scope/$roomId');
    return raw == null ? null : int.tryParse(raw);
  }

  Future<int?> getRoomSyncSeq(String roomId) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('touchfish_sync_seq/$scope/$roomId');
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveRoomSyncPoint(String roomId, int seq) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('touchfish_sync_seq/$scope/$roomId', '$seq');
  }

  Future<void> clearDatabase() async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'touchfish_messages/$scope/';
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      await prefs.remove(key);
    }
  }

  Future<List<ChatMessage>> loadAllMessages(String roomId) async {
    return loadMessages(roomId);
  }

  Future<List<LocalMessageSearchResult>> searchAllRooms(
    String query, {
    int limit = 200,
  }) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'touchfish_messages/$scope/';
    final normalized = query.trim().toLowerCase();
    final results = <LocalMessageSearchResult>[];
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final roomId = key.substring(prefix.length);
      for (final message in await _loadMessages(prefs, scope, roomId)) {
        if (message.text.toLowerCase().contains(normalized)) {
          results.add(LocalMessageSearchResult(roomId: roomId, message: message));
        }
      }
    }
    results.sort((a, b) => b.message.timestamp.compareTo(a.message.timestamp));
    return results.take(limit).toList();
  }
}
