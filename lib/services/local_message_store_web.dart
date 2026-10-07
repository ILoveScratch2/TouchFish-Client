import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/local_message_search_result.dart';
import '../utils/talker.dart';

class LocalMessageStore {
  static LocalMessageStore? _instance;
  static LocalMessageStore get instance => _instance ??= LocalMessageStore._();
  LocalMessageStore._();
  String? _scope;

  /// 单房间最多保留的消息条数
  static const int _maxMessagesPerRoom = 300;

  /// 消息缓存总字节预算。
  ///
  /// localStorage 通常只有约 5MB
  static const int _maxTotalBytes = 3 * 1024 * 1024;

  static const String _messagesPrefix = 'touchfish_messages/';

  static final RegExp _timestampPattern = RegExp(r'"timestamp":(\d+)');

  void configureScope(String serverAddress, int uid) {
    final encoded = base64Url.encode(utf8.encode(serverAddress));
    _scope = '$encoded/$uid';
    // 启动时检查历史遗留的超额缓存：升级前的版本可能已把 localStorage 塞满，
    // 不先瘦身的话后续其它 prefs 写入（会话列表/设置）会先抛配额错误。
    unawaited(_enforceBudgetOnStartup());
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

  int _compareMessages(ChatMessage a, ChatMessage b) =>
      ChatMessage.compareByOrder(a, b, _messageKey);

  /// 只保留最新的 [_maxMessagesPerRoom] 条（输入需已按时间升序）。
  List<ChatMessage> _trimNewest(List<ChatMessage> messages) {
    if (messages.length <= _maxMessagesPerRoom) return messages;
    return messages.sublist(messages.length - _maxMessagesPerRoom);
  }

  /// 从房间缓存 JSON 中取出最新消息时间戳（毫秒），用于淘汰排序。
  int _latestTimestampMs(String raw) {
    var latest = 0;
    for (final match in _timestampPattern.allMatches(raw)) {
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > latest) latest = value;
    }
    return latest;
  }

  /// 按总字节预算淘汰最旧的房间缓存（按各房间最新消息时间排序）。
  Future<void> _evictOldest(
    SharedPreferences prefs, {
    required String keepKey,
    required int targetBytes,
  }) async {
    final rooms = <({String key, int bytes, int latest})>[];
    var total = 0;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_messagesPrefix)) continue;
      final raw = prefs.getString(key) ?? '';
      final bytes = utf8.encode(raw).length;
      total += bytes;
      rooms.add((key: key, bytes: bytes, latest: _latestTimestampMs(raw)));
    }
    rooms.sort((a, b) => a.latest.compareTo(b.latest));
    for (final room in rooms) {
      if (total <= targetBytes) break;
      if (room.key == keepKey) continue;
      await prefs.remove(room.key);
      total -= room.bytes;
      talker.info(
        'LocalMessageStore(web): 淘汰本地消息缓存 ${room.key}（${room.bytes} 字节）',
      );
    }
  }

  /// 写 shared_preferences；配额不足时淘汰最旧房间缓存后重试一次。
  ///
  /// 失败只记日志不抛出：本地消息缓存是可再生的，不应影响消息主流程。
  Future<void> _write(SharedPreferences prefs, String key, String value) async {
    try {
      await prefs.setString(key, value);
      return;
    } catch (e) {
      talker.warning('LocalMessageStore(web): 写入配额不足，清理最旧缓存后重试（$e）');
    }
    await _evictOldest(prefs, keepKey: key, targetBytes: _maxTotalBytes ~/ 2);
    try {
      await prefs.setString(key, value);
    } catch (e) {
      talker.error('LocalMessageStore(web): 清理后仍写入失败 $e');
    }
  }

  /// 配额紧急清理：删除所有作用域下的本地消息缓存。
  ///
  /// 供 token 等关键数据写入失败时兜底调用（这些数据必须能落盘）。
  Future<void> emergencyTrimForQuota() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs
          .getKeys()
          .where((key) => key.startsWith(_messagesPrefix))
          .toList()) {
        await prefs.remove(key);
      }
      talker.warning('LocalMessageStore(web): 已执行配额紧急清理（删除全部本地消息缓存）');
    } catch (e) {
      talker.error('LocalMessageStore(web): 配额紧急清理失败 $e');
    }
  }

  /// 启动自检：消息缓存总量超预算时提前淘汰，避免下次写入才爆配额。
  Future<void> _enforceBudgetOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var total = 0;
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_messagesPrefix)) continue;
        total += utf8.encode(prefs.getString(key) ?? '').length;
      }
      if (total <= _maxTotalBytes) return;
      talker.warning(
        'LocalMessageStore(web): 启动自检发现消息缓存超额（$total 字节），开始清理',
      );
      await _evictOldest(prefs, keepKey: '', targetBytes: _maxTotalBytes ~/ 2);
    } catch (e) {
      talker.warning('LocalMessageStore(web): 启动自检失败 $e');
    }
  }

  Future<List<ChatMessage>> _loadMessages(
    SharedPreferences prefs,
    String scope,
    String roomId,
  ) async {
    final raw = prefs.getString(_key(scope, roomId));
    if (raw == null) return [];
    final messages = <ChatMessage>[];
    for (final e in jsonDecode(raw) as List<dynamic>) {
      try {
        messages.add(
          ChatMessage.fromJson(
            Map<String, dynamic>.from(e as Map),
            activeUid: _scopeUid(scope),
          ),
        );
      } catch (_) {}
    }
    return messages;
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
    await _write(
      prefs,
      _key(scope, roomId),
      jsonEncode(_trimNewest(merged).map((e) => e.toJson()).toList()),
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
      await _write(
        prefs,
        _key(scope, roomId),
        jsonEncode(
          _trimNewest([...messages, message]).map((e) => e.toJson()).toList(),
        ),
      );
    }
  }

  Future<void> deleteMessage(String roomId, ChatMessage message) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final key = _messageKey(message);
    final messages = await _loadMessages(prefs, scope, roomId);
    final remaining = messages
        .where((e) => _messageKey(e) != key)
        .map((e) => e.toJson())
        .toList();
    if (remaining.length == messages.length) return;
    await _write(prefs, _key(scope, roomId), jsonEncode(remaining));
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
      try {
        final message = ChatMessage.fromJson(
          Map<String, dynamic>.from(payload),
          activeUid: _scopeUid(_requireScope()),
        );
        await saveMessages(roomId, [message]);
        count++;
      } catch (_) {}
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

  Future<ChatMessage?> findMessageByMid(String roomId, int mid) async {
    final scope = _requireScope();
    final prefs = await SharedPreferences.getInstance();
    final messages = await _loadMessages(prefs, scope, roomId);
    for (final message in messages) {
      if (message.mid == mid) return message;
    }
    return null;
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
