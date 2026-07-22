import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../models/user_profile.dart';
import '../utils/talker.dart';
import '../models/settings_service.dart';
import 'api/tf_api_client.dart';
import 'auth_state.dart';
import 'chat_ws_service.dart';
import 'local_message_store.dart';

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

class ChatNotificationPrompt {
  final String roomId;
  final String roomName;
  final String message;

  const ChatNotificationPrompt({
    required this.roomId,
    required this.roomName,
    required this.message,
  });
}

class ChatDataService extends ChangeNotifier {
  static ChatDataService? _instance;
  static ChatDataService get instance => _instance ??= ChatDataService._();
  ChatDataService._();

  final StreamController<String> _ackErrorController =
      StreamController<String>.broadcast();
  Stream<String> get ackErrorStream => _ackErrorController.stream;
  final StreamController<ChatNotificationPrompt> _notificationPromptController =
      StreamController<ChatNotificationPrompt>.broadcast();
  Stream<ChatNotificationPrompt> get notificationPromptStream =>
      _notificationPromptController.stream;

  List<ChatRoom> _rooms = [];
  List<Contact> _contacts = [];
  final Map<String, List<ChatMessage>> _messageCache = {};
  // LRU 顺序追踪：末尾是最近访问，开头是最久未访问
  final List<String> _cacheAccessOrder = [];
  final Map<String, UserProfile> _userCache = {};
  final Map<String, ChatRoomPreference> _roomPreferences = {};
  bool _isLoading = false;
  StreamSubscription? _wsSubscription;
  final LocalMessageStore _localStore = LocalMessageStore.instance;
  int? _initializedUid;
  int _generation = 0;
  int? _roomPreferencesUid;
  String? _roomPreferencesScope;

  /// 从设置读取消息缓存的最大会话房间数（默认 50）
  int get _maxCachedRooms =>
      SettingsService.instance.getValue<int>('maxCachedRooms', 50);

  /// 将 roomId 标记为最近访问
  void _touchCacheRoom(String roomId) {
    _cacheAccessOrder.remove(roomId);
    _cacheAccessOrder.add(roomId);
  }

  /// 若缓存超出上限，驱逐最久未访问的房间消息
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

  void setMessages(String roomId, List<ChatMessage> msgs) {
    _messageCache[roomId] = msgs;
    _touchCacheRoom(roomId);
    _evictCacheIfNeeded();
    unawaited(_localStore.saveMessages(roomId, msgs));
    notifyListeners();
  }

