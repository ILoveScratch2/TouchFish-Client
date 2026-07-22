import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';

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

  Future<List<ChatMessage>> loadMessages(String roomId) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    return _loadMessages(prefs, scope, roomId);
  }

  Future<void> saveMessages(String roomId, List<ChatMessage> messages) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(scope, roomId),
      jsonEncode(messages.map((e) => e.toJson()).toList()),
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

  Future<void> clearDatabase() async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'touchfish_messages/$scope/';
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      await prefs.remove(key);
    }
  }
}
