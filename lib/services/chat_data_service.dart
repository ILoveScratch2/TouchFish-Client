import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../models/app_notification.dart';
import '../models/message_model.dart';
import '../models/room_message_history.dart';
import '../models/search_result.dart';
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

  bool _deferredNotifyScheduled = false;
  @override
  void notifyListeners() {
    final phase = _safeSchedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      if (_deferredNotifyScheduled) return;
      _deferredNotifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _deferredNotifyScheduled = false;
        super.notifyListeners();
      });
      return;
    }
    super.notifyListeners();
  }

  static SchedulerPhase? get _safeSchedulerPhase {
    try {
      return SchedulerBinding.instance.schedulerPhase;
    } on FlutterError {
      return null;
    }
  }

  final StreamController<({String clientMid, String error})>
  _ackErrorController =
      StreamController<({String clientMid, String error})>.broadcast();
  Stream<({String clientMid, String error})> get ackErrorStream =>
      _ackErrorController.stream;
  List<ChatRoom> _rooms = [];
  List<Contact> _contacts = [];

  /// 新增写入路径必须同时满足：有序 可增长
  /// we need DS(data structure)(not dpsk)
  final Map<String, RoomMessageHistory> _messageCache = {};
  final _cacheAccessOrder = <String>{};
  final _activeHistoryReads = <String, Object>{};
  final Map<String, UserProfile> _userCache = {};
  final Map<String, ChatRoomPreference> _roomPreferences = {};
  final Map<String, Future<void>> _roomPreferenceWrites = {};
  bool _isLoading = false;
  StreamSubscription? _wsSubscription;
  final LocalMessageStore _localStore = LocalMessageStore.instance;
  int? _initializedUid;
  int _generation = 0;
  int _roomListGeneration = 0;
  static const int _messagePageSize = 50;
  /// 服务端搜索单页条数（服务端上限 20）
  static const int _messageSearchPageSize = 20;
  int? _roomPreferencesUid;
  String? _roomPreferencesScope;
  String? _roomPreferencesEncoded;
  // clientMid 房间
  final Map<String, String> _pendingClientMidRooms = {};
  final Set<String> _fetchingGroups = {};
  final Set<String> _fetchingUsers = {};

  // 分房间通知回调(河流pod)
  final Map<String, List<VoidCallback>> _roomListeners = {};
  bool _batchRoomNotify = false;
  final Set<String> _batchedRoomNotifyQueue = {};

  bool _batchIngest = false;
  final Map<String, Map<String, ChatMessage>> _pendingIngest = {};

  // 追加式索引
  // 仅作候选集提示
  final Map<int, String> _midToRoom = {};
  final Map<String, Set<String>> _hashToRooms = {};

  // 服务端未读
  final Map<String, int> _unreadRebaseSeq = {};

  // 已读回执
  // 私聊对方已读roomId peer last_read_seq 
  // 群聊按消息 mid 记录已读人数
  final Map<String, int> _peerReadSeq = {};
  final Map<int, int> _groupReadCounts = {};

  static const int _groupReadCountCap = 500;

  final messageCacheResetRevision = ValueNotifier<int>(0);

  final ValueNotifier<int> readReceiptRevision = ValueNotifier<int>(0);

  void _bumpReadReceiptRevision() => readReceiptRevision.value++;

  int get _maxCachedRooms =>
      SettingsService.instance.getValue<int>('maxCachedRooms', 50);

  void addRoomListener(String roomId, VoidCallback listener) {
    _roomListeners.putIfAbsent(roomId, () => []).add(listener);
  }

  void removeRoomListener(String roomId, VoidCallback listener) {
    _roomListeners[roomId]?.remove(listener);
    if (_roomListeners[roomId]?.isEmpty ?? false) {
      _roomListeners.remove(roomId);
    }
  }

  void _withBatchedRoomNotify(VoidCallback action) {
    if (_batchRoomNotify) {
      action();
      return;
    }
    _batchRoomNotify = true;
    try {
      action();
    } finally {
      _batchRoomNotify = false;
      for (final roomId in _batchedRoomNotifyQueue) {
        _notifyRoom(roomId);
      }
      _batchedRoomNotifyQueue.clear();
    }
  }

  /// 通知特定房间的监听器
  void _notifyRoom(String roomId) {
    if (_batchRoomNotify) {
      _batchedRoomNotifyQueue.add(roomId);
      return;
    }
    final listeners = _roomListeners[roomId];
    if (listeners != null) {
      for (final listener in [...listeners]) {
        try {
          listener();
        } catch (e) {
          talker.warning('Listener error for room $roomId: $e');
        }
      }
    }
  }

  void _touchCacheRoom(String roomId) {
    _cacheAccessOrder.remove(roomId);
    _cacheAccessOrder.add(roomId);
  }

  /// 若缓存超出上限，rm -rf 最久未访问的房间消息
  void _evictCacheIfNeeded() {
    final limit = _maxCachedRooms;
    while (_messageCache.length > limit && _cacheAccessOrder.isNotEmpty) {
      final oldest = _cacheAccessOrder.first;
      _cacheAccessOrder.remove(oldest);
      _activeHistoryReads.remove(oldest);
      _messageCache.remove(oldest);
      _notifyRoom(oldest);
      _midToRoom.removeWhere((_, room) => room == oldest);
      _hashToRooms.removeWhere((_, rooms) {
        rooms.remove(oldest);
        return rooms.isEmpty;
      });
      _pendingClientMidRooms.removeWhere((_, roomId) => roomId == oldest);
      talker.info(
        'ChatDataService: evicted message cache for room $oldest (limit=$limit)',
      );
    }
    _evictUsersIfNeeded();
  }

  /// 单房间内存副本上限
  static const int _maxMessagesPerRoom = 2000;

  /// 超出上限多少条
  static const int _messageTrimSlack = 300;

  void _trimRoomMessages(String roomId, List<ChatMessage> cached) {
    // 留一点滞回
    if (cached.length <= _maxMessagesPerRoom + _messageTrimSlack) return;
    final dropCount = cached.length - _maxMessagesPerRoom;
    final removed = cached.sublist(0, dropCount);
    cached.removeRange(0, dropCount);
    for (final message in removed) {
      final mid = message.mid;
      if (mid != null) _midToRoom.remove(mid);
      final hash = message.media?.fileHash;
      if (hash != null && hash.isNotEmpty) {
        final rooms = _hashToRooms[hash];
        if (rooms != null) {
          rooms.remove(roomId);
          if (rooms.isEmpty) _hashToRooms.remove(hash);
        }
      }
    }
  }

  /// 用户资料缓存上限
  static const int _maxCachedUsers = 3000;

  void _evictUsersIfNeeded() {
    if (_userCache.length <= _maxCachedUsers) return;
    final overflow = _userCache.length - _maxCachedUsers;
    final stale = _userCache.keys.take(overflow).toList(growable: false);
    for (final key in stale) {
      _userCache.remove(key);
    }
  }

  List<ChatRoom> get rooms => _rooms;
  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;

  void _indexMessages(String roomId, Iterable<ChatMessage> messages) {
    for (final message in messages) {
      final mid = message.mid;
      if (mid != null) _midToRoom[mid] = roomId;
      final hash = message.media?.fileHash;
      if (hash != null && hash.isNotEmpty) {
        _hashToRooms.putIfAbsent(hash, () => <String>{}).add(roomId);
      }
    }
  }

  void _clearMessageIndexes() {
    _midToRoom.clear();
    _hashToRooms.clear();
    _unreadRebaseSeq.clear();
  }

  void _beginIngest() => _batchIngest = true;
  
  void _endIngest() {
    _batchIngest = false;
    for (final entry in _pendingIngest.entries) {
      final changed = entry.value.values.toList();
      if (changed.isNotEmpty) {
        unawaited(_localStore.appendMessages(entry.key, changed));
      }
    }
    _pendingIngest.clear();
    _sortRooms();
  }

  /// 批量模式下延迟
  void _persistEntry(String roomId, ChatMessage message) {
    if (_batchIngest) {
      (_pendingIngest[roomId] ??= {})[RoomMessageHistory.localKey(message)] = message;
    } else {
      unawaited(_localStore.saveMessage(roomId, message));
    }
  }

  bool _aboveUnreadRebase(String roomId, int? seq) {
    final rebase = _unreadRebaseSeq[roomId];
    if (rebase == null || seq == null) return true;
    return seq > rebase;
  }

  int get totalUnreadCount => _rooms.fold(0, (sum, r) => sum + r.unreadCount);

  List<ChatMessage> getMessages(String roomId) {
    if (_messageCache.containsKey(roomId)) _touchCacheRoom(roomId);
    return _messageCache[roomId] ?? [];
  }

  List<ChatMessage> getMessageSnapshot(String roomId) {
    final history = _messageCache[roomId];
    if (history == null) return const [];
    _touchCacheRoom(roomId);
    return history.snapshot;
  }

  /// 本会话内可搜索的消息（本地库 + 内存缓存)
  Future<List<ChatMessage>> getSearchableMessages(String roomId) async {
    final local = await _localStore.loadMessages(roomId);
    final merged = _mergeMessages(_messageCache[roomId] ?? [], local);
    merged.sort(_compareMessages);
    if (merged.isEmpty) {
      return _fillSenderInfo((await refreshMessagesForContact(roomId)).messages);
    }
    return _fillSenderInfo(merged);
  }
  Future<MessageSearchPage> searchRoomMessagesFromServer(
    String roomId,
    String keyword, {
    int beforeMid = 0,
    int limit = _messageSearchPageSize,
  }) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return MessageSearchPage.empty;

    final rk = roomKey(roomId);
    final page = await TfApiClient.instance.searchMessages(
      uid,
      password,
      keyword,
      targetUid: rk > 0 ? rk : 0,
      groupId: rk < 0 ? -rk : null,
      beforeMid: beforeMid,
      limit: limit,
    );
    if (page.messages.isEmpty) return page;

    final filled = _fillSenderInfo(page.messages);
    _ensureSenderProfiles(filled, roomId);
    await _localStore.saveMessages(roomId, filled);
    return MessageSearchPage(messages: filled, hasMore: page.hasMore);
  }

  String? senderDisplayName(String roomId, ChatMessage message) {
    final senderUid = message.senderUid;
    return resolveSenderLabel(
      isMe: message.isMe,
      messageSenderName: message.senderName,
      selfName: message.isMe ? AuthState.instance.currentUser?.username : null,
      profileName: message.isMe || senderUid == null
          ? null
          : _senderNameFor(senderUid),
      directRoomName: isGroupRoom(roomId) ? null : _roomName(roomId),
    );
  }

  @visibleForTesting
  static String? resolveSenderLabel({
    required bool isMe,
    String? messageSenderName,
    String? selfName,
    String? profileName,
    String? directRoomName,
  }) {
    final fromMessage = messageSenderName?.trim();
    if (fromMessage != null && fromMessage.isNotEmpty) return fromMessage;
    if (isMe) {
      final self = selfName?.trim();
      if (self != null && self.isNotEmpty) return self;
      return null;
    }
    final profile = profileName?.trim();
    if (profile != null && profile.isNotEmpty) return profile;
    final roomName = directRoomName?.trim();
    if (roomName != null && roomName.isNotEmpty) return roomName;
    return null;
  }

  String? _roomName(String roomId) {
    for (final room in _rooms) {
      if (room.id == roomId) return room.name;
    }
    return null;
  }

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
    const maxPages = 3;
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
    _activeHistoryReads.remove(roomId);
    final cache = RoomMessageHistory(msgs);
    _messageCache[roomId] = cache;
    _touchCacheRoom(roomId);
    _evictCacheIfNeeded();
    unawaited(_localStore.saveMessages(roomId, cache));

    _notifyRoom(roomId);

    // 全局通知
    // 保留兼容性
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

  void _cacheSelfProfile() {
    final me = AuthState.instance.currentUser;
    if (me != null) cacheUserProfile(me);
  }

  final Set<String> _profileFetchesInFlight = {};

  Future<void> ensureUserProfile(int uid) async {
    if (uid < 0) return;
    final key = roomIdFromUid(uid);
    if (_userCache.containsKey(key)) return;
    if (AuthState.instance.uid == uid) {
      final me = AuthState.instance.currentUser;
      if (me != null) {
        cacheUserProfile(me);
        notifyListeners();
      }
      return;
    }

    if (!_profileFetchesInFlight.add(key)) return;
    try {
      final profile = await TfApiClient.instance.getUserByUid(uid);
      if (profile != null) {
        cacheUserProfile(profile);
        notifyListeners();
      }
    } catch (e) {
      talker.warning('ensureUserProfile failed uid=$uid', e);
    } finally {
      _profileFetchesInFlight.remove(key);
    }
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
        _messageCache[entry.key] = RoomMessageHistory(messages);
        unawaited(_localStore.saveMessages(entry.key, messages));
        _notifyRoom(entry.key);
      }
    }
    notifyListeners();
  }

  Future<void> _ensureRoomPreferencesLoaded() async {
    final generation = _generation;
    final uid = AuthState.instance.uid;
    if (uid == null) {
      _roomPreferences.clear();
      _roomPreferencesUid = null;
      _roomPreferencesScope = null;
      _roomPreferencesEncoded = null;
      return;
    }
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    if (_generation != generation || AuthState.instance.uid != uid) return;
    final scope = '${base64Url.encode(utf8.encode(baseUrl))}:$uid';
    if (_roomPreferencesUid == uid && _roomPreferencesScope == scope) return;

    final prefs = await SharedPreferences.getInstance();
    if (_generation != generation || AuthState.instance.uid != uid) return;
    if (_roomPreferencesUid == uid && _roomPreferencesScope == scope) return;
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
    _roomPreferences
      ..clear()
      ..addAll(loaded);
    _roomPreferencesUid = uid;
    _roomPreferencesScope = scope;
    _roomPreferencesEncoded = raw;
  }

  Future<void> _saveRoomPreferences() async {
    final scope = _roomPreferencesScope;
    if (scope == null) return;
    final encoded = _roomPreferences.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    final text = jsonEncode(encoded);
    if (text == _roomPreferencesEncoded) {
      // WS 每次重连都会 loadContactsAndRooms
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString('chat_room_prefs_$scope', text);
    if (saved && _roomPreferencesScope == scope) _roomPreferencesEncoded = text;
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
    final previous = _roomPreferenceWrites[roomId];
    final completion = Completer<void>();
    _roomPreferenceWrites[roomId] = completion.future;
    try {
      if (previous != null) await previous;
      if (_generation != generation || AuthState.instance.uid != uid) {
        return false;
      }
      await _ensureRoomPreferencesLoaded();
      if (_generation != generation || AuthState.instance.uid != uid) {
        return false;
      }
      if (isPinned != null ||
          notifyLevel != null ||
          alias != null ||
          description != null) {
        if (password == null) return false;
        final saved = await TfApiClient.instance.updateChatPreference(
          uid,
          password,
          roomId,
          isPinned: isPinned,
          notifyLevel: notifyLevel,
          alias: alias,
          description: description,
        );
        if (!saved ||
            _generation != generation ||
            AuthState.instance.uid != uid) {
          return false;
        }
      }
      final updated = getRoomPreference(roomId).copyWith(
        isPinned: isPinned,
        notifyLevel: notifyLevel,
        alias: alias,
        description: description,
      );
      await _applyRoomPreferenceLocally(
        roomId,
        updated,
        resetUnread: notifyLevel != null && notifyLevel != 0,
      );
      return true;
    } finally {
      completion.complete();
      if (identical(_roomPreferenceWrites[roomId], completion.future)) {
        _roomPreferenceWrites.remove(roomId);
      }
    }
  }

  Future<void> _applyRoomPreferenceLocally(
    String roomId,
    ChatRoomPreference updated, {
    required bool resetUnread,
  }) async {
    _roomPreferences[roomId] = updated;

    final roomIdx = _rooms.indexWhere((room) => room.id == roomId);
    if (roomIdx >= 0) {
      final currentRoom = _rooms[roomIdx];
      final fallbackName = _userCache[roomId]?.username ?? currentRoom.name;
      _rooms[roomIdx] = currentRoom.copyWith(
        name: displayNameForRoom(roomId, fallbackName),
        isPinned: updated.isPinned,
        unreadCount: resetUnread ? 0 : currentRoom.unreadCount,
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
    final save = _saveRoomPreferences();
    _notifyRoom(roomId);
    notifyListeners();
    await save;
  }

  /// 偏好
  Future<void> applyRemoteRoomPreference(Map<String, dynamic> data) async {
    final roomId = data['room_id']?.toString();
    if (roomId == null || roomId.isEmpty) return;
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    final generation = _generation;
    await _ensureRoomPreferencesLoaded();
    if (_generation != generation || AuthState.instance.uid != uid) return;
    final current = getRoomPreference(roomId);
    final updated = current.copyWith(
      isPinned: data['is_pinned'] as bool?,
      notifyLevel: (data['notify_level'] as num?)?.toInt(),
      alias: data['alias'] as String?,
      description: data['description'] as String?,
    );
    await _applyRoomPreferenceLocally(
      roomId,
      updated,
      resetUnread: updated.notifyLevel != 0,
    );
  }

  Future<bool> updateRoomPinState(String roomId, bool isPinned) async {
    return updateRoomPreference(roomId, isPinned: isPinned);
  }

  Future<void> clearRoomLocalData(String roomId) async {
    _activeHistoryReads.remove(roomId);
    final generation = _generation;
    // 消息缓存
    _messageCache.remove(roomId);
    _cacheAccessOrder.remove(roomId);

    // 本地消息存储
    await _localStore.deleteRoom(roomId);

    if (_generation != generation) return;

    // 保留最后消息摘要
    _notifyRoom(roomId);
    notifyListeners();
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
    _activeHistoryReads.clear();
    _messageCache.clear();
    _cacheAccessOrder.clear();
    _userCache.clear();
    _clearMessageIndexes();
    _rooms.clear();
    _contacts.clear();
    _initializedUid = uid;
    messageCacheResetRevision.value++;
    _cacheSelfProfile();
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

  Future<void> _restoreSyncBaselines() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final generation = _generation;
    final syncService = MessageSyncService.instance;
    await syncService.loadFullSyncRooms();
    final rooms = List<ChatRoom>.from(_rooms);
    for (final room in rooms) {
      if (_generation != generation || AuthState.instance.uid != uid) return;
      if (!syncService.isFullSyncRoom(room.id)) {
        // 仅浏览模式且未升级的房间
        final browseSeq = room.serverLastSeq;
        if (browseSeq != null && browseSeq > 0) {
          await syncService.adoptServerBaseline(room.id, browseSeq);
        }
        continue;
      }
      final seq = await LocalMessageStore.instance.getRoomSyncSeq(room.id);
      if (seq != null && seq > 0) {
        syncService.registerRoomSeq(room.id, seq);
        continue;
      }
      // 旧数据迁移的客户端只有 sync_mid
      final syncMid = await LocalMessageStore.instance.getRoomSyncMid(
        room.id,
      );
      if (syncMid != null && syncMid > 0) {
        await syncService.syncRoomFromMid(room.id, syncMid);
        continue;
      }
      // 全新房间
      final serverSeq = room.serverLastSeq;
      if (serverSeq != null && serverSeq > 0) {
        await syncService.adoptServerBaseline(room.id, serverSeq);
        continue;
      }
      final mid = room.lastMessageMid;
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
    _roomPreferenceWrites.clear();
    await _wsSubscription?.cancel();
    if (_generation != generation) return;
    _wsSubscription = null;
    ChatWsService.instance.removeListener(_onWsStateChanged);
    MessageSyncService.instance.clear();
    _initializedUid = null;
    _roomPreferencesUid = null;
    _roomPreferencesScope = null;
    _roomPreferencesEncoded = null;
    _pendingClientMidRooms.clear();
    _activeHistoryReads.clear();
    _messageCache.clear();
    _cacheAccessOrder.clear();
    _userCache.clear();
    _clearMessageIndexes();
    _roomPreferences.clear();
    // roomId/mid 全局共享
    _peerReadSeq.clear();
    _groupReadCounts.clear();
    _bumpReadReceiptRevision();
    _rooms.clear();
    _contacts.clear();
    _roomListeners.clear();
    messageCacheResetRevision.value++;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearLocalMessageDatabase() async {
    _activeHistoryReads.clear();
    await _localStore.clearDatabase();
    _activeHistoryReads.clear();
    _messageCache.clear();
    _cacheAccessOrder.clear();
    _clearMessageIndexes();
    messageCacheResetRevision.value++;
    notifyListeners();
  }

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
      final byTime = bTime.compareTo(aTime);
      if (byTime != 0) return byTime;
      // Dart 的 List.sort 对大列表不稳定，两条消息落在同一毫秒时
      // 顺序会随排序实现变化
      final byMid = (b.lastMessageMid ?? 0).compareTo(a.lastMessageMid ?? 0);
      if (byMid != 0) return byMid;
      return a.id.compareTo(b.id);
    });
  }

  /// 会话预览是否应该被 [msg] 覆盖
  static bool _shouldAdvanceRoomPreview(ChatRoom room, ChatMessage msg) {
    final mid = msg.mid;
    final lastMid = room.lastMessageMid;
    if (mid != null && lastMid != null) return mid > lastMid;
    final lastTime = room.lastMessageTime;
    if (lastTime == null) return true;
    return !msg.timestamp.isBefore(lastTime);
  }

  static bool _serverPreviewWins({
    required int? serverMid,
    required DateTime? serverTime,
    required int? localMid,
    required DateTime? localTime,
  }) {
    if (serverMid != null && localMid != null) return serverMid >= localMid;
    if (serverTime == null) return localTime == null;
    if (localTime == null) return true;
    return !serverTime.isBefore(localTime);
  }

  static List<ChatMessage> _tail(List<ChatMessage> list, int count) =>
      list.length <= count ? list : list.sublist(list.length - count);

  int _compareMessages(ChatMessage a, ChatMessage b) =>
      ChatMessage.compareByOrder(a, b, RoomMessageHistory.localKey);

  /// 把消息插入已排序列表
  void _insertSorted(List<ChatMessage> mutable, ChatMessage message) {
    if (mutable.isEmpty || _compareMessages(mutable.last, message) < 0) {
      mutable.add(message);
      return;
    }
    var lo = 0;
    var hi = mutable.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_compareMessages(mutable[mid], message) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    mutable.insert(lo, message);
  }

  List<ChatMessage> _replaceSorted(
    List<ChatMessage> cached,
    int index,
    ChatMessage replacement,
  ) {
    final updated = List<ChatMessage>.from(cached)..removeAt(index);
    _insertSorted(updated, replacement);
    return updated;
  }

  /// 服务端回声
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

  Future<void>? _loadContactsFuture;

  Future<void> loadContactsAndRooms() {
    final pending = _loadContactsFuture;
    if (pending != null) return pending;
    late final Future<void> future;
    future = _loadContactsAndRoomsOnce().whenComplete(() {
      if (identical(_loadContactsFuture, future)) _loadContactsFuture = null;
    });
    _loadContactsFuture = future;
    return future;
  }

  Future<void> _loadContactsAndRoomsOnce() async {
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
      _cacheSelfProfile();
      await _ensureRoomPreferencesLoaded();
      if (_generation != generation ||
          _roomListGeneration != roomListGeneration ||
          AuthState.instance.uid != uid) {
        return;
      }
      talker.info(
        'ChatDataService.loadContactsAndRooms: calling /chat/list for uid=$uid',
      );
      final unreadSnapshot = {
        for (final room in _rooms) room.id: room.unreadCount,
      };
      final chatItems = await TfApiClient.instance.queryChatList(uid, password);
      if (_generation != generation ||
          _roomListGeneration != roomListGeneration ||
          AuthState.instance.uid != uid) {
        return;
      }
      if (chatItems == null) {
        talker.warning(
          'ChatDataService.loadContactsAndRooms: /chat/list failed, '
          'keeping ${_rooms.length} cached rooms',
        );
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

      final existingRooms = {for (final room in _rooms) room.id: room};
      final nextRooms = <ChatRoom>[];
      final nextContacts = <Contact>[];

      for (final item in chatItems) {
        // 过滤
        if (item.partnerUid == uid) continue;
        if (item.partnerUid < 0 && item.roomType != 'group') continue;
        final isGroup = item.roomType == 'group';
        final existingRoom = existingRooms[item.roomId];
        if (item.isPinned != null ||
            item.notifyLevel != null ||
            item.alias != null ||
            item.description != null) {
          final currentPreference = getRoomPreference(item.roomId);
          _roomPreferences[item.roomId] = currentPreference.copyWith(
            isPinned: item.isPinned,
            notifyLevel: item.notifyLevel,
            alias: item.alias,
            description: item.description,
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

        final localUnread = existingRoom?.unreadCount ?? 0;
        final snapshot = unreadSnapshot[item.roomId] ?? 0;
        final windowDelta = localUnread - snapshot;
        final unread = item.unreadCount + (windowDelta > 0 ? windowDelta : 0);
        // 记录
        _unreadRebaseSeq[item.roomId] = item.lastSeq ?? 0;

        nextRooms.add(
          ChatRoom(
            id: item.roomId,
            name: displayName,
            avatar: avatarUrl,
            type: isGroup ? ChatType.group : ChatType.direct,
            lastMessage: item.lastDeleted
                ? ''
                : item.visibleLastContent ?? existingRoom?.lastMessage,
            lastMessageType: item.lastDeleted
                ? MessageType.text
                : item.lastMessageType,
            lastMessageFileName: item.lastFileName,
            lastMessageTime: lastTime ?? existingRoom?.lastMessageTime,
            lastMessageMid: item.lastMid,
            serverLastSeq: item.lastSeq,
            unreadCount: unread,
            isPinned: getRoomPreference(item.roomId).isPinned,
          ),
        );
        if (existingRoom != null &&
            !item.lastDeleted &&
            !_serverPreviewWins(
              serverMid: item.lastMid,
              serverTime: lastTime,
              localMid: existingRoom.lastMessageMid,
              localTime: existingRoom.lastMessageTime,
            )) {
          final index = nextRooms.length - 1;
          nextRooms[index] = nextRooms[index].copyWith(
            lastMessage: existingRoom.lastMessage,
            lastMessageTime: existingRoom.lastMessageTime,
            lastMessageMid: existingRoom.lastMessageMid,
            lastMessageType: existingRoom.lastMessageType,
            lastMessageFileName: existingRoom.lastMessageFileName,
          );
        }
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
    // 刚发出的消息只可能在自己的房间
    final knownRoom = _pendingClientMidRooms[clientMid];
    final roomIds = knownRoom != null && _messageCache.containsKey(knownRoom)
        ? <String>[knownRoom]
        : _messageCache.keys;
    for (final roomId in roomIds) {
      final msgs = _messageCache[roomId]!;
      final idx = msgs.indexWhere((m) => m.isMe && m.clientMid == clientMid);
      if (idx != -1) {
        final existing = msgs[idx];
        final changed = existing.copyWith(
          id: serverMid?.toString() ?? existing.id,
          mid: serverMid ?? existing.mid,
          roomSeq: roomSeq ?? existing.roomSeq,
          status: status,
          ackError: error,
          clearAckError: error == null,
        );
        final updated = roomSeq != null && roomSeq != existing.roomSeq
            ? _replaceSorted(msgs, idx, changed)
            : (List<ChatMessage>.from(msgs, growable: true)..[idx] = changed);
        _messageCache[roomId] = RoomMessageHistory(updated);
        _pendingClientMidRooms.remove(clientMid);
        _indexMessages(roomId, [changed]);
        unawaited(_localStore.saveMessage(roomId, changed));
        if (updated.isNotEmpty &&
            identical(updated.last, changed) &&
            serverMid != null) {
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
        _notifyRoom(roomId);
        notifyListeners();
        return;
      }
    }
    // 索引失效
    _pendingClientMidRooms.remove(clientMid);
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> server,
    List<ChatMessage> local, {
    List<ChatMessage>? keepBytesFrom,
  }) {
    // 服务端版本不带 bytes
    final localBytes = <String, List<int>>{};
    final byteSources = <ChatMessage>[..._tail(local, 100)];
    if (keepBytesFrom != null) byteSources.addAll(_tail(keepBytesFrom, 100));
    for (final message in byteSources) {
      final bytes = message.media?.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        localBytes[RoomMessageHistory.localKey(message)] = bytes;
      }
    }
    final seen = <String>{};
    // 去重键优先 clientMid
    final seenMids = <int>{};
    var result = <ChatMessage>[];
    for (final m in [...server, ...local]) {
      final mid = m.mid;
      if (mid != null && !seenMids.add(mid)) continue;
      final key = RoomMessageHistory.localKey(m);
      if (!seen.add(key)) continue;
      final bytes = localBytes[key];
      final media = m.media;
      if (bytes != null &&
          media != null &&
          (media.bytes == null || media.bytes!.isEmpty)) {
        result.add(m.copyWith(media: media.copyWith(bytes: bytes)));
      } else {
        result.add(m);
      }
    }
    if (result.isEmpty) return result;
    final recalledMids = <int>{
      for (final message in result)
        if (message.isDeleted && message.mid != null) message.mid!,
    };
    if (recalledMids.isEmpty) return result;
    return applyRecallsToMessages(result, recalledMids);
  }

  List<ChatMessage> _attachOlderMessages(
    List<ChatMessage> cached,
    List<ChatMessage> older,
    List<ChatMessage> local,
  ) {
    final knownMids = <int>{};
    final knownKeys = <String>{};
    for (final message in cached) {
      final mid = message.mid;
      if (mid != null) knownMids.add(mid);
      knownKeys.add(message.localIdentityKey);
    }

    final incoming = <ChatMessage>[];
    for (final message in older) {
      if (!_claimIncoming(message, knownMids, knownKeys)) {
        continue;
      }
      incoming.add(message);
    }
    for (final message in local) {
      if (!_claimIncoming(message, knownMids, knownKeys)) {
        continue;
      }
      incoming.add(message);
    }
    if (incoming.isEmpty) return cached;
    incoming.sort(_compareMessages);
    return _mergeSortedLists(incoming, cached);
  }

  @visibleForTesting
  List<ChatMessage> debugAttachOlderMessages(
    List<ChatMessage> cached,
    List<ChatMessage> older,
    List<ChatMessage> local,
  ) => _attachOlderMessages(cached, older, local);

  static bool _claimIncoming(
    ChatMessage message,
    Set<int> knownMids,
    Set<String> knownKeys,
  ) {
    final key = message.localIdentityKey;
    final mid = message.mid;
    if (knownKeys.contains(key) || (mid != null && knownMids.contains(mid))) {
      return false;
    }
    knownKeys.add(key);
    if (mid != null) knownMids.add(mid);
    return true;
  }

  /// 线性合并
  List<ChatMessage> _mergeSortedLists(
    List<ChatMessage> first,
    List<ChatMessage> second,
  ) {
    if (first.isEmpty) return second;
    if (second.isEmpty) return first;
    final merged = List<ChatMessage>.filled(
      first.length + second.length,
      first.first,
      growable: true,
    );
    var i = 0;
    var j = 0;
    var k = 0;
    while (i < first.length && j < second.length) {
      if (_compareMessages(first[i], second[j]) <= 0) {
        merged[k++] = first[i++];
      } else {
        merged[k++] = second[j++];
      }
    }
    while (i < first.length) {
      merged[k++] = first[i++];
    }
    while (j < second.length) {
      merged[k++] = second[j++];
    }
    return merged;
  }

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

    if (event.type == 'message.read') {
      // 同账号其它设备
      final data = event.notification;
      final uid = AuthState.instance.uid;
      if (data == null || uid == null) return;
      if ((data['uid'] as num?)?.toInt() != uid) return;
      final roomId = data['room_id'] as String?;
      final lastSeq = (data['last_seq'] as num?)?.toInt();
      if (roomId == null || roomId.isEmpty || lastSeq == null) return;
      applyRemoteReadReceipt(roomId, lastSeq);
      return;
    }

    if (event.type == 'message.read_receipt') {
      // 私聊
      // 对方（好友）已读到
      final data = event.notification;
      if (data == null) return;
      final roomId = data['room_id'] as String?;
      final lastSeq = (data['last_seq'] as num?)?.toInt();
      if (roomId == null || roomId.isEmpty || lastSeq == null) return;
      applyPeerReadReceipt(roomId, lastSeq);
      return;
    }

    if (event.type == 'PRIVACY.UPDATED') {
      unawaited(AuthState.instance.refreshProfile());
      return;
    }

    if (event.type == 'FILE.MEDIA_READY') {
      final items = event.notification?['items'];
      if (items is List) {
        applyMediaMetadataToMessages(items);
      }
      return;
    }

    if (event.type == 'PREFERENCES.UPDATED') {
      final data = event.notification;
      if (data != null && data['scope'] == 'room') {
        unawaited(applyRemoteRoomPreference(data));
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

    // 瞬时通知（NOTIFICATION.EPHEMERAL）
    if ((event.type != 'NOTIFICATION.NEW' &&
            event.type != 'NOTIFICATION.EPHEMERAL') ||
        event.notification == null) {
      return;
    }

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

  @visibleForTesting
  void deliverIncomingMessage(String roomId, ChatMessage msg) =>
      _addToCache(roomId, msg);

  @visibleForTesting
  void debugSetUnreadRebase(String roomId, int seq) =>
      _unreadRebaseSeq[roomId] = seq;

  void processSyncedMessages(
    String roomId,
    List<ChatMessage> messages, {
    bool isHistorical = false,
  }) {
    if (messages.isEmpty) return;
    _withBatchedRoomNotify(() {
      _beginIngest();
      try {
        final timeline = <ChatMessage>[];
        for (final msg in messages) {
          // 事件（撤回等变更
          if (msg.contentType == 'event') {
            _applyEventMessage(roomId, msg);
            continue;
          }
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
          timeline.add(msg);
          _addToCacheSilent(roomId, msg, countUnread: !isHistorical);
        }
        _ensureSenderProfiles(timeline, roomId);
      } finally {
        _endIngest();
      }
    });
    notifyListeners();
  }

  /// 应用一条事件
  void _applyEventMessage(String roomId, ChatMessage event) {
    if (event.eventKind == 'message.recalled' && event.eventTargetMid != null) {
      markMessageRecalled(
        event.eventTargetMid!,
        roomId: roomId,
        deletedAt: event.timestamp,
        deletedBy: event.senderUid,
      );
    }
    // 未来的事件 kind 在此扩展
    // 未知 kind 忽略。
  }

  void _addToCacheSilent(
    String roomId,
    ChatMessage msg, {
    bool countUnread = true,
  }) {
    final cached = _messageCache[roomId] ?? RoomMessageHistory();
    final matchIdx = cached.indexOfMessage(msg);
    var listChanged = false;
    if (matchIdx == null) {
      _insertSorted(cached, msg);
      _trimRoomMessages(roomId, cached);
      _messageCache[roomId] = cached;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
      _indexMessages(roomId, [msg]);
      _persistEntry(roomId, msg);
      listChanged = true;
    } else {
      final upgraded = _adoptServerFields(cached[matchIdx], msg);
      if (!identical(upgraded, cached[matchIdx])) {
        final updated = _replaceSorted(cached, matchIdx, upgraded);
        _messageCache[roomId] = RoomMessageHistory(updated);
        _touchCacheRoom(roomId);
        _evictCacheIfNeeded();
        _indexMessages(roomId, [upgraded]);
        _persistEntry(roomId, upgraded);
        listChanged = true;
      }
    }

    final uid = AuthState.instance.uid;
    final username = AuthState.instance.currentUser?.username ?? '';
    final shouldCountUnread =
        countUnread &&
        !msg.isMe &&
        matchIdx == null &&
        _aboveUnreadRebase(roomId, msg.roomSeq) &&
        (msg.shouldAlert ??
            (uid != null &&
                shouldNotifyMessage(
                  notifyLevel: roomNotifyLevel(roomId),
                  message: msg.text,
                  currentUid: uid,
                  currentUsername: username,
                )));

    final roomIndex = _rooms.indexWhere((r) => r.id == roomId);
    if (roomIndex < 0) {
      _addNewRoom(roomId, msg, unreadCount: shouldCountUnread ? 1 : 0);
    } else {
      var updated = _rooms[roomIndex];
      // 乱序到达
      if (_shouldAdvanceRoomPreview(updated, msg)) {
        updated = updated.copyWith(
          lastMessage: msg.text,
          lastMessageTime: msg.timestamp,
          lastMessageMid: msg.mid,
          lastMessageType: msg.type,
          lastMessageFileName: msg.media?.fileName,
        );
      }
      if (shouldCountUnread) {
        updated = updated.copyWith(unreadCount: updated.unreadCount + 1);
      }
      _rooms[roomIndex] = updated;
    }
    // 未读早于房间通知
    if (listChanged) _notifyRoom(roomId);
    unawaited(_ensureGroupInfo(roomId));
    if (!_batchIngest) {
      _sortRooms();
      notifyListeners();
    }
  }

  String _roomIdForNotification(NotificationInfo info, int myUid) {
    if (info.roomId != null && info.roomId!.isNotEmpty) return info.roomId!;
    if (info.groupId != null) return 'G${info.groupId}';
    return roomIdFromUid(info.senderUid ?? myUid);
  }

  void _addToCache(String roomId, ChatMessage msg) {
    final cached = _messageCache[roomId] ?? RoomMessageHistory();
    final matchIdx = cached.indexOfMessage(msg);
    var listChanged = false;
    if (matchIdx == null) {
      _insertSorted(cached, msg);
      _trimRoomMessages(roomId, cached);
      _messageCache[roomId] = cached;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
      _indexMessages(roomId, [msg]);
      unawaited(_localStore.saveMessage(roomId, msg));
      listChanged = true;
    } else {
      final upgraded = _adoptServerFields(cached[matchIdx], msg);
      if (!identical(upgraded, cached[matchIdx])) {
        final updated = _replaceSorted(cached, matchIdx, upgraded);
        _messageCache[roomId] = RoomMessageHistory(updated);
        _touchCacheRoom(roomId);
        _evictCacheIfNeeded();
        _indexMessages(roomId, [upgraded]);
        unawaited(_localStore.saveMessage(roomId, upgraded));
        notifyListeners();
        listChanged = true;
      }
      if (listChanged) _notifyRoom(roomId);
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
      var updated = _rooms[idx];
      if (_shouldAdvanceRoomPreview(updated, msg)) {
        updated = updated.copyWith(
          lastMessage: msg.text,
          lastMessageTime: msg.timestamp,
          lastMessageMid: msg.mid,
          lastMessageType: msg.type,
          lastMessageFileName: msg.media?.fileName,
        );
      }
      if (shouldNotify) {
        updated = updated.copyWith(unreadCount: updated.unreadCount + 1);
      }
      _rooms[idx] = updated;
    } else {
      _addNewRoom(roomId, msg, unreadCount: shouldNotify ? 1 : 0);
    }
    // 先记完未读再通知房间，反了会把刚清掉的未读又 +1 回来，什么神金问题
    _notifyRoom(roomId);
    unawaited(_ensureGroupInfo(roomId));
    _sortRooms();
    notifyListeners();
    if (shouldNotify && _shouldSendNotification(roomId)) {
      final notifyIndex = _rooms.indexWhere((room) => room.id == roomId);
      if (notifyIndex >= 0) {
        final room = _rooms[notifyIndex];
        unawaited(
          AppNotificationService.instance.present(
            AppNotification(
              id: '$roomId:${msg.id}',
              title: room.name,
              body: msg.text,
              avatarUrl: msg.senderAvatar ?? room.avatar,
              route: '/chat/$roomId',
              topic: isGroupRoom(roomId) ? 'message.group' : 'message.private',
              senderKey: roomId,
              roomId: roomId,
            ),
          ),
        );
      }
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
        lastMessageType: msg.type,
        lastMessageFileName: msg.media?.fileName,
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
    // 防止重复加载同一用户
    if (!_fetchingUsers.add(roomId)) return;

    final puid = _parseUid(roomId);
    if (puid == null) {
      _fetchingUsers.remove(roomId);
      return;
    }
    final generation = _generation;
    final uid = AuthState.instance.uid;

    TfApiClient.instance
        .getUserByUid(puid)
        .then((profile) {
          _fetchingUsers.remove(roomId);

          if (profile == null ||
              _generation != generation ||
              AuthState.instance.uid != uid) {
            return;
          }
          _userCache[profile.uid] = profile;
          // profile.uid 是 "U{uid}"
          // 但是之前有问题
          _userCache[roomIdFromUid(puid)] = profile;
          _updateRoomAndContacts(roomId, profile.username, profile.avatar);
          _fillMsgAvatars(
            messageRoomId ?? roomId,
            puid,
            profile.username,
            profile.avatar,
          );
          // 强制通知UI刷新
          notifyListeners();
        })
        .catchError((error, stack) {
          _fetchingUsers.remove(roomId);
          talker.error('Failed to fetch profile for $roomId', error, stack);
        });
  }

  Future<void> ensureGroupInfo(int gid) => _ensureGroupInfo('G$gid');

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
      talker.error(
        'ChatDataService fetch group info failed for $roomId',
        e,
        stack,
      );
    } finally {
      _fetchingGroups.remove(roomId);
    }
  }

  @visibleForTesting
  static List<String> collectMissingSenderRooms({
    required List<ChatMessage> messages,
    required int? myUid,
    required Set<String> cachedRooms,
    required Set<String> fetchingRooms,
  }) {
    final missing = <String>[];
    if (myUid == null) return missing;
    final seen = <int>{};
    for (final message in messages) {
      final senderUid = message.senderUid;
      // 0 是合法 UID
      // TouchFish UID 为自然数
      // hywyf
      if (senderUid == null ||
          senderUid == myUid ||
          message.isMe ||
          !seen.add(senderUid)) {
        continue;
      }
      final senderRoomId = roomIdFromUid(senderUid);
      if (cachedRooms.contains(senderRoomId) ||
          fetchingRooms.contains(senderRoomId)) {
        continue;
      }
      missing.add(senderRoomId);
    }
    return missing;
  }

  /// 逐个抓取资料
  Future<void> _ensureSenderProfiles(
    List<ChatMessage> messages,
    String roomId,
  ) async {
    final missingProfiles = collectMissingSenderRooms(
      messages: messages,
      myUid: AuthState.instance.uid,
      cachedRooms: _userCache.keys.toSet(),
      fetchingRooms: _fetchingUsers,
    );
    // 批量启动加载
    for (final senderRoomId in missingProfiles) {
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
      _messageCache[roomId] = RoomMessageHistory(updated);
      _localStore.saveMessages(roomId, updated);
      _notifyRoom(roomId);
    }
  }

  /// 删除本机未发送/发送失败的消息
  void deleteLocalMessage(String roomId, ChatMessage message) {
    _activeHistoryReads.remove(roomId);
    var changed = false;
    final cached = _messageCache[roomId];
    if (cached != null) {
      final updated = cached
          .where((m) => !_sameLocalMessage(m, message))
          .toList();
      if (updated.length != cached.length) {
        _messageCache[roomId] = RoomMessageHistory(updated);
        unawaited(_localStore.deleteMessage(roomId, message));
        _notifyRoom(roomId);
        changed = true;
      }
    }
    if (changed) {
      final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
      if (roomIndex >= 0 && _rooms[roomIndex].lastMessageMid == null) {
        final lastMessages = _messageCache[roomId];
        final last = lastMessages == null || lastMessages.isEmpty
            ? null
            : lastMessages.last;
        _rooms[roomIndex] = _rooms[roomIndex].copyWith(
          lastMessage: last?.text ?? '',
          lastMessageType: last?.type,
          lastMessageFileName: last?.media?.fileName,
        );
      }
    }
    if (changed) notifyListeners();
  }

  bool _sameLocalMessage(ChatMessage a, ChatMessage b) => a.matchesMessage(b);

  @visibleForTesting
  void debugSetRawCache(String roomId, List<ChatMessage> messages) {
    _messageCache[roomId] = RoomMessageHistory(messages);
    _touchCacheRoom(roomId);
  }

  void addSentMessage(String roomId, ChatMessage msg) {
    final clientMid = msg.clientMid;
    if (clientMid != null && clientMid.isNotEmpty) {
      _pendingClientMidRooms[clientMid] = roomId;
    }
    final cached = _messageCache[roomId] ?? RoomMessageHistory();
    if (cached.indexOfMessage(msg) == null) {
      _insertSorted(cached, msg);
      _messageCache[roomId] = cached;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
      _indexMessages(roomId, [msg]);
      unawaited(_localStore.saveMessage(roomId, msg));
      _notifyRoom(roomId);
    }

    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx >= 0) {
      _rooms[idx] = _rooms[idx].copyWith(
        lastMessage: msg.text,
        lastMessageTime: msg.timestamp,
        lastMessageType: msg.type,
        lastMessageFileName: msg.media?.fileName,
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

  /// 收到 FILE.MEDIA_READY
  void applyMediaMetadataToMessages(List<dynamic> items) {
    final patches = <String, Map<String, dynamic>>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final hash = raw['hash']?.toString();
      if (hash == null || hash.isEmpty) continue;
      patches[hash] = Map<String, dynamic>.from(raw);
    }
    if (patches.isEmpty) return;
    var changed = false;
    // 候选房间优先由 fileHash 索引
    final candidateRooms = <String>{};
    var needFullScan = false;
    for (final hash in patches.keys) {
      final rooms = _hashToRooms[hash];
      if (rooms == null || rooms.isEmpty) {
        needFullScan = true;
      } else {
        candidateRooms.addAll(rooms);
      }
    }
    if (needFullScan) candidateRooms.addAll(_messageCache.keys);
    for (final id in candidateRooms) {
      final messages = _messageCache[id];
      if (messages == null) continue;
      final changedMessages = <ChatMessage>[];
      List<ChatMessage>? updated;
      for (var index = 0; index < messages.length; index++) {
        final patched = _applyMediaPatch(messages[index], patches);
        if (patched == null) continue;
        updated ??= List<ChatMessage>.from(messages);
        updated[index] = patched;
        changedMessages.add(patched);
      }
      if (updated == null) continue;
      _messageCache[id] = RoomMessageHistory(updated);
      if (changedMessages.isNotEmpty) {
        unawaited(_localStore.appendMessages(id, changedMessages));
      }
      _notifyRoom(id);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  ChatMessage? _applyMediaPatch(
    ChatMessage message,
    Map<String, Map<String, dynamic>> patches,
  ) {
    final media = message.media;
    final hash = media?.fileHash;
    if (media == null || hash == null) return null;
    final patch = patches[hash];
    if (patch == null) return null;
    final width = (patch['width'] as num?)?.toInt();
    final height = (patch['height'] as num?)?.toInt();
    final blurhash = patch['blurhash']?.toString();
    final hasThumb =
        patch['has_thumb'] == true || (patch['thumb_url'] as String?) != null;
    final updatedMedia = media.withMediaMetadata(
      width: width,
      height: height,
      blurhash: blurhash,
      hasThumb: hasThumb ? true : null,
    );
    final updatedMessage = message.copyWith(media: updatedMedia);
    if (ChatMessage.sameRenderedContent(message, updatedMessage)) return null;
    return updatedMessage;
  }

  void markMessageRecalled(
    int mid, {
    String? roomId,
    DateTime? deletedAt,
    int? deletedBy,
  }) {
    if (roomId == null) {
      _activeHistoryReads.clear();
    } else {
      _activeHistoryReads.remove(roomId);
    }
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
      _messageCache[id] = RoomMessageHistory(updated);
      unawaited(_localStore.saveMessages(id, updated));
      _notifyRoom(id);
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
    if (changed && !_batchIngest) notifyListeners();
  }

  /// 被撤回消息的原位 seq 被吃了，就不要 retry 了
  void _forgetRecalledSeqFromSync(int mid) {
    final indexedRoom = _midToRoom[mid];
    if (indexedRoom != null) {
      final messages = _messageCache[indexedRoom];
      if (messages != null) {
        for (final message in messages) {
          if (message.mid == mid && message.roomSeq != null) {
            MessageSyncService.instance.forgetMissingSeq(
              indexedRoom,
              message.roomSeq!,
            );
            return;
          }
        }
      }
    }
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
  }) => applyRecallsToMessages(
    messages,
    {mid},
    deletedAt: deletedAt,
    deletedBy: deletedBy,
  );
  static List<ChatMessage> applyRecallsToMessages(
    List<ChatMessage> messages,
    Set<int> mids, {
    DateTime? deletedAt,
    int? deletedBy,
  }) {
    if (mids.isEmpty) return messages;
    var changed = false;
    final updated = messages.map((message) {
      var next = message;
      if (mids.contains(message.mid) && !message.isDeleted) {
        next = message.asTombstone(at: deletedAt, by: deletedBy);
        changed = true;
      }
      final quote = next.quotePreview;
      if (quote != null &&
          mids.contains(quote.mid) &&
          (!quote.isDeleted ||
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


  void applyRemoteReadReceipt(String roomId, int lastSeq) {
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx < 0 || _rooms[idx].unreadCount <= 0) return;
    final cached = _messageCache[roomId] ?? const <ChatMessage>[];
    var remaining = 0;
    for (final msg in cached) {
      final seq = msg.roomSeq;
      if (seq == null || seq <= lastSeq || msg.isMe) continue;
      remaining++;
    }
    final current = _rooms[idx].unreadCount;
    final updated = remaining < current ? remaining : current;
    if (updated != current) {
      _rooms[idx] = _rooms[idx].copyWith(unreadCount: updated);
      notifyListeners();
    }
  }

  /// 私聊
  /// 对方当前已读到
  int? peerReadSeq(String roomId) => _peerReadSeq[roomId];

  /// 群聊
  /// 某条消息的已读人数
  int? groupReadCount(int mid) => _groupReadCounts[mid];

  /// 群聊
  /// mid 已读人数
  Map<int, int> get groupReadCounts => UnmodifiableMapView(_groupReadCounts);

  /// 收到私聊已读
  void applyPeerReadReceipt(String roomId, int lastSeq) {
    if (roomId.isEmpty || lastSeq <= 0) return;
    final prev = _peerReadSeq[roomId];
    if (prev != null && prev >= lastSeq) return;
    _peerReadSeq[roomId] = lastSeq;
    notifyListeners();
    _bumpReadReceiptRevision();
  }

  /// 丢弃私聊对方的已读
  void clearPeerReadReceipt(String roomId) {
    if (_peerReadSeq.remove(roomId) == null) return;
    notifyListeners();
    _bumpReadReceiptRevision();
  }

  Future<void> refreshReadReceipt(String roomId, int mid) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final result = await TfApiClient.instance.queryReadReceipt(
      uid,
      password,
      roomId,
      mid,
    );
    if (result == null || AuthState.instance.uid != uid) return;
    applyReadReceiptResult(roomId, mid, result);
  }

  @visibleForTesting
  void applyReadReceiptResult(String roomId, int mid, TfReadReceipt result) {
    if (roomId.startsWith('U')) {
      if (result.hidden || result.readerLastSeq <= 0) {
        clearPeerReadReceipt(roomId);
      } else {
        applyPeerReadReceipt(roomId, result.readerLastSeq);
      }
    } else if (roomId.startsWith('G')) {
      setGroupReadCount(mid, result.readCount);
    }
  }

  void setGroupReadCount(int mid, int count) {
    if (count < 0 || _groupReadCounts[mid] == count) return;
    // Dart 的 Map 保序
    _groupReadCounts.remove(mid);
    _groupReadCounts[mid] = count;
    while (_groupReadCounts.length > _groupReadCountCap) {
      _groupReadCounts.remove(_groupReadCounts.keys.first);
    }
    notifyListeners();
    _bumpReadReceiptRevision();
  }

  Future<void> removeRoom(String roomId) async {
    _activeHistoryReads.remove(roomId);
    _roomListGeneration++;
    _rooms.removeWhere((room) => room.id == roomId);
    _contacts.removeWhere((contact) => contact.id == roomId);
    _messageCache.remove(roomId);
    _cacheAccessOrder.remove(roomId);
    _notifyRoom(roomId);
    _userCache.remove(roomId);
    _roomPreferences.remove(roomId);
    await _saveRoomPreferences();
    await _localStore.deleteRoom(roomId);
    notifyListeners();
  }

  Future<MessageHistoryPage> refreshMessagesForContact(String roomId) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      return const MessageHistoryPage(messages: [], hasMore: false);
    }
    final generation = _generation;
    final rk = roomKey(roomId);
    return refreshFirstPage(
      roomId,
      loadServer: () => TfApiClient.instance.queryMessageHistory(
        uid,
        password,
        rk > 0 ? rk : 0,
        groupId: rk < 0 ? -rk : null,
        limit: _messagePageSize,
      ),
      loadLocal: () =>
          _localStore.loadMessages(roomId, limit: _messagePageSize),
      sameAccount: () =>
          generation == _generation && AuthState.instance.uid == uid,
    );
  }

  @visibleForTesting
  Future<MessageHistoryPage> refreshFirstPage(
    String roomId, {
    required Future<List<ChatMessage>> Function() loadServer,
    required Future<List<ChatMessage>> Function() loadLocal,
    required bool Function() sameAccount,
  }) async {
    const empty = MessageHistoryPage(messages: [], hasMore: false);
    final token = Object();
    _activeHistoryReads[roomId] = token;
    final before = (_messageCache[roomId] ??= RoomMessageHistory()).snapshot;
    _touchCacheRoom(roomId);
    _evictCacheIfNeeded();
    MessageHistoryPage currentPage() {
      if (!sameAccount()) return empty;
      final live = getMessageSnapshot(roomId);
      return MessageHistoryPage(
        messages: _tail(live, _messagePageSize),
        hasMore: false,
      );
    }

    try {
      final remote = await loadServer();
      if (!sameAccount() || _activeHistoryReads[roomId] != token) {
        return currentPage();
      }
      final local = await loadLocal();
      if (!sameAccount() || _activeHistoryReads[roomId] != token) {
        return currentPage();
      }
      final current = _messageCache[roomId]?.snapshot;
      if (current == null) {
        return currentPage();
      }

      final fromServer = _fillSenderInfo(remote);
      var merged = _mergeMessages(fromServer, local, keepBytesFrom: current);
      var persist = fromServer;
      final beforeIds = {
        for (final message in before) identityHashCode(message),
      };
      final pushed = [
        for (final message in current)
          if (!beforeIds.contains(identityHashCode(message))) message,
      ];
      if (pushed.isNotEmpty) {
        final page = RoomMessageHistory(merged);
        for (final message in pushed) {
          final index = page.indexOfMessage(message);
          if (index == null) {
            page.add(message);
          } else if (!page[index].isDeleted &&
              !(message.mid == null && page[index].mid != null)) {
            page[index] = message;
          }
        }
        merged = page.toList();
        final recalls = {
          for (final m in merged)
            if (m.isDeleted && m.mid != null) m.mid!,
        };
        merged = applyRecallsToMessages(merged, recalls);
        persist = merged;
      }
      merged.sort(_compareMessages);
      final visible = _tail(merged, _messagePageSize);
      if (merged.isNotEmpty) {
        _messageCache[roomId] = RoomMessageHistory(merged);
        _indexMessages(roomId, merged);
      }
      final saved = _localStore.saveMessages(roomId, persist);
      _notifyRoom(roomId);
      _ensureSenderProfiles(merged, roomId);
      await saved;
      if (_activeHistoryReads[roomId] != token || !sameAccount()) {
        return currentPage();
      }
      notifyListeners();
      return MessageHistoryPage(
        messages: visible,
        hasMore:
            remote.length == _messagePageSize ||
            local.length == _messagePageSize,
      );
    } finally {
      if (_activeHistoryReads[roomId] == token) {
        _activeHistoryReads.remove(roomId);
      }
    }
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
    final currentCache = _messageCache[roomId];
    if (currentCache == null) {
      talker.warning(
        'ChatDataService: room $roomId cache evicted during loadOlder, skip',
      );
      return const MessageHistoryPage(messages: [], hasMore: false);
    }
    final merged = _attachOlderMessages(
      currentCache,
      olderFilled,
      localMsgs,
    );

    _messageCache[roomId] = merged is RoomMessageHistory ? merged : RoomMessageHistory(merged);
    _touchCacheRoom(roomId);
    await _localStore.saveMessages(roomId, olderFilled);
    _ensureSenderProfiles(olderFilled, roomId);
    _notifyRoom(roomId);
    if (merged.length != currentCache.length) notifyListeners();
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
