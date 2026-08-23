import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../models/app_notification.dart';
import '../models/message_model.dart';
import '../models/local_message_search_result.dart';
import '../models/notification_model.dart';
import '../models/user_profile.dart';
import '../utils/talker.dart';
import '../models/settings_service.dart';
import 'api/tf_api_client.dart';
import 'app_notification_service.dart';
import 'auth_state.dart';
import 'chat_ws_service.dart';
import 'local_message_store.dart';
import 'message_sync_service.dart';

class ChatRoomPreference {
  final bool isPinned;
  final int notifyLevel;
  final String alias;
  final String description;

  const ChatRoomPreference({
    this.isPinned = false,
    this.notifyLevel = 0,
    this.alias = '',
    this.description = '',
  });

  ChatRoomPreference copyWith({
    bool? isPinned,
    int? notifyLevel,
    String? alias,
    String? description,
  }) {
    return ChatRoomPreference(
      isPinned: isPinned ?? this.isPinned,
      notifyLevel: notifyLevel ?? this.notifyLevel,
      alias: alias ?? this.alias,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isPinned': isPinned,
      'notifyLevel': notifyLevel,
      'alias': alias,
      'description': description,
    };
  }

  factory ChatRoomPreference.fromJson(Map<String, dynamic> json) {
    return ChatRoomPreference(
      isPinned: json['isPinned'] as bool? ?? false,
      notifyLevel: (json['notifyLevel'] as num?)?.toInt() ?? 0,
      alias: json['alias'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class MessageHistoryPage {
  final List<ChatMessage> messages;
  final bool hasMore;

  const MessageHistoryPage({required this.messages, required this.hasMore});
}

class ChatDataService extends ChangeNotifier {
  static ChatDataService? _instance;
  static ChatDataService get instance => _instance ??= ChatDataService._();
  ChatDataService._();

  final StreamController<({String clientMid, String error})> _ackErrorController =
      StreamController<({String clientMid, String error})>.broadcast();
  Stream<({String clientMid, String error})> get ackErrorStream =>
      _ackErrorController.stream;
  List<ChatRoom> _rooms = [];
  List<Contact> _contacts = [];
  final Map<String, List<ChatMessage>> _messageCache = {};
  final List<String> _cacheAccessOrder = [];
  final Map<String, UserProfile> _userCache = {};
  final Map<String, ChatRoomPreference> _roomPreferences = {};
  bool _isLoading = false;
  StreamSubscription? _wsSubscription;
  final LocalMessageStore _localStore = LocalMessageStore.instance;
  int? _initializedUid;
  int _generation = 0;
  int _roomListGeneration = 0;
  static const int _messagePageSize = 50;
  int? _roomPreferencesUid;
  String? _roomPreferencesScope;
  final Set<String> _fetchingGroups = {};

  /// 从设置读取消息缓存的最大会话房间数（默认 50）
  int get _maxCachedRooms =>
      SettingsService.instance.getValue<int>('maxCachedRooms', 50);

  void _touchCacheRoom(String roomId) {
    _cacheAccessOrder.remove(roomId);
    _cacheAccessOrder.add(roomId);
  }

  /// 若缓存超出上限，rm -rf 最久未访问的房间消息
  void _evictCacheIfNeeded() {
    final limit = _maxCachedRooms;
    while (_messageCache.length > limit && _cacheAccessOrder.isNotEmpty) {
      final oldest = _cacheAccessOrder.removeAt(0);
      _messageCache.remove(oldest);
      talker.info(
        'ChatDataService: evicted message cache for room $oldest (limit=$limit)',
      );
    }
  }

  List<ChatRoom> get rooms => _rooms;
  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;

  int get totalUnreadCount => _rooms.fold(0, (sum, r) => sum + r.unreadCount);

  List<ChatMessage> getMessages(String roomId) {
    if (_messageCache.containsKey(roomId)) _touchCacheRoom(roomId);
    return _messageCache[roomId] ?? [];
  }

  Future<List<ChatMessage>> getSearchableMessages(String roomId) async {
    final local = await _localStore.loadMessages(roomId);
    final merged = _mergeMessages(_messageCache[roomId] ?? [], local);
    merged.sort(_compareMessages);
    if (merged.isNotEmpty) return merged;
    return (await refreshMessagesForContact(roomId)).messages;
  }

  /// 按服务端消息 id（mid）定位消息，用于置顶消息等内容预览。
  ///
  /// 依次从内存缓存、本地库查找；仍缺失且 [allowServerFetch] 为 true 时，
  /// 从服务端 /message/history 向前翻页（有界）补拉该消息，不影响当前可见列表。
  Future<ChatMessage?> findMessageByMid(
    String roomId,
    int mid, {
    bool allowServerFetch = true,
  }) async {
    for (final m in _messageCache[roomId] ?? const <ChatMessage>[]) {
      if (m.mid == mid) return m;
    }
    final local = await _localStore.findMessageByMid(roomId, mid);
    if (local != null || !allowServerFetch) return local;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return null;
    final generation = _generation;
    final rk = roomKey(roomId);
    var beforeMid = 0;
    const maxPages = 20;
    for (var pageCount = 0; pageCount < maxPages; pageCount++) {
      if (_generation != generation || AuthState.instance.uid != uid) {
        return null;
      }
      final page = await TfApiClient.instance.queryMessageHistory(
        uid,
        password,
        rk > 0 ? rk : 0,
        groupId: rk < 0 ? -rk : null,
        beforeMid: beforeMid,
        limit: _messagePageSize,
      );
      if (page.isEmpty) return null;
      int? oldestMid;
      for (final m in page) {
        if (m.mid == mid) {
          final filled = _fillSenderInfo([m]).first;
          _ensureSenderProfiles([filled], roomId);
          await _localStore.saveMessages(roomId, [filled]);
          return filled;
        }
        if (m.mid != null && (oldestMid == null || m.mid! < oldestMid)) {
          oldestMid = m.mid;
        }
      }
      if (page.length < _messagePageSize || oldestMid == null) return null;
      beforeMid = oldestMid;
    }
    return null;
  }

  Future<List<LocalMessageSearchResult>> searchAllRoomsMessages(
    String query, {
    int limit = 200,
  }) {
    return _localStore.searchAllRooms(query, limit: limit);
  }

  void setMessages(String roomId, List<ChatMessage> msgs) {
    _messageCache[roomId] = msgs;
    _touchCacheRoom(roomId);
    _evictCacheIfNeeded();
    unawaited(_localStore.saveMessages(roomId, msgs));
    notifyListeners();
  }

  UserProfile? getUser(String roomId) => _userCache[roomId];

  UserProfile? getUserByUsername(String username) {
    final lower = username.toLowerCase();
    for (final profile in _userCache.values) {
      if (profile.username.toLowerCase() == lower) return profile;
    }
    return null;
  }

  ChatRoomPreference getRoomPreference(String roomId) {
    return _roomPreferences[roomId] ?? const ChatRoomPreference();
  }

  String displayNameForRoom(String roomId, String fallback) {
    final alias = getRoomPreference(roomId).alias.trim();
    return alias.isNotEmpty ? alias : fallback;
  }

  String roomDescription(String roomId) =>
      getRoomPreference(roomId).description;

  int roomNotifyLevel(String roomId) => getRoomPreference(roomId).notifyLevel;

  @visibleForTesting
  static bool shouldNotifyMessage({
    required int notifyLevel,
    required String message,
    required int currentUid,
    required String currentUsername,
  }) {
    if (notifyLevel == 2) return false;
    if (notifyLevel == 0) return true;
    return _containsMention(message, currentUsername) ||
        _containsMention(message, currentUid.toString());
  }

  static bool _containsMention(String message, String target) {
    if (target.isEmpty) return false;
    final escaped = RegExp.escape(target);
    return RegExp(
      '(^|\\s)@$escaped(?=\\s|\$|[.,!?，。！？:：;；])',
      caseSensitive: false,
    ).hasMatch(message);
  }

  void cacheUserProfile(UserProfile profile) {
    _userCache[profile.uid] = profile;
    final puid = int.tryParse(profile.uid);
    if (puid != null) _userCache[roomIdFromUid(puid)] = profile;
  }

  Future<void> invalidateAvatarCache({
    required int groupId,
    required Iterable<int> memberUids,
    required int version,
  }) async {
    String? versioned(String? url) {
      if (url == null || url.isEmpty) return null;
      final uri = Uri.parse(url);
      return uri
          .replace(queryParameters: {...uri.queryParameters, 'v': '$version'})
          .toString();
    }

    final memberSet = memberUids.toSet();
    final groupRoomId = 'G$groupId';
    for (final entry in _userCache.entries.toList()) {
      final profile = entry.value;
      final profileUid = int.tryParse(profile.uid.replaceFirst('U', ''));
      final isGroupProfile = entry.key == groupRoomId;
      if (!isGroupProfile &&
          (profileUid == null || !memberSet.contains(profileUid))) {
        continue;
      }
      final avatar = profile.avatar;
      final avatarBase = avatar == null
          ? null
          : Uri.parse(avatar).replace(query: null).toString();
      _userCache[entry.key] = UserProfile(
        uid: profile.uid,
        username: profile.username,
        email: profile.email,
        stat: profile.stat,
        createTime: profile.createTime,
        personalSign: profile.personalSign,
        introduction: profile.introduction,
        avatar: avatarBase,
        avatarVersion: version,
      );
    }
    final roomIndex = _rooms.indexWhere((room) => room.id == groupRoomId);
    if (roomIndex >= 0) {
      _rooms[roomIndex] = _rooms[roomIndex].copyWith(
        avatar: versioned(_rooms[roomIndex].avatar),
      );
    }
    for (var index = 0; index < _contacts.length; index++) {
      final uid = _parseUid(_contacts[index].id);
      if (uid != null && memberSet.contains(uid)) {
        _contacts[index] = Contact(
          id: _contacts[index].id,
          name: _contacts[index].name,
          avatar: versioned(_contacts[index].avatar),
        );
      }
    }
    for (final entry in _messageCache.entries) {
      var changed = false;
      final messages = entry.value.map((message) {
        if (message.senderUid != null &&
            memberSet.contains(message.senderUid) &&
            message.senderAvatar != null) {
          changed = true;
          return message.copyWith(
            senderAvatar: versioned(message.senderAvatar),
          );
        }
        return message;
      }).toList();
      if (changed) {
        _messageCache[entry.key] = messages;
        unawaited(_localStore.saveMessages(entry.key, messages));
      }
    }
    notifyListeners();
  }

  Future<void> _ensureRoomPreferencesLoaded() async {
    final uid = AuthState.instance.uid;
    if (uid == null) {
      _roomPreferences.clear();
      _roomPreferencesUid = null;
      _roomPreferencesScope = null;
      return;
    }
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    if (AuthState.instance.uid != uid) return;
    final scope = '${base64Url.encode(utf8.encode(baseUrl))}:$uid';
    if (_roomPreferencesUid == uid && _roomPreferencesScope == scope) return;

    final prefs = await SharedPreferences.getInstance();
    if (AuthState.instance.uid != uid) return;
    final raw = prefs.getString('chat_room_prefs_$scope');
    final loaded = <String, ChatRoomPreference>{};

    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in data.entries) {
          if (entry.value is Map<String, dynamic>) {
            loaded[entry.key] = ChatRoomPreference.fromJson(
              entry.value as Map<String, dynamic>,
            );
          } else if (entry.value is Map) {
            loaded[entry.key] = ChatRoomPreference.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
      } catch (e) {
        talker.error('ChatDataService load room preferences failed', e);
      }
    }
    if (AuthState.instance.uid != uid) return;
    _roomPreferences
      ..clear()
      ..addAll(loaded);
    _roomPreferencesUid = uid;
    _roomPreferencesScope = scope;
  }

  Future<void> _saveRoomPreferences() async {
    final scope = _roomPreferencesScope;
    if (scope == null) return;
    final encoded = _roomPreferences.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_room_prefs_$scope', jsonEncode(encoded));
  }

  Future<bool> updateRoomPreference(
    String roomId, {
    bool? isPinned,
    int? notifyLevel,
    String? alias,
    String? description,
  }) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final generation = _generation;
    if (uid == null) return false;
    await _ensureRoomPreferencesLoaded();
    if (_generation != generation || AuthState.instance.uid != uid) {
      return false;
    }
    final current = getRoomPreference(roomId);
    final updated = current.copyWith(
      isPinned: isPinned,
      notifyLevel: notifyLevel,
      alias: alias,
      description: description,
    );
    if (isPinned != null || notifyLevel != null) {
      if (password == null) return false;
      final saved = await TfApiClient.instance.updateChatPreference(
        uid,
        password,
        roomId,
        isPinned: isPinned,
        notifyLevel: notifyLevel,
      );
      if (!saved) return false;
      if (_generation != generation || AuthState.instance.uid != uid) {
        return false;
      }
    }
    _roomPreferences[roomId] = updated;
    await _saveRoomPreferences();

    final roomIdx = _rooms.indexWhere((room) => room.id == roomId);
    if (roomIdx >= 0) {
      final currentRoom = _rooms[roomIdx];
      final fallbackName = _userCache[roomId]?.username ?? currentRoom.name;
      _rooms[roomIdx] = currentRoom.copyWith(
        name: displayNameForRoom(roomId, fallbackName),
        isPinned: updated.isPinned,
        unreadCount: notifyLevel != null && notifyLevel != 0
            ? 0
            : currentRoom.unreadCount,
      );
    }
    final contactIdx = _contacts.indexWhere((contact) => contact.id == roomId);
    if (contactIdx >= 0) {
      final fallbackName =
          _userCache[roomId]?.username ?? _contacts[contactIdx].name;
      _contacts[contactIdx] = Contact(
        id: roomId,
        name: displayNameForRoom(roomId, fallbackName),
        avatar: _contacts[contactIdx].avatar,
      );
    }
    _sortRooms();
    notifyListeners();
    return true;
  }

  Future<void> init() async {
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    if (_initializedUid == uid && _wsSubscription != null) {
      return;
    }
    final generation = ++_generation;
    await _wsSubscription?.cancel();
    if (_generation != generation || AuthState.instance.uid != uid) return;
    _messageCache.clear();
    _cacheAccessOrder.clear();
    _userCache.clear();
    _rooms.clear();
    _contacts.clear();
    _initializedUid = uid;
    _wsSubscription = ChatWsService.instance.eventStream.listen(_onWsEvent);
    ChatWsService.instance.addListener(_onWsStateChanged);
    await loadContactsAndRooms();
    await _restoreSyncBaselines();
  }

  void _onWsStateChanged() {
    if (ChatWsService.instance.isAuthenticated) {
      unawaited(_restoreMessagesAfterReconnect());
    }
  }

  Future<void> _restoreMessagesAfterReconnect() async {
    final uid = AuthState.instance.uid;
    final generation = _generation;
    await loadContactsAndRooms();
    if (_generation != generation || AuthState.instance.uid != uid) return;
    await _restoreSyncBaselines();
  }

  /// 恢复/建立每房间同步基线（优先 seq，其次迁移的 last_mid，再退回房间列表 last_mid）。
  Future<void> _restoreSyncBaselines() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final generation = _generation;
    final syncService = MessageSyncService.instance;
    final rooms = List<ChatRoom>.from(_rooms);
    for (final room in rooms) {
      if (_generation != generation || AuthState.instance.uid != uid) return;
      final seq = await LocalMessageStore.instance.getRoomSyncSeq(room.id);
      if (seq != null && seq > 0) {
        syncService.registerRoomSeq(room.id, seq);
        continue;
      }
      final mid =
          await LocalMessageStore.instance.getRoomSyncMid(room.id) ??
          room.lastMessageMid;
      if (mid != null && mid > 0) {
        await syncService.syncRoomFromMid(room.id, mid);
      } else {
        await syncService.establishBaseline(room.id);
      }
    }
    if (_generation != generation || AuthState.instance.uid != uid) return;
    await syncService.resyncAfterReconnect(rooms.map((room) => room.id));
  }

  Future<void> reset() async {
    final generation = ++_generation;
    await _wsSubscription?.cancel();
    if (_generation != generation) return;
    _wsSubscription = null;
    ChatWsService.instance.removeListener(_onWsStateChanged);
    MessageSyncService.instance.clear();
    _initializedUid = null;
    _roomPreferencesUid = null;
    _roomPreferencesScope = null;
    _messageCache.clear();
    _cacheAccessOrder.clear();
    _userCache.clear();
    _roomPreferences.clear();
    _rooms.clear();
    _contacts.clear();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearLocalMessageDatabase() async {
    await _localStore.clearDatabase();
    _messageCache.clear();
    notifyListeners();
  }

  // --- ID helpers ---

  static String roomIdFromUid(int uid) => 'U$uid';

  static int roomKey(String roomId) {
    if (roomId.startsWith('G')) {
      return -(int.tryParse(roomId.substring(1)) ?? 0);
    }
    if (roomId.startsWith('U')) return int.tryParse(roomId.substring(1)) ?? 0;
    return int.tryParse(roomId) ?? 0;
  }

  static bool isGroupRoom(String roomId) => roomId.startsWith('G');

  String? _senderNameFor(int senderUid) {
    if (senderUid == AuthState.instance.uid) {
      return AuthState.instance.currentUser?.username;
    }
    final profile = _userCache[roomIdFromUid(senderUid)];
    return profile?.username;
  }

  String? _senderAvatarFor(int senderUid) {
    if (senderUid == AuthState.instance.uid) {
      return AuthState.instance.currentUser?.avatar;
    }
    return _userCache[roomIdFromUid(senderUid)]?.avatar;
  }

  void _sortRooms() {
    _rooms.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      final aTime = a.lastMessageTime?.millisecondsSinceEpoch ?? 0;
      final bTime = b.lastMessageTime?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
  }

  String _messageDedupKey(ChatMessage message) {
    final clientMid = message.clientMid;
    if (clientMid != null && clientMid.isNotEmpty) {
      return 'client:$clientMid';
    }
    return 'id:${message.id}';
  }

  int _compareMessages(ChatMessage a, ChatMessage b) =>
      ChatMessage.compareByOrder(a, b, _messageDedupKey);

  bool _containsMessage(List<ChatMessage> messages, ChatMessage candidate) {
    final key = _messageDedupKey(candidate);
    if (messages.any((m) => _messageDedupKey(m) == key)) return true;
    // 如果 candidate 有 mid，检查是否有消息的 mid 与之匹配
    final candidateMid = candidate.mid;
    if (candidateMid != null) {
      return messages.any((m) => m.mid == candidateMid);
    }
    return false;
  }

  int? _indexOfMessage(List<ChatMessage> messages, ChatMessage candidate) {
    final key = _messageDedupKey(candidate);
    for (var i = 0; i < messages.length; i++) {
      if (_messageDedupKey(messages[i]) == key) return i;
    }
    final candidateMid = candidate.mid;
    if (candidateMid != null) {
      for (var i = 0; i < messages.length; i++) {
        if (messages[i].mid == candidateMid) return i;
      }
    }
    return null;
  }

  /// 服务端回声（MESSAGE.NEW 推回给自己）/补拉命中本地待确认消息时，
  /// 采用服务端身份字段，让已确认消息获得服务端序号与发送时间，
  /// 后续实时消息即可按服务端序号正确排序（不再依赖设备时钟）。
  ChatMessage _adoptServerFields(ChatMessage existing, ChatMessage incoming) {
    final serverMid = incoming.mid;
    final serverSeq = incoming.roomSeq;
    final isPending = existing.mid == null && existing.roomSeq == null;
    if (isPending && serverMid != null && serverSeq != null) {
      final incomingTime = incoming.timestamp;
      return existing.copyWith(
        id: serverMid.toString(),
        mid: serverMid,
        roomSeq: serverSeq,
        timestamp: incomingTime.millisecondsSinceEpoch > 0
            ? incomingTime
            : existing.timestamp,
      );
    }
    if (serverMid != null && existing.mid == null) {
      return existing.copyWith(id: serverMid.toString(), mid: serverMid);
    }
    if (serverSeq != null && serverSeq != existing.roomSeq) {
      return existing.copyWith(roomSeq: serverSeq);
    }
    return existing;
  }

  // --- Room/Contact list ---

  Future<void> loadContactsAndRooms() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      talker.warning(
        'ChatDataService.loadContactsAndRooms: skipped (uid=$uid, hasPassword=${password != null})',
      );
      return;
    }
    final generation = _generation;
    final roomListGeneration = ++_roomListGeneration;

    _isLoading = true;
    notifyListeners();

    try {
      await _ensureRoomPreferencesLoaded();
      if (_generation != generation ||
          _roomListGeneration != roomListGeneration ||
          AuthState.instance.uid != uid) {
        return;
      }
      talker.info(
        'ChatDataService.loadContactsAndRooms: calling /chat/list for uid=$uid',
      );
      final chatItems = await TfApiClient.instance.queryChatList(uid, password);
      if (_generation != generation ||
          _roomListGeneration != roomListGeneration ||
          AuthState.instance.uid != uid) {
        return;
      }
      talker.info(
        'ChatDataService.loadContactsAndRooms: got ${chatItems.length} items from server',
      );
      final baseUrl = await TfApiClient.instance.getBaseUrl();
      if (_generation != generation ||
          _roomListGeneration != roomListGeneration ||
          AuthState.instance.uid != uid) {
        return;
      }

      // 在 await（queryChatList/getBaseUrl）之后构建房间映射：
      // await 期间轮询恢复的历史消息会实时累计未读（_addToCacheSilent），
      // 若在 await 前取快照，重建列表时会把这些未读清零。
      final existingRooms = {for (final room in _rooms) room.id: room};
      final nextRooms = <ChatRoom>[];
      final nextContacts = <Contact>[];

      for (final item in chatItems) {
        // 过滤
        if (item.partnerUid == uid) continue;
        if (item.partnerUid < 0 && item.roomType != 'group') continue;
        final isGroup = item.roomType == 'group';
        final existingRoom = existingRooms[item.roomId];
        if (item.isPinned != null || item.notifyLevel != null) {
          final currentPreference = getRoomPreference(item.roomId);
          _roomPreferences[item.roomId] = currentPreference.copyWith(
            isPinned: item.isPinned,
            notifyLevel: item.notifyLevel,
          );
        }
        final lastTime = item.lastTime != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (item.lastTime! * 1000).toInt(),
              )
            : null;
        final avatarUrl = item.avatar != null ? '$baseUrl${item.avatar}' : null;

        _userCache[item.roomId] = UserProfile(
          uid: item.roomId,
          username: item.username,
          email: '',
          stat: 'user',
          createTime: '0',
          avatar: avatarUrl,
        );
        final displayName = displayNameForRoom(item.roomId, item.username);
        if (!isGroup && item.isFriend) {
          nextContacts.add(
            Contact(id: item.roomId, name: displayName, avatar: avatarUrl),
          );
        }

        nextRooms.add(
          ChatRoom(
            id: item.roomId,
            name: displayName,
            avatar: avatarUrl,
            type: isGroup ? ChatType.group : ChatType.direct,
            lastMessage: item.lastDeleted
                ? ''
                : item.visibleLastContent ?? existingRoom?.lastMessage,
            lastMessageTime: lastTime ?? existingRoom?.lastMessageTime,
            lastMessageMid: item.lastMid,
            unreadCount: existingRoom?.unreadCount ?? 0,
            isPinned: getRoomPreference(item.roomId).isPinned,
          ),
        );
      }

      _rooms = nextRooms;
      _contacts = nextContacts;
      await _saveRoomPreferences();
      _sortRooms();
      talker.info(
        'ChatDataService.loadContactsAndRooms: loaded ${_rooms.length} rooms, ${_contacts.length} contacts',
      );
    } catch (e) {
      talker.error('ChatDataService loadContactsAndRooms error', e);
    } finally {
      if (_generation == generation &&
          _roomListGeneration == roomListGeneration &&
          AuthState.instance.uid == uid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _onMessageAck(
    String clientMid, {
    int? serverMid,
    int? roomSeq,
    required MessageStatus status,
    String? error,
  }) {
    for (final roomId in _messageCache.keys) {
      final msgs = _messageCache[roomId]!;
      final idx = msgs.indexWhere((m) => m.clientMid == clientMid);
      if (idx != -1) {
        final existing = msgs[idx];
        final updated = List<ChatMessage>.from(msgs, growable: true);
        updated[idx] = existing.copyWith(
          id: serverMid?.toString() ?? existing.id,
          mid: serverMid ?? existing.mid,
          roomSeq: roomSeq ?? existing.roomSeq,
          status: status,
          ackError: error,
          clearAckError: error == null,
        );
        if (roomSeq != null && roomSeq != existing.roomSeq) {
          updated.sort(_compareMessages);
        }
        _messageCache[roomId] = updated;
        _localStore.saveMessages(roomId, updated);
        if (idx == updated.length - 1 && serverMid != null) {
          final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
          if (roomIndex >= 0) {
            _rooms[roomIndex] = _rooms[roomIndex].copyWith(
              lastMessageMid: serverMid,
            );
          }
        }
        if (status == MessageStatus.failed && error != null) {
          _ackErrorController.add((clientMid: clientMid, error: error));
        }
        notifyListeners();
        return;
      }
    }
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> server,
    List<ChatMessage> local,
  ) {
    final seen = <String>{};
    var result = <ChatMessage>[];
    for (final m in [...server, ...local]) {
      if (seen.add(_messageDedupKey(m))) result.add(m);
    }
    for (final recalled in result.where((message) => message.isDeleted)) {
      final mid = recalled.mid;
      if (mid != null) result = applyRecallToMessages(result, mid);
    }
    return result;
  }

  // --- Real-time events ---

  void _onWsEvent(ChatWsEvent event) {
    if (event.type == 'message.ack') {
      final data = event.notification;
      if (data != null) {
        final mid = (data['mid'] as num?)?.toInt();
        final clientMid = data['client_mid'] as String?;
        final roomSeq = (data['room_seq'] as num?)?.toInt();
        final rawStatus = data['status'] as String? ?? 'sent';
        final status = rawStatus == 'failed'
            ? MessageStatus.failed
            : MessageStatus.sent;
        final error = data['error'] as String?;
        if (clientMid != null) {
          _onMessageAck(
            clientMid,
            serverMid: mid,
            roomSeq: roomSeq,
            status: status,
            error: error,
          );
        }
      }
      return;
    }

    if (event.type == 'MESSAGE.RECALLED') {
      final data = event.notification;
      final mid =
          (data?['mid'] as num?)?.toInt() ??
          (data?['recalled_mid'] as num?)?.toInt();
      if (mid != null) {
        markMessageRecalled(
          mid,
          deletedAt: _notificationDateTime(data?['deleted_at']),
          deletedBy: (data?['deleted_by'] as num?)?.toInt(),
        );
      }
      return;
    }

    if (event.type == 'MESSAGE.NEW') {
      final data = event.notification;
      if (data == null) return;
      final uid = AuthState.instance.uid;
      if (uid == null) return;
      final info = NotificationInfo.fromServerMessageInfo(data);
      final eventType = info.event;

      if (eventType == 'message.recalled' || eventType == 'message.recall') {
        final mid = info.recalledMid;
        if (mid != null) {
          markMessageRecalled(
            mid,
            deletedAt: info.deletedAt,
            deletedBy: info.deletedBy,
          );
        }
        return;
      }

      if (eventType != 'message.plain' && eventType != 'message.file') {
        return;
      }

      final senderUid = info.senderUid;
      if (senderUid == null) return;
      if (senderUid == uid && info.groupId == null && info.roomId == null) {
        return;
      }

      final roomId = _roomIdForNotification(info, uid);
      final msg = ChatMessage.fromServerMessage(
        data,
        myUid: uid,
        senderName: _senderNameFor(senderUid),
        senderAvatar: _senderAvatarFor(senderUid),
      );
      MessageSyncService.instance.observeMessage(roomId, msg);
      _addToCache(roomId, msg);
      return;
    }

    if (event.type != 'NOTIFICATION.NEW' || event.notification == null) return;

    final info = NotificationInfo.fromServerJson(event.notification!);
    final eventType = info.event;

    if (eventType == 'friend.accepted') {
      final suid = info.senderUid;
      if (suid != null) addFriendToContacts(suid);
      return;
    }
    if (eventType == 'friend.request' ||
        eventType == 'group.invited' ||
        eventType == 'group.join.approved' ||
        eventType == 'group.left' ||
        eventType == 'group.member.removed' ||
        eventType == 'group.deleted') {
      final gid = info.groupEventGid;
      if (gid != null &&
          (eventType == 'group.left' ||
              eventType == 'group.member.removed' ||
              eventType == 'group.deleted')) {
        unawaited(removeRoom('G$gid'));
      } else if (gid != null) {
        unawaited(ensureGroupInfo(gid));
      }
      loadContactsAndRooms();
      return;
    }
    if (eventType == 'messages.pinned' || eventType == 'messages.unpinned') {
      notifyListeners();
      return;
    }
  }

  /// 处理 /message/sync 补拉到的消息（静默合并：不发横幅、只累计未读角标）。
  void processSyncedMessages(
    String roomId,
    List<ChatMessage> messages, {
    bool isHistorical = false,
  }) {
    if (messages.isEmpty) return;
    for (final msg in messages) {
      if (msg.isDeleted) {
        if (msg.mid != null) {
          markMessageRecalled(
            msg.mid!,
            roomId: roomId,
            deletedAt: msg.deletedAt,
            deletedBy: msg.deletedBy,
          );
        }
        continue;
      }
      _addToCacheSilent(roomId, msg, countUnread: !isHistorical);
    }
    _ensureSenderProfiles(messages, roomId);
    notifyListeners();
  }

  void _addToCacheSilent(
    String roomId,
    ChatMessage msg, {
    bool countUnread = true,
  }) {
    final cached = _messageCache[roomId] ?? [];
    final matchIdx = _indexOfMessage(cached, msg);
    if (matchIdx == null) {
      cached.add(msg);
      cached.sort(_compareMessages);
      _messageCache[roomId] = cached;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
      _localStore.appendMessage(roomId, msg);
    } else {
      final upgraded = _adoptServerFields(cached[matchIdx], msg);
      if (!identical(upgraded, cached[matchIdx])) {
        final updated = List<ChatMessage>.from(cached);
        updated[matchIdx] = upgraded;
        updated.sort(_compareMessages);
        _messageCache[roomId] = updated;
        _touchCacheRoom(roomId);
        _evictCacheIfNeeded();
        _localStore.saveMessages(roomId, updated);
      }
    }

    // 历史恢复的消息同样参照 _addToCache 的通知判定累计未读角标，
    // 这样在另一平台离线期间的私聊/群聊消息会在聊天列表右侧
    // 显示红色数字角标，而不是弹横幅轰炸。
    // 消息已存在（例如轮询与 WS 同时收到同一消息）时不重复累计，
    // 但始终更新房间的最后一条消息。
    final uid = AuthState.instance.uid;
    final username = AuthState.instance.currentUser?.username ?? '';
    final shouldCountUnread =
        countUnread &&
        !msg.isMe &&
        matchIdx == null &&
        (msg.shouldAlert ??
            (uid != null &&
                shouldNotifyMessage(
                  notifyLevel: roomNotifyLevel(roomId),
                  message: msg.text,
                  currentUid: uid,
                  currentUsername: username,
                )));

    if (!_rooms.any((r) => r.id == roomId)) {
      _addNewRoom(roomId, msg, unreadCount: shouldCountUnread ? 1 : 0);
    } else {
      final idx = _rooms.indexWhere((r) => r.id == roomId);
      final lastTime = _rooms[idx].lastMessageTime;
      var updated = _rooms[idx];
      if (lastTime == null || msg.timestamp.isAfter(lastTime)) {
        updated = updated.copyWith(
          lastMessage: msg.text,
          lastMessageTime: msg.timestamp,
          lastMessageMid: msg.mid,
        );
      }
      if (shouldCountUnread) {
        updated = updated.copyWith(unreadCount: updated.unreadCount + 1);
      }
      _rooms[idx] = updated;
    }
    unawaited(_ensureGroupInfo(roomId));
    _sortRooms();
    notifyListeners();
  }

  String _roomIdForNotification(NotificationInfo info, int myUid) {
    if (info.roomId != null && info.roomId!.isNotEmpty) return info.roomId!;
    if (info.groupId != null) return 'G${info.groupId}';
    return roomIdFromUid(info.senderUid ?? myUid);
  }

  void _addToCache(String roomId, ChatMessage msg) {
    final cached = _messageCache[roomId] ?? [];
    final matchIdx = _indexOfMessage(cached, msg);
    if (matchIdx == null) {
      cached.add(msg);
      cached.sort(_compareMessages);
      _messageCache[roomId] = cached;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
      _localStore.appendMessage(roomId, msg);
    } else {
      final upgraded = _adoptServerFields(cached[matchIdx], msg);
      if (!identical(upgraded, cached[matchIdx])) {
        final updated = List<ChatMessage>.from(cached);
        updated[matchIdx] = upgraded;
        updated.sort(_compareMessages);
        _messageCache[roomId] = updated;
        _touchCacheRoom(roomId);
        _evictCacheIfNeeded();
        _localStore.saveMessages(roomId, updated);
        notifyListeners();
      }
      return;
    }

    if (!msg.isMe && msg.senderAvatar == null && msg.senderUid != null) {
      _fetchProfileForRoom(
        roomIdFromUid(msg.senderUid!),
        messageRoomId: roomId,
      );
    }

    final uid = AuthState.instance.uid;
    final username = AuthState.instance.currentUser?.username ?? '';
    final shouldNotify =
        !msg.isMe &&
        (msg.shouldAlert ??
            (uid != null &&
                shouldNotifyMessage(
                  notifyLevel: roomNotifyLevel(roomId),
                  message: msg.text,
                  currentUid: uid,
                  currentUsername: username,
                )));

    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx >= 0) {
      _rooms[idx] = _rooms[idx].copyWith(
        lastMessage: msg.text,
        lastMessageTime: msg.timestamp,
        lastMessageMid: msg.mid,
        unreadCount: shouldNotify
            ? _rooms[idx].unreadCount + 1
            : _rooms[idx].unreadCount,
      );
    } else {
      _addNewRoom(roomId, msg, unreadCount: shouldNotify ? 1 : 0);
    }
    unawaited(_ensureGroupInfo(roomId));
    _sortRooms();
    notifyListeners();
    if (shouldNotify && _shouldSendNotification(roomId)) {
      final room = _rooms.firstWhere((room) => room.id == roomId);
      unawaited(
        AppNotificationService.instance.present(
          AppNotification(
            id: '$roomId:${msg.id}',
            title: room.name,
            body: msg.text,
            avatarUrl: msg.senderAvatar ?? room.avatar,
            route: '/chat/$roomId',
            topic: isGroupRoom(roomId)
                ? 'message.group'
                : 'message.private',
            senderKey: roomId,
            roomId: roomId,
          ),
        ),
      );
    }
  }

  bool _shouldSendNotification(String roomId) {
    final settings = SettingsService.instance;
    return isGroupRoom(roomId)
        ? settings.getValue<bool>('groupChat', true)
        : settings.getValue<bool>('privateChat', true);
  }

  void _addNewRoom(String roomId, ChatMessage msg, {int unreadCount = 1}) {
    if (!isGroupRoom(roomId) && _userCache[roomId] == null) {
      final puid = _parseUid(roomId);
      if (puid != null) _fetchProfileForRoom(roomId);
    }
    _rooms.insert(
      0,
      ChatRoom(
        id: roomId,
        name: displayNameForRoom(
          roomId,
          _userCache[roomId]?.username ??
              (isGroupRoom(roomId)
                  ? 'Group ${roomId.substring(1)}'
                  : 'User ${roomId.substring(1)}'),
        ),
        avatar: _userCache[roomId]?.avatar,
        type: isGroupRoom(roomId) ? ChatType.group : ChatType.direct,
        lastMessage: msg.text,
        lastMessageTime: msg.timestamp,
        lastMessageMid: msg.mid,
        unreadCount: unreadCount,
        isPinned: getRoomPreference(roomId).isPinned,
      ),
    );
  }

  int? _parseUid(String roomId) {
    if (roomId.startsWith('U')) return int.tryParse(roomId.substring(1));
    if (roomId.startsWith('G')) return int.tryParse(roomId.substring(1));
    return int.tryParse(roomId);
  }

  static DateTime? _notificationDateTime(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final number = value.toDouble();
      return DateTime.fromMillisecondsSinceEpoch(
        (number > 100000000000 ? number : number * 1000).toInt(),
      );
    }
    return DateTime.tryParse(value.toString());
  }

