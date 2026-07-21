import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';

class LocalMessageStore {
  static LocalMessageStore? _instance;
  static LocalMessageStore get instance => _instance ??= LocalMessageStore._();
  LocalMessageStore._();
  String _scope = 'default/0';

  void setServerKey(String serverAddress) {
    final encoded = base64Url.encode(utf8.encode(serverAddress));
    _scope = '$encoded/${_scope.split('/').last}';
  }

  void setUid(int uid) => _scope = '${_scope.split('/').first}/$uid';
  String _key(String roomId) => 'touchfish_messages/$_scope/$roomId';

  Future<List<ChatMessage>> loadMessages(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(roomId));
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveMessages(String roomId, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(roomId),
      jsonEncode(messages.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> appendMessage(String roomId, ChatMessage message) async {
    final messages = await loadMessages(roomId);
    if (!messages.any(
      (e) =>
          e.id == message.id ||
          (e.clientMid != null && e.clientMid == message.clientMid),
    )) {
      await saveMessages(roomId, [...messages, message]);
    }
  }

  Future<void> deleteRoom(String roomId) async =>
      (await SharedPreferences.getInstance()).remove(_key(roomId));
  Future<void> clearDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith('touchfish_messages/'),
    )) {
      await prefs.remove(key);
    }
  }
}