  UserProfile? getUser(String roomId) => _userCache[roomId];

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
    // Also store under "U{uid}" key for compatibility with roomId-based lookups
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
    await loadContactsAndRooms();
  }

  Future<void> reset() async {
    final generation = ++_generation;
    await _wsSubscription?.cancel();
    if (_generation != generation) return;
    _wsSubscription = null;
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

  /// Parse numeric UID from roomId. "U123" → 123, "G456" → -456.
  static int roomKey(String roomId) {
    if (roomId.startsWith('G')) {
      return -(int.tryParse(roomId.substring(1)) ?? 0);
    }
    if (roomId.startsWith('U')) return int.tryParse(roomId.substring(1)) ?? 0;
    return int.tryParse(roomId) ?? 0;
  }

  static bool isGroupRoom(String roomId) => roomId.startsWith('G');

  String? _senderNameFor(int senderUid) {
    final profile = _userCache[roomIdFromUid(senderUid)];
    return profile?.username;
  }

  String? _senderAvatarFor(int senderUid) {
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

  bool _containsMessage(List<ChatMessage> messages, ChatMessage candidate) {
    final key = _messageDedupKey(candidate);
    return messages.any((message) => _messageDedupKey(message) == key);
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

    _isLoading = true;
    notifyListeners();

    try {
      await _ensureRoomPreferencesLoaded();
      if (_generation != generation || AuthState.instance.uid != uid) return;
      final existingRooms = {for (final room in _rooms) room.id: room};
      talker.info(
        'ChatDataService.loadContactsAndRooms: calling /chat/list for uid=$uid',
      );
      final chatItems = await TfApiClient.instance.queryChatList(uid, password);
      if (_generation != generation || AuthState.instance.uid != uid) return;
      talker.info(
        'ChatDataService.loadContactsAndRooms: got ${chatItems.length} items from server',
      );
      final baseUrl = await TfApiClient.instance.getBaseUrl();
      if (_generation != generation || AuthState.instance.uid != uid) return;

      final nextRooms = <ChatRoom>[];
      final nextContacts = <Contact>[];

      for (final item in chatItems) {
        // 过滤无效项：partnerUid 为负数（非群聊）或等于自己
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
            lastMessage: item.lastContent ?? existingRoom?.lastMessage,
            lastMessageTime: lastTime ?? existingRoom?.lastMessageTime,
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
      if (_generation == generation && AuthState.instance.uid == uid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _onMessageAck(
    String clientMid, {
    int? serverMid,
    required MessageStatus status,
    String? error,
  }) {
    for (final roomId in _messageCache.keys) {
      final msgs = _messageCache[roomId]!;
      final idx = msgs.indexWhere((m) => m.clientMid == clientMid);
      if (idx != -1) {
        final updated = List<ChatMessage>.from(msgs, growable: true);
        updated[idx] = updated[idx].copyWith(
          id: serverMid?.toString() ?? updated[idx].id,
          mid: serverMid ?? updated[idx].mid,
          status: status,
          ackError: error,
          clearAckError: error == null,
        );
        _messageCache[roomId] = updated;
        _localStore.saveMessages(roomId, updated);
        if (status == MessageStatus.failed && error != null) {
          _ackErrorController.add(error);
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
    final result = <ChatMessage>[];
    for (final m in [...server, ...local]) {
      if (seen.add(_messageDedupKey(m))) result.add(m);
    }
    return result;
  }

  // --- Real-time events ---

  void _onWsEvent(ChatWsEvent event) {
    // Server ack: message was stored, update status to sent
    if (event.type == 'message.ack') {
      final data = event.notification;
      if (data != null) {
        final mid = (data['mid'] as num?)?.toInt();
        final clientMid = data['client_mid'] as String?;
        final rawStatus = data['status'] as String? ?? 'sent';
        final status = rawStatus == 'failed'
            ? MessageStatus.failed
            : MessageStatus.sent;
        final error = data['error'] as String?;
        if (clientMid != null) {
          _onMessageAck(
            clientMid,
            serverMid: mid,
            status: status,
            error: error,
          );
        }
      }
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
        eventType == 'group.member.removed' ||
        eventType == 'group.deleted') {
      loadContactsAndRooms();
      return;
    }
    if (eventType != 'message.plain' && eventType != 'message.file') return;

    final uid = AuthState.instance.uid;
    if (uid == null) return;
    final senderUid = info.senderUid;
    if (senderUid == null) return;

    final roomId = _roomIdForNotification(info, uid);
    final msg = ChatMessage.fromNotification(
      notification: info,
      myUid: uid,
      senderName: _senderNameFor(senderUid),
      senderAvatar: _senderAvatarFor(senderUid),
    );
    _addToCache(roomId, msg);
  }

  void processPolledMessage(
    NotificationInfo info, {
    bool isHistorical = false,
  }) {
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    final senderUid = info.senderUid;
    if (senderUid == null) return;

    final roomId = _roomIdForNotification(info, uid);
    final msg = ChatMessage.fromNotification(
      notification: info,
      myUid: uid,
      senderName: _senderNameFor(senderUid),
      senderAvatar: _senderAvatarFor(senderUid),
    );
    if (isHistorical) {
      _addToCacheSilent(roomId, msg);
    } else {
      _addToCache(roomId, msg);
    }
  }

  void _addToCacheSilent(String roomId, ChatMessage msg) {
    final cached = List<ChatMessage>.from(_messageCache[roomId] ?? []);
    final exists = _containsMessage(cached, msg);
    if (!exists) {
      cached.add(msg);
      cached.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _messageCache[roomId] = cached;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
      _localStore.appendMessage(roomId, msg);
    }
    // Don't bump unread for historical polled messages
    if (!_rooms.any((r) => r.id == roomId)) {
      _addNewRoom(roomId, msg, unreadCount: 0);
    } else {
      final idx = _rooms.indexWhere((r) => r.id == roomId);
      final lastTime = _rooms[idx].lastMessageTime;
      if (lastTime == null || msg.timestamp.isAfter(lastTime)) {
        _rooms[idx] = _rooms[idx].copyWith(
          lastMessage: msg.text,
          lastMessageTime: msg.timestamp,
        );
      }
    }
    _sortRooms();
    notifyListeners();
  }

  String _roomIdForNotification(NotificationInfo info, int myUid) {
    if (info.roomId != null && info.roomId!.isNotEmpty) return info.roomId!;
    if (info.groupId != null) return 'G${info.groupId}';
    return roomIdFromUid(info.senderUid ?? myUid);
  }

  void _addToCache(String roomId, ChatMessage msg) {
    final cached = List<ChatMessage>.from(_messageCache[roomId] ?? []);
    final exists = _containsMessage(cached, msg);
    if (!exists) {
      cached.add(msg);
      cached.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _messageCache[roomId] = cached;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
      _localStore.appendMessage(roomId, msg);
    }
    if (exists) return;

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
        unreadCount: shouldNotify
            ? _rooms[idx].unreadCount + 1
            : _rooms[idx].unreadCount,
      );
    } else {
      _addNewRoom(roomId, msg, unreadCount: shouldNotify ? 1 : 0);
    }
    _sortRooms();
    notifyListeners();
    if (shouldNotify && _shouldShowInAppPrompt(roomId)) {
      final room = _rooms.firstWhere((room) => room.id == roomId);
      _notificationPromptController.add(
        ChatNotificationPrompt(
          roomId: roomId,
          roomName: room.name,
          message: msg.text,
        ),
      );
    }
  }

  bool _shouldShowInAppPrompt(String roomId) {
    final settings = SettingsService.instance;
    if (!settings.getValue<bool>('inAppNotifications', true)) return false;
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
      // Note: profile.uid is plain "123", but our cache uses "U123"
      // Store under both keys for compatibility
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
      if (!m.isMe && m.senderUid == senderUid && m.senderAvatar == null) {
        changed = true;
        return m.copyWith(senderName: username, senderAvatar: avatar);
      }
      return m;
    }).toList();
    if (changed) {
      _messageCache[roomId] = updated;
      _localStore.saveMessages(roomId, updated);
    }
  }

  void addSentMessage(String roomId, ChatMessage msg) {
    final cached = List<ChatMessage>.from(_messageCache[roomId] ?? []);
    if (!_containsMessage(cached, msg)) {
      cached.add(msg);
      cached.sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
    _sortRooms();
    notifyListeners();
  }

  void clearUnread(String roomId) {
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx >= 0 && _rooms[idx].unreadCount > 0) {
      _rooms[idx] = _rooms[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  Future<void> removeRoom(String roomId) async {
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

  Future<List<ChatMessage>> refreshMessagesForContact(String roomId) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return [];
    final generation = _generation;

    final rk = roomKey(roomId);
    final serverMsgs = await TfApiClient.instance.queryMessageHistory(
      uid,
      password,
      rk > 0 ? rk : 0,
      groupId: rk < 0 ? -rk : null,
      limit: 50,
    );
    if (_generation != generation || AuthState.instance.uid != uid) return [];

    final serverFilled = _fillSenderInfo(serverMsgs);
    final localMsgs = await _localStore.loadMessages(roomId);
    if (_generation != generation || AuthState.instance.uid != uid) return [];
    final merged = _mergeMessages(serverFilled, localMsgs);
    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (merged.isNotEmpty || !_messageCache.containsKey(roomId)) {
      _messageCache[roomId] = merged;
      _touchCacheRoom(roomId);
      _evictCacheIfNeeded();
    }
    await _localStore.saveMessages(roomId, merged);
    notifyListeners();
    return merged;
  }

  Future<List<ChatMessage>> loadOlderMessages(String roomId) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return [];
    final generation = _generation;

    final cached = _messageCache[roomId] ?? [];
    if (cached.isEmpty) return [];

    int? oldestMid;
    for (final m in cached) {
      if (m.mid != null && (oldestMid == null || m.mid! < oldestMid)) {
        oldestMid = m.mid;
      }
    }
    if (oldestMid == null) return [];

    final rk = roomKey(roomId);
    final olderMsgs = await TfApiClient.instance.queryMessageHistory(
      uid,
      password,
      rk > 0 ? rk : 0,
      groupId: rk < 0 ? -rk : null,
      beforeMid: oldestMid,
      limit: 50,
    );
    if (_generation != generation || AuthState.instance.uid != uid) return [];
    if (olderMsgs.isEmpty) return [];

    final olderFilled = _fillSenderInfo(olderMsgs);
    final merged = _mergeMessages(olderFilled, cached);
    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _messageCache[roomId] = merged;
    _touchCacheRoom(roomId);
    await _localStore.saveMessages(roomId, merged);
    notifyListeners();
    return merged;
  }

  List<ChatMessage> _fillSenderInfo(List<ChatMessage> msgs) {
    return msgs.map((m) {
      if (m.isMe) return m;
      final suid = m.senderUid;
      if (suid == null) return m;
      final name = m.senderName ?? _senderNameFor(suid);
      final avatar = m.senderAvatar ?? _senderAvatarFor(suid);
      return m.copyWith(senderName: name, senderAvatar: avatar);
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
    _notificationPromptController.close();
    super.dispose();
  }
}