  void _fetchProfileForRoom(String roomId, {String? messageRoomId}) {
    if (_userCache[roomId] != null) return;
    final puid = _parseUid(roomId);
    if (puid == null) return;
    final generation = _generation;
    final uid = AuthState.instance.uid;
    TfApiClient.instance.getUserByUid(puid).then((profile) {
      if (profile == null ||
          _generation != generation ||
          AuthState.instance.uid != uid) {
        return;
      }
      _userCache[profile.uid] = profile;
      // profile.uid 是 "U{uid}" 格式，但是之前有问题
      _userCache[roomIdFromUid(puid)] = profile;
      _updateRoomAndContacts(roomId, profile.username, profile.avatar);
      _fillMsgAvatars(
        messageRoomId ?? roomId,
        puid,
        profile.username,
        profile.avatar,
      );
      notifyListeners();
    });
  }

  /// 为群聊房间补拉群资料（名称/头像）。
  Future<void> ensureGroupInfo(int gid) =>
      _ensureGroupInfo('G$gid');

  Future<void> _ensureGroupInfo(String roomId) async {
    if (!isGroupRoom(roomId)) return;
    final cachedName = _userCache[roomId]?.username;
    if (cachedName != null && cachedName.isNotEmpty) return;
    final gid = _parseUid(roomId);
    if (gid == null) return;
    if (!_fetchingGroups.add(roomId)) return;

    final generation = _generation;
    final uid = AuthState.instance.uid;
    try {
      final groups = await TfApiClient.instance.infoGroup(gid);
      if (groups.isEmpty ||
          _generation != generation ||
          AuthState.instance.uid != uid) {
        return;
      }
      final groupName = (groups.first['groupname'] as String?) ?? '';
      if (groupName.isEmpty) return;
      final baseUrl = await TfApiClient.instance.getBaseUrl();
      if (_generation != generation || AuthState.instance.uid != uid) return;
      final avatarUrl = '$baseUrl/avatar/get_avatar/group/$gid';
      _userCache[roomId] = UserProfile(
        uid: roomId,
        username: groupName,
        email: '',
        stat: 'group',
        createTime: '0',
        avatar: avatarUrl,
      );
      _updateRoomAndContacts(roomId, groupName, avatarUrl);
      notifyListeners();
    } catch (e, stack) {
      talker.error('ChatDataService fetch group info failed for $roomId', e, stack);
    } finally {
      _fetchingGroups.remove(roomId);
    }
  }

  /// 为一批消息中尚未缓存的发送者逐个抓取资料。
  ///
  /// 群聊历史/同步加载的消息发送者不在 /chat/list 的直接联系人里时，
  /// _userCache 中并无其资料，导致昵称回退显示为 "User X"（见 _fillSenderInfo）。
  /// 这里主动调用 _fetchProfileForRoom 补齐，资料返回后由 _fillMsgAvatars
  /// 就地更新 [messageRoomId] 对应房间缓存里的消息昵称/头像。
  void _ensureSenderProfiles(List<ChatMessage> messages, String roomId) {
    final myUid = AuthState.instance.uid;
    if (myUid == null) return;
    final seen = <int>{};
    for (final message in messages) {
      final senderUid = message.senderUid;
      if (senderUid == null ||
          senderUid == myUid ||
          senderUid == 0 ||
          message.isMe ||
          !seen.add(senderUid)) {
        continue;
      }
      final senderRoomId = roomIdFromUid(senderUid);
      if (_userCache[senderRoomId] != null) continue;
      _fetchProfileForRoom(senderRoomId, messageRoomId: roomId);
    }
  }

  void _updateRoomAndContacts(String roomId, String? username, String? avatar) {
    final displayName = displayNameForRoom(roomId, username ?? '');
    final rIdx = _rooms.indexWhere((r) => r.id == roomId);
    if (rIdx >= 0) {
      _rooms[rIdx] = _rooms[rIdx].copyWith(name: displayName, avatar: avatar);
    }
    final cIdx = _contacts.indexWhere((c) => c.id == roomId);
    if (cIdx >= 0) {
      _contacts[cIdx] = Contact(id: roomId, name: displayName, avatar: avatar);
    }
  }

  void _fillMsgAvatars(
    String roomId,
    int senderUid,
    String? username,
    String? avatar,
  ) {
    final msgs = _messageCache[roomId];
    if (msgs == null) return;
    var changed = false;
    final updated = msgs.map((m) {
      var next = m;
      if (!next.isMe &&
          next.senderUid == senderUid &&
          next.senderAvatar == null) {
        changed = true;
        next = next.copyWith(senderName: username, senderAvatar: avatar);
      }
      final quote = next.quotePreview;
      if (quote?.senderUid == senderUid && quote?.senderName == null) {
        changed = true;
        next = next.copyWith(
          quotePreview: quote!.copyWith(senderName: username),
        );
      }
      final forwarded = next.forwardPreview;
      if (forwarded?.senderUid == senderUid && forwarded?.senderName == null) {
        changed = true;
        next = next.copyWith(
          forwardPreview: forwarded!.copyWith(senderName: username),
        );
      }
      return next;
    }).toList();
    if (changed) {
      _messageCache[roomId] = updated;
      _localStore.saveMessages(roomId, updated);
    }
  }

  void addSentMessage(String roomId, ChatMessage msg) {
    final cached = _messageCache[roomId] ?? [];
    if (!_containsMessage(cached, msg)) {
      cached.add(msg);
      cached.sort(_compareMessages);
      _messageCache[roomId] = cached;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
      _localStore.appendMessage(roomId, msg);
    }

    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx >= 0) {
      _rooms[idx] = _rooms[idx].copyWith(
        lastMessage: msg.text,
        lastMessageTime: msg.timestamp,
      );
    } else {
      _addNewRoom(roomId, msg, unreadCount: 0);
      if (!isGroupRoom(roomId) && !_contacts.any((c) => c.id == roomId)) {
        final profile = _userCache[roomId];
        _contacts.add(
          Contact(
            id: roomId,
            name: displayNameForRoom(roomId, profile?.username ?? ''),
            avatar: profile?.avatar,
          ),
        );
      }
    }
    unawaited(_ensureGroupInfo(roomId));
    _sortRooms();
    notifyListeners();
  }

  void markMessageRecalled(
    int mid, {
    String? roomId,
    DateTime? deletedAt,
    int? deletedBy,
  }) {
    _forgetRecalledSeqFromSync(mid);
    var changed = false;
    var cachedTargetFound = false;
    for (final id in _messageCache.keys.toList()) {
      final messages = _messageCache[id];
      if (messages == null) continue;
      if (messages.any((message) => message.mid == mid)) {
        cachedTargetFound = true;
      }
      final updated = applyRecallToMessages(
        messages,
        mid,
        deletedAt: deletedAt,
        deletedBy: deletedBy,
      );
      final latestIsRecalled = updated.isNotEmpty && updated.last.mid == mid;
      final roomIndex = _rooms.indexWhere((room) => room.id == id);
      if (roomIndex >= 0 &&
          (latestIsRecalled || _rooms[roomIndex].lastMessageMid == mid)) {
        _rooms[roomIndex] = _rooms[roomIndex].copyWith(lastMessage: '');
        changed = true;
      }
      if (identical(updated, messages)) continue;
      _messageCache[id] = updated;
      unawaited(_localStore.saveMessages(id, updated));
      changed = true;
    }
    if (roomId != null && !cachedTargetFound) {
      unawaited(_persistRecallToLocalStore(roomId, mid, deletedAt, deletedBy));
    }
    if (roomId != null) {
      final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
      if (roomIndex >= 0 && _rooms[roomIndex].lastMessageMid == mid) {
        _rooms[roomIndex] = _rooms[roomIndex].copyWith(lastMessage: '');
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// 被撤回消息的原位 seq 被吃了，就不要 retry 了
  void _forgetRecalledSeqFromSync(int mid) {
    for (final entry in _messageCache.entries) {
      for (final message in entry.value) {
        if (message.mid == mid && message.roomSeq != null) {
          MessageSyncService.instance.forgetMissingSeq(
            entry.key,
            message.roomSeq!,
          );
          return;
        }
      }
    }
  }

  Future<void> _persistRecallToLocalStore(
    String roomId,
    int mid,
    DateTime? deletedAt,
    int? deletedBy,
  ) async {
    try {
      final messages = await _localStore.loadMessages(roomId);
      final updated = applyRecallToMessages(
        messages,
        mid,
        deletedAt: deletedAt,
        deletedBy: deletedBy,
      );
      if (!identical(updated, messages)) {
        await _localStore.saveMessages(roomId, updated);
      }
    } catch (e, stack) {
      talker.error(
        'ChatDataService persist recall failed for $roomId',
        e,
        stack,
      );
    }
  }

  static List<ChatMessage> applyRecallToMessages(
    List<ChatMessage> messages,
    int mid, {
    DateTime? deletedAt,
    int? deletedBy,
  }) {
    var changed = false;
    final updated = messages.map((message) {
      var next = message;
      if (message.mid == mid && !message.isDeleted) {
        next = message.asTombstone(at: deletedAt, by: deletedBy);
        changed = true;
      }
      final quote = next.quotePreview;
      if (quote?.mid == mid &&
          (!quote!.isDeleted ||
              quote.content.isNotEmpty ||
              quote.contentType != 'plain')) {
        next = next.copyWith(quotePreview: quote.asRecalled());
        changed = true;
      }
      return next;
    }).toList();
    return changed ? updated : messages;
  }

  void clearUnread(String roomId) {
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx >= 0 && _rooms[idx].unreadCount > 0) {
      _rooms[idx] = _rooms[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  Future<void> removeRoom(String roomId) async {
    _roomListGeneration++;
    _rooms.removeWhere((room) => room.id == roomId);
    _contacts.removeWhere((contact) => contact.id == roomId);
    _messageCache.remove(roomId);
    _cacheAccessOrder.remove(roomId);
    _userCache.remove(roomId);
    _roomPreferences.remove(roomId);
    await _saveRoomPreferences();
    await _localStore.deleteRoom(roomId);
    notifyListeners();
  }

  // --- Message history ---

  Future<MessageHistoryPage> refreshMessagesForContact(String roomId) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      return const MessageHistoryPage(messages: [], hasMore: false);
    }
    final generation = _generation;

    final rk = roomKey(roomId);
    final serverMsgs = await TfApiClient.instance.queryMessageHistory(
      uid,
      password,
      rk > 0 ? rk : 0,
      groupId: rk < 0 ? -rk : null,
      limit: _messagePageSize,
    );
    if (_generation != generation || AuthState.instance.uid != uid) {
      return const MessageHistoryPage(messages: [], hasMore: false);
    }

    final serverFilled = _fillSenderInfo(serverMsgs);
    final localMsgs = await _localStore.loadMessages(
      roomId,
      limit: _messagePageSize,
    );
    if (_generation != generation || AuthState.instance.uid != uid) {
      return const MessageHistoryPage(messages: [], hasMore: false);
    }
    final merged = _mergeMessages(serverFilled, localMsgs);
    merged.sort(_compareMessages);
    final visible = merged.length <= _messagePageSize
        ? merged
        : merged.sublist(merged.length - _messagePageSize);

    if (visible.isNotEmpty || !_messageCache.containsKey(roomId)) {
      _messageCache[roomId] = visible;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
    }
    _ensureSenderProfiles(visible, roomId);
    await _localStore.saveMessages(roomId, serverFilled);
    notifyListeners();
    return MessageHistoryPage(
      messages: visible,
      hasMore:
          serverMsgs.length == _messagePageSize ||
          localMsgs.length == _messagePageSize,
    );
  }

  Future<MessageHistoryPage> loadOlderMessages(String roomId) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      return const MessageHistoryPage(messages: [], hasMore: false);
    }
    final generation = _generation;

    final cached = _messageCache[roomId] ?? [];
    if (cached.isEmpty) {
      return const MessageHistoryPage(messages: [], hasMore: false);
    }

    int? oldestMid;
    for (final m in cached) {
      if (m.mid != null && (oldestMid == null || m.mid! < oldestMid)) {
        oldestMid = m.mid;
      }
    }
    final localMsgs = await _localStore.loadMessages(
      roomId,
      limit: _messagePageSize,
      before: cached.first,
    );
    if (_generation != generation || AuthState.instance.uid != uid) {
      return const MessageHistoryPage(messages: [], hasMore: false);
    }

    final rk = roomKey(roomId);
    final olderMsgs = oldestMid == null
        ? <ChatMessage>[]
        : await TfApiClient.instance.queryMessageHistory(
            uid,
            password,
            rk > 0 ? rk : 0,
            groupId: rk < 0 ? -rk : null,
            beforeMid: oldestMid,
            limit: _messagePageSize,
          );
    if (_generation != generation || AuthState.instance.uid != uid) {
      return const MessageHistoryPage(messages: [], hasMore: false);
    }

    final olderFilled = _fillSenderInfo(olderMsgs);
    final merged = _mergeMessages(olderFilled, [...localMsgs, ...cached]);
    merged.sort(_compareMessages);

    _messageCache[roomId] = merged;
    _touchCacheRoom(roomId);
    await _localStore.saveMessages(roomId, olderFilled);
    _ensureSenderProfiles(olderFilled, roomId);
    if (merged.length != cached.length) notifyListeners();
    return MessageHistoryPage(
      messages: merged,
      hasMore:
          olderMsgs.length == _messagePageSize ||
          localMsgs.length == _messagePageSize,
    );
  }

  List<ChatMessage> _fillSenderInfo(List<ChatMessage> msgs) {
    return msgs.map((m) {
      var next = m;
      if (next.senderUid != null) {
        final suid = next.senderUid!;
        next = next.copyWith(
          senderName: next.senderName ?? _senderNameFor(suid),
          senderAvatar: next.senderAvatar ?? _senderAvatarFor(suid),
        );
      }
      final quote = next.quotePreview;
      if (quote?.senderName == null && quote?.senderUid != null) {
        final name = _senderNameFor(quote!.senderUid!);
        if (name != null) {
          next = next.copyWith(quotePreview: quote.copyWith(senderName: name));
        }
      }
      final forwarded = next.forwardPreview;
      if (forwarded?.senderName == null && forwarded?.senderUid != null) {
        final name = _senderNameFor(forwarded!.senderUid!);
        if (name != null) {
          next = next.copyWith(
            forwardPreview: forwarded.copyWith(senderName: name),
          );
        }
      }
      return next;
    }).toList();
  }

  Future<void> addFriendToContacts(int friendUid) async {
    final uid = AuthState.instance.uid;
    final generation = _generation;
    if (uid == null) return;
    // 不把自己加入联系人列表
    if (friendUid == uid) return;
    final roomId = roomIdFromUid(friendUid);
    if (_contacts.any((c) => c.id == roomId) &&
        _rooms.any((r) => r.id == roomId)) {
      return;
    }

    final profile = await TfApiClient.instance.getUserByUid(friendUid);
    if (_generation != generation || AuthState.instance.uid != uid) return;
    final baseName = profile?.username ?? 'User $friendUid';
    final name = displayNameForRoom(roomId, baseName);
    final avatar = profile?.avatar;

    if (profile != null) {
      _userCache[profile.uid] = profile;
      _userCache[roomId] = profile;
    }
    if (!_contacts.any((c) => c.id == roomId)) {
      _contacts.add(Contact(id: roomId, name: name, avatar: avatar));
    }
    if (!_rooms.any((r) => r.id == roomId)) {
      _rooms.insert(
        0,
        ChatRoom(
          id: roomId,
          name: name,
          avatar: avatar,
          type: ChatType.direct,
          unreadCount: 0,
          isPinned: getRoomPreference(roomId).isPinned,
        ),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _ackErrorController.close();
    super.dispose();
  }
}
