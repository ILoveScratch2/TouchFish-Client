import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' show lookupMimeType;
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/settings_service.dart';
import '../models/user_profile.dart';
import '../widgets/message_bubble.dart';
import '../widgets/media/image_lightbox.dart';
import '../widgets/chat_input_bar.dart';
import '../routes/app_routes.dart';
import '../l10n/app_localizations.dart';
import '../widgets/mention_text_field.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../services/chat_ws_service.dart';
import '../services/chat_data_service.dart';
import '../services/draft_service.dart';
import '../services/local_message_store.dart';
import '../services/message_sync_service.dart';
import '../services/notification_service.dart';
import '../utils/talker.dart';
import 'chat_room_settings_screen.dart';
import 'group_essence_screen.dart';
import '../widgets/pinned_messages_sheet.dart';
import '../widgets/sync_indicator.dart';

class ChatDetailScreen extends StatefulWidget {
  final String roomId;

  const ChatDetailScreen({super.key, required this.roomId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  /// 当前聊天按时间序的图片画廊条目（灯箱多图用）。消息超过 [_galleryCap] 时
  /// 清空并退化为单图模式，限制重建开销。
  final List<LightboxImageItem> _imageEntries = [];
  final Map<String, int> _imageIndexById = {};
  static const int _galleryCap = 3000;

  final Map<int, GlobalKey> _messageKeys = {};
  final Map<String, Timer> _pendingWsTimers = {};

  /// clientMids that already went through the REST fallback, to avoid
  /// re-sending the same message twice.
  final Set<String> _restFallbackAttempted = {};
  ChatRoom? _currentRoom;
  final List<MentionUser> _mentionUsers = [];
  bool _isInitialized = false;
  bool _wsConnected = false;
  bool _avatarLoadFailed = false;
  bool _isLoadingOlder = false;
  bool _isLoadingMessages = false;
  bool _hasMoreMessages = true;
  bool _realtimeListenersAttached = false;
  StreamSubscription? _ackErrorSub;
  String _groupEnterHint = '';
  bool _showGroupEnterHint = true;
  bool _followBottom = true;
  bool _showBackToBottom = false;
  ChatMessage? _replyingTo;
  ChatMessage? _forwardingTo;
  bool _canModerateGroup = false;
  Timer? _draftTimer;
  bool _suppressDraftSave = false;
  int _roomGeneration = 0;
  List<PinnedMessage> _pinnedMessages = [];
  final Map<int, ChatMessage?> _pinnedMessageContents = {};
  int _pinCurrentPage = 0;
  final GlobalKey _pinnedBarKey = GlobalKey();
  List<int> _essenceMids = [];
  bool _essenceEnabled = true;
  String? _fetchingEssenceRoomId;
  StreamSubscription<int>? _essenceSub;
  bool _fetchingPins = false;
  bool _isJumpingToMessage = false;
  Timer? _weakNetworkTimer;

  String get _contactUid {
    final id = widget.roomId;
    if (id.startsWith('U') || id.startsWith('G')) return id;
    // 修复 dev ID，应该用不着了
    final parsed = int.tryParse(id);
    if (parsed != null) return 'U$parsed';
    return id;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_scheduleDraftSave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initRoom();
      _isInitialized = true;
    }
  }

  @override
  void didUpdateWidget(covariant ChatDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _draftTimer?.cancel();
      unawaited(_saveDraftForRoom(oldWidget.roomId));
      _initRoom();
    }
  }

  void _initRoom() {
    _roomGeneration++;
    for (final timer in _pendingWsTimers.values) {
      timer.cancel();
    }
    _pendingWsTimers.clear();
    _restFallbackAttempted.clear();
    _messageKeys.clear();
    _messages.clear();
    _rebuildImageEntries();
    _currentRoom = null;
    _avatarLoadFailed = false;
    _isLoadingOlder = false;
    _isLoadingMessages = false;
    _hasMoreMessages = true;
    _isJumpingToMessage = false;
    _groupEnterHint = '';
    _showGroupEnterHint = true;
    _followBottom = true;
    _showBackToBottom = false;
    _replyingTo = null;
    _canModerateGroup = false;
    _essenceMids = [];
    _essenceEnabled = true;
    _fetchingEssenceRoomId = null;
    _suppressDraftSave = true;
    _messageController.clear();
    _suppressDraftSave = false;
    unawaited(_restoreDraft(_contactUid));
    // 进入/切换聊天时立即清除该房间的未读计数：
    //   - 聊天列表中该会话右侧的角标消失
    //   - 导航栏/侧边栏右上角的总计数（totalUnreadCount 动态求和）相应减去
    // _markVisibleMessagesRead 仍负责后续新消息到达且可见时再清零并发送已读回执。
    ChatDataService.instance.clearUnread(_contactUid);
    _loadChatRoom();
    _startRealMessaging();
    _initMessageSync();
    _weakNetworkTimer?.cancel();
    if (SettingsService.instance.getValue<bool>('weakNetworkMode', false)) {
      _weakNetworkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(MessageSyncService.instance.resyncAfterReconnect([_contactUid]));
      });
    }
  }

  /// 进入/切换聊天时：注册为同步活跃房间，触发增量补
  void _initMessageSync() {
    final roomId = _contactUid;
    MessageSyncService.instance.activeRoomId = roomId;
    unawaited(_syncRoomIfNeeded(roomId));
  }

  Future<void> _syncRoomIfNeeded(String roomId) async {
    final syncService = MessageSyncService.instance;
    if (syncService.lastSeqOf(roomId) != null) {
      final settings = SettingsService.instance;
      final forceExplicit = settings.getValue<bool>('forceExplicitSync', false);
      final cooldownSeconds =
          int.tryParse(
            settings.getValue<String>('explicitSyncCooldownSeconds', '30'),
          ) ??
          30;
      final cooldown = Duration(seconds: cooldownSeconds);
      if (forceExplicit ||
          syncService.hasPendingGapsFor(roomId) ||
          !syncService.isWithinSyncCooldown(roomId, cooldown)) {
        syncService.recordEntrySync(roomId);
        await syncService.resyncAfterReconnect();
      } else {
        await syncService.silentSyncRoom(roomId);
      }
      return;
    }
    // 无序号基线：用本地迁移的 last_mid 或房间列表 last_mid 建立同步点后再补拉
    final syncMid =
        await LocalMessageStore.instance.getRoomSyncMid(roomId) ??
        ChatDataService.instance.rooms
            .where((room) => room.id == roomId)
            .map((room) => room.lastMessageMid)
            .firstWhere((mid) => mid != null, orElse: () => null);
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    try {
      if (syncMid != null && syncMid > 0) {
        await syncService.syncRoomFromMid(roomId, syncMid);
      } else {
        await syncService.establishBaseline(roomId);
      }
    } catch (e, stack) {
      talker.error('ChatDetailScreen sync init failed for $roomId', e, stack);
    }
  }

  @override
  void dispose() {
    for (final timer in _pendingWsTimers.values) {
      timer.cancel();
    }
    _pendingWsTimers.clear();
    _restFallbackAttempted.clear();
    if (MessageSyncService.instance.activeRoomId == _contactUid) {
      MessageSyncService.instance.activeRoomId = null;
    }
    _detachRealtimeListeners();
    _ackErrorSub?.cancel();
    _essenceSub?.cancel();
    _draftTimer?.cancel();
    _weakNetworkTimer?.cancel();
    unawaited(_saveDraft());
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleDraftSave() {
    if (_suppressDraftSave) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  Future<void> _restoreDraft(String roomId) async {
    final draft = await DraftService.instance.loadDraft('chat', roomId);
    if (!mounted ||
        _contactUid != roomId ||
        _messageController.text.isNotEmpty) {
      return;
    }
    final text = draft?['text'] as String? ?? '';
    if (text.isNotEmpty) _messageController.text = text;
  }

  Future<void> _saveDraft() => DraftService.instance.saveDraft(
    'chat',
    _contactUid,
    {'text': _messageController.text},
  );

  Future<void> _saveDraftForRoom(String roomId) => DraftService.instance
      .saveDraft('chat', roomId, {'text': _messageController.text});

  void _onAckError(({String clientMid, String error}) info) {
    if (!mounted) return;

    // WS ack rejected the message. Some servers reject the WS `message.file`
    // ownership check even though the file is owned by the sender (REST
    // `/message/send` works). For file/media messages, retry immediately via
    // REST using the same client_mid — the server dedups, so no duplicates.
    // The failure snackbar is only shown if the REST retry also fails.
    final msgs = ChatDataService.instance.getMessages(_contactUid);
    final idx = msgs.indexWhere((m) => m.clientMid == info.clientMid);
    if (idx != -1 && msgs[idx].media != null) {
      final media = msgs[idx].media!;
      unawaited(
        _wsAckFallback(
          clientMid: info.clientMid,
          content: media.fileHash ?? media.path,
          contentType: 'file',
          fileHash: media.fileHash,
          quoteMid: msgs[idx].quoteMid ?? -1,
          forwardedMid: -1,
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final msg = switch (info.error) {
      'banned' => l10n.chatSendFailedBanned,
      'rate_limited' => l10n.chatSendFailedRateLimited,
      'not_friends' => l10n.chatSendFailedNotFriends,
      'not_group_member' => l10n.chatSendFailedNotGroupMember,
      'message_too_long' => l10n.chatSendFailedTooLong,
      _ => l10n.chatSendFailed,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _attachRealtimeListeners() {
    if (_realtimeListenersAttached) return;
    ChatWsService.instance.addListener(_onWsStateChanged);
    ChatDataService.instance.addListener(_onChatDataChanged);
    _essenceSub = NotificationService.instance.essenceChanges.listen(
      _onEssenceChanged,
    );
    _realtimeListenersAttached = true;
  }

  void _detachRealtimeListeners() {
    if (!_realtimeListenersAttached) return;
    ChatWsService.instance.removeListener(_onWsStateChanged);
    ChatDataService.instance.removeListener(_onChatDataChanged);
    _essenceSub?.cancel();
    _essenceSub = null;
    _realtimeListenersAttached = false;
  }

  bool get _isRoomSyncing =>
      MessageSyncService.instance.isSyncingFor(_contactUid);

  String? get _syncHint {
    final sync = MessageSyncService.instance;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return null;
    if (_isRoomSyncing) {
      final count = sync.syncedCountFor(_contactUid);
      if (count > 0) {
        return l10n.chatSyncHistoryProgress(
          count,
          sync.batchRoundFor(_contactUid),
        );
      }
      return l10n.chatSyncHistory;
    }
    if (sync.syncJustCompletedFor(_contactUid)) {
      return l10n.chatSyncComplete(sync.syncedCountFor(_contactUid));
    }
    return null;
  }

  void _startRealMessaging() {
    if (!AuthState.instance.isLoggedIn) return;

    final ws = ChatWsService.instance;
    _wsConnected = ws.isAuthenticated;
    _attachRealtimeListeners();
    if (!ws.isAuthenticated) ws.connect();

    _ackErrorSub?.cancel();
    _ackErrorSub = ChatDataService.instance.ackErrorStream.listen(_onAckError);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadAndShowMessages();
    });
  }

  void _markVisibleMessagesRead({String? previousLastId}) {
    if (_messages.isEmpty) return;
    final lastMsg = _messages.last;
    final hasNewVisibleTail =
        previousLastId == null || lastMsg.id != previousLastId;
    if (!hasNewVisibleTail || lastMsg.isMe || lastMsg.mid == null) return;
    ChatDataService.instance.clearUnread(_contactUid);
    if (_wsConnected) {
      ChatWsService.instance.sendReadReceipt(_contactUid, lastMsg.mid!);
    }
  }

  Future<void> _loadAndShowMessages() async {
    if (_isLoadingMessages || _isLoadingOlder) return;
    final chatData = ChatDataService.instance;
    final roomId = _contactUid;
    final roomGeneration = _roomGeneration;

    // 先同步展示本地缓存，切房间立即有内容，网络刷新在后台完成。
    final cached = chatData.getMessages(roomId);
    if (cached.isNotEmpty && _messages.isEmpty) {
      setState(() {
        _messages.addAll(cached);
        _rebuildImageEntries();
      });
      _followBottom = true;
    }
    setState(() => _isLoadingMessages = true);

    final page = await chatData.refreshMessagesForContact(roomId);
    if (!mounted ||
        roomGeneration != _roomGeneration ||
        roomId != _contactUid) {
      return;
    }
    _refreshRoom();

    setState(() {
      _messages.clear();
      _messages.addAll(chatData.getMessages(roomId));
      _rebuildImageEntries();
      _isLoadingMessages = false;
      _hasMoreMessages = page.hasMore;
    });
    _followBottom = true;
    _markVisibleMessagesRead();
  }

  Future<void> _onRefresh() async {
    await _loadAndShowMessages();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final showBackToBottom = !_isNearBottom;
    if (_showBackToBottom != showBackToBottom && mounted) {
      setState(() => _showBackToBottom = showBackToBottom);
    }
    if (_isAtBottom) _followBottom = true;

    _updatePinnedPageFromScroll();

    // 跳转过程中禁用自动加载更早消息，避免打断跳转
    if (_isJumpingToMessage ||
        _isLoadingMessages ||
        _isLoadingOlder ||
        !_hasMoreMessages) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent > 0 &&
        position.pixels > position.maxScrollExtent - 50) {
      _loadOlder();
    }
  }

  void _updatePinnedPageFromScroll() {
    if (_pinnedMessages.length <= 1 || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0 || _messages.length <= 1) return;

    // reverse:true 列表中 index=0 为最新消息，pixels=0 为底部（最新），pixels=max 为顶部（最旧）。
    // 因此消息在滚动坐标中的近似位置与其列表 index 同向，而不是反向。
    //
    // 策略：
    //   前方 pin（itemPosition >= pixels，尚未滑过）→ 取最新（msgIndex 最小）显示
    //   后方 pin（itemPosition < pixels，已滑过） → 取最旧（msgIndex 最大）显示
    //   优先显示前方最新 pin；全部已滑过则停在最旧 pin
    final total = _messages.length;
    final extentPerItem = position.maxScrollExtent / (total - 1);
    final viewportTop = position.pixels;

    int? aheadPage; // 前方 pin 中 msgIndex 最小的（最新）
    int aheadMsgIndex = total;
    int? behindPage; // 后方 pin 中 msgIndex 最大的（最旧）
    int behindMsgIndex = -1;

    for (int i = 0; i < _pinnedMessages.length; i++) {
      final msgIndex = _messages.indexWhere(
        (m) => m.mid == _pinnedMessages[i].messageId,
      );
      if (msgIndex < 0) continue;

      final itemPosition = msgIndex * extentPerItem;

      if (itemPosition >= viewportTop) {
        // 前方（尚未滑过）→ 取最新
        if (msgIndex < aheadMsgIndex) {
          aheadMsgIndex = msgIndex;
          aheadPage = i;
        }
      } else {
        // 后方（已滑过）→ 取最旧
        if (msgIndex > behindMsgIndex) {
          behindMsgIndex = msgIndex;
          behindPage = i;
        }
      }
    }

    final page = aheadPage ?? behindPage ?? 0;
    if (page != _pinCurrentPage && mounted) {
      setState(() => _pinCurrentPage = page);
    }
  }

  bool _onUserScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _followBottom = false;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _followBottom = false;
    } else if (notification is ScrollEndNotification && _isAtBottom) {
      _followBottom = true;
    }
    return false;
  }

  bool _onScrollMetricsChanged(ScrollMetricsNotification notification) {
    // 跳转过程中忽略“跟随底部”自动回底，防止把跳转顶回底部
    if (_followBottom && !_isJumpingToMessage) {
      _scrollToBottom(animated: false);
    }
    return false;
  }

  Future<void> _loadOlder() async {
    if (_isLoadingMessages || _isLoadingOlder || !_hasMoreMessages) return;

    setState(() => _isLoadingOlder = true);
    final roomId = _contactUid;
    final roomGeneration = _roomGeneration;
    final chatData = ChatDataService.instance;
    final page = await chatData.loadOlderMessages(roomId);

    if (!mounted ||
        roomGeneration != _roomGeneration ||
        roomId != _contactUid) {
      return;
    }
    setState(() {
      _messages.clear();
      _messages.addAll(chatData.getMessages(roomId));
      _rebuildImageEntries();
      _isLoadingOlder = false;
      _hasMoreMessages = page.hasMore;
    });
  }

  void _refreshRoom() {
    final chatData = ChatDataService.instance;
    final profile = chatData.getUser(_contactUid);
    if (profile != null) {
      final updated = ChatRoom(
        id: _contactUid,
        name: chatData.displayNameForRoom(_contactUid, profile.username),
        avatar: profile.avatar,
        type: _currentRoom?.type ?? ChatType.direct,
      );
      if (_currentRoom?.name != updated.name ||
          _currentRoom?.avatar != updated.avatar) {
        _avatarLoadFailed = false;
        _currentRoom = updated;
        if (mounted) setState(() {});
      }
    } else if (!_contactUid.startsWith('G')) {
      final targetUid = _contactUid.startsWith('U')
          ? int.tryParse(_contactUid.substring(1))
          : null;
      if (targetUid != null) {
        TfApiClient.instance.getUserByUid(targetUid).then((p) {
          if (p != null && mounted) {
            talker.info(
              'ChatDetail: refreshRoom fetched uid=${p.uid} avatar=${p.avatar}',
            );
            chatData.cacheUserProfile(p);
            _avatarLoadFailed = false;
            setState(() {
              _currentRoom = ChatRoom(
                id: _contactUid,
                name: chatData.displayNameForRoom(_contactUid, p.username),
                avatar: p.avatar,
                type: _contactUid.startsWith('G')
                    ? ChatType.group
                    : ChatType.direct,
              );
            });
          }
        });
      }
    }
  }

  void _onWsStateChanged() {
    if (!mounted) return;
    setState(() => _wsConnected = ChatWsService.instance.isAuthenticated);
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.pixels <= pos.minScrollExtent + 100;
  }

  bool get _isAtBottom {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.pixels <= pos.minScrollExtent + 1;
  }

  void _onChatDataChanged() {
    if (!mounted) return;
    // 跳转过程中完全忽略实时数据变动，避免：
    //  1) 新消息触发 _scrollToBottom 把跳转顶回底部
    //  2) 列表被替换导致按 index 的分段跳转失效
    if (_isJumpingToMessage) return;
    _refreshRoom();
    final cached = ChatDataService.instance.getMessages(_contactUid);
    final previousLastId = _messages.isNotEmpty ? _messages.last.id : null;
    final countChanged = cached.length != _messages.length;
    final lastIdChanged = cached.isNotEmpty && cached.last.id != previousLastId;
    final wasNearBottom = _isNearBottom;
    // 未读角标、房间列表等无关通知不重建消息列表（ChatMessage 不可变，
    // 引用逐一相同说明缓存内容没变）。
    if (countChanged || lastIdChanged || !_sameMessageRefs(cached)) {
      setState(() {
        _messages.clear();
        _messages.addAll(cached);
        _rebuildImageEntries();
      });
    }
    if ((countChanged || lastIdChanged) && wasNearBottom) {
      _scrollToBottom();
    }
    if (countChanged || lastIdChanged) {
      _markVisibleMessagesRead(previousLastId: previousLastId);
    }
    if (_currentRoom?.type == ChatType.group) {
      unawaited(_fetchPinnedMessages());
      unawaited(_fetchEssenceMessages());
    }
  }

  bool _sameMessageRefs(List<ChatMessage> cached) {
    if (cached.length != _messages.length) return false;
    for (var i = 0; i < cached.length; i++) {
      if (!identical(cached[i], _messages[i])) return false;
    }
    return true;
  }

  void _loadChatRoom() {
    final chatData = ChatDataService.instance;
    final profile = chatData.getUser(_contactUid);
    _mentionUsers.clear();
    _pinnedMessages.clear();
    _pinnedMessageContents.clear();
    _pinCurrentPage = 0;
    _fetchingPins = false;
    if (profile != null && _contactUid.startsWith('U')) {
      _mentionUsers.add(
        MentionUser(
          id: profile.uid.replaceFirst('U', ''),
          username: profile.username,
          avatarUrl: profile.avatar,
        ),
      );
    }

    _currentRoom = ChatRoom(
      id: _contactUid,
      name: chatData.displayNameForRoom(
        _contactUid,
        profile?.username ??
            (_contactUid.startsWith('G')
                ? 'Group ${_contactUid.substring(1)}'
                : _contactUid),
      ),
      avatar: profile?.avatar,
      type: _contactUid.startsWith('G') ? ChatType.group : ChatType.direct,
    );
    _avatarLoadFailed = false;
    setState(() {});

    final targetUid = _contactUid.startsWith('U')
        ? int.tryParse(_contactUid.substring(1))
        : null;
    if (targetUid != null) {
      TfApiClient.instance.getUserByUid(targetUid).then((p) {
        if (p != null && mounted) {
          talker.info(
            'ChatDetail: fetched profile uid=${p.uid} avatar=${p.avatar}',
          );
          chatData.cacheUserProfile(p);
          _mentionUsers
            ..clear()
            ..add(
              MentionUser(id: p.uid, username: p.username, avatarUrl: p.avatar),
            );
          _avatarLoadFailed = false;
          setState(() {
            _currentRoom = ChatRoom(
              id: _contactUid,
              name: chatData.displayNameForRoom(_contactUid, p.username),
              avatar: p.avatar,
              type: _contactUid.startsWith('G')
                  ? ChatType.group
                  : ChatType.direct,
            );
          });
        }
      });
    } else if (_contactUid.startsWith('G')) {
      unawaited(_loadMentionUsers());
      unawaited(_fetchEssenceMessages());
    }
  }

  Future<void> _loadMentionUsers() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(_contactUid.substring(1));
    if (uid == null || password == null || gid == null) return;

    final result = await TfApiClient.instance.getGroupMembers(
      uid,
      password,
      gid,
    );
    final members = result?['members'] as List<dynamic>?;
    if (members == null) return;
    final settings = result?['settings'] as Map<String, dynamic>?;
    final enterHint = settings?['enter_hint'] as String? ?? '';
    final normalizedEnterHint = enterHint.trim();
    final showEnterHint =
        normalizedEnterHint.isNotEmpty &&
        !await DraftService.instance.isAcknowledged(
          'group_enter_hint',
          gid.toString(),
          normalizedEnterHint,
        );
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    final chatData = ChatDataService.instance;
    for (final raw in members) {
      final member = Map<String, dynamic>.from(raw as Map);
      final memberUid = (member['uid'] as num).toInt();
      if (memberUid == uid) continue;
      chatData.cacheUserProfile(
        UserProfile(
          uid: 'U$memberUid',
          username: member['username'] as String? ?? 'User $memberUid',
          email: '',
          stat: 'user',
          createTime: '0',
          avatar: '$baseUrl/avatar/get_avatar/user/$memberUid',
        ),
      );
    }
    final mentionUsers = members
        .map((raw) {
          final member = Map<String, dynamic>.from(raw as Map);
          final memberUid = (member['uid'] as num).toInt();
          return MentionUser(
            id: memberUid.toString(),
            username: member['username'] as String? ?? 'User $memberUid',
            avatarUrl: '$baseUrl/avatar/get_avatar/user/$memberUid',
          );
        })
        .where((member) => member.id != uid.toString())
        .toList();
    final currentMember = members.cast<dynamic>().firstWhere(
      (raw) => raw is Map && (raw['uid'] as num?)?.toInt() == uid,
      orElse: () => null,
    );
    final currentRole = currentMember is Map
        ? currentMember['role']?.toString().toLowerCase()
        : null;
    if (!mounted || _contactUid != 'G$gid') return;
    setState(() {
      _mentionUsers
        ..clear()
        ..addAll(mentionUsers);
      _groupEnterHint = normalizedEnterHint;
      _showGroupEnterHint = showEnterHint;
      _canModerateGroup = currentRole == 'owner' || currentRole == 'admin';
    });
    unawaited(_fetchPinnedMessages());
  }

  void _startReply(ChatMessage message) {
    if (message.mid == null || message.isDeleted) return;
    setState(() {
      _replyingTo = message;
      _forwardingTo = null;
    });
  }

  void _startForward(ChatMessage message) {
    if (message.mid == null || message.isDeleted) return;
    // 打开转发选择屏幕（右键转发 / 悬浮转发按钮都会触发）
    context.push(AppRoutes.forward, extra: message);
  }

  bool _canRecall(ChatMessage message) {
    if (message.mid == null || message.isDeleted) return false;
    if (message.isMe) return true;
    if (AuthState.instance.currentUser?.hasAdminAccess == true) return true;
    return _currentRoom?.type == ChatType.group && _canModerateGroup;
  }

  Future<void> _recallMessage(ChatMessage message) async {
    if (!_canRecall(message)) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.messageRecallConfirmTitle),
        content: Text(l10n.messageRecallConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.messageActionRecall),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final mid = message.mid;
    if (uid == null || password == null || mid == null) return;
    final recalled = await TfApiClient.instance.recallMessage(
      uid,
      password,
      mid,
    );
    if (!mounted) return;
    if (recalled != null) {
      final deletedAtRaw = recalled['deleted_at'];
      final deletedAt = deletedAtRaw is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (deletedAtRaw.toDouble() * 1000).toInt(),
            )
          : DateTime.tryParse(deletedAtRaw?.toString() ?? '');
      ChatDataService.instance.markMessageRecalled(
        mid,
        roomId: _contactUid,
        deletedAt: deletedAt,
        deletedBy: (recalled['deleted_by'] as num?)?.toInt() ?? uid,
      );
      if (_replyingTo?.mid == mid) setState(() => _replyingTo = null);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.messageRecallFailed)));
    }
  }

  Future<void> _fetchEssenceMessages() async {
    final roomId = _contactUid;
    if (!roomId.startsWith('G') || _fetchingEssenceRoomId == roomId) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(roomId.substring(1));
    if (uid == null || password == null || gid == null) return;

    _fetchingEssenceRoomId = roomId;
    try {
      final result = await TfApiClient.instance.queryEssence(
        uid,
        password,
        gid,
      );
      if (mounted && roomId == _contactUid && result != null) {
        setState(() {
          _essenceMids = result.mids;
          _essenceEnabled = result.essenceEnabled;
        });
      }
    } finally {
      if (_fetchingEssenceRoomId == roomId) {
        _fetchingEssenceRoomId = null;
      }
    }
  }

  Future<void> _fetchPinnedMessages() async {
    if (_fetchingPins) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(_contactUid.substring(1));
    if (uid == null || password == null || gid == null) return;

    _fetchingPins = true;
    try {
      final pins = await TfApiClient.instance.getPinnedMessages(
        uid,
        password,
        gid,
      );
      if (!mounted) return;
      final currentMessageId =
          _pinnedMessages.isNotEmpty &&
              _pinCurrentPage >= 0 &&
              _pinCurrentPage < _pinnedMessages.length
          ? _pinnedMessages[_pinCurrentPage].messageId
          : null;
      setState(() {
        _pinnedMessages = pins;
        if (pins.isNotEmpty) {
          final retainedPage = currentMessageId == null
              ? -1
              : pins.indexWhere((pin) => pin.messageId == currentMessageId);
          _pinCurrentPage = retainedPage >= 0 ? retainedPage : pins.length - 1;
        } else {
          _pinCurrentPage = 0;
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updatePinnedPageFromScroll();
      });
    } catch (_) {
      // server eror 不能一直 retry 啦
    } finally {
      _fetchingPins = false;
    }
  }

  Future<void> _toggleEssence(ChatMessage message) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(_contactUid.substring(1));
    final mid = message.mid;
    if (uid == null || password == null || gid == null || mid == null) return;
    if (_essenceMids.contains(mid)) {
      final ok = await TfApiClient.instance.removeEssence(
        uid,
        password,
        gid,
        mid,
      );
      if (ok && mounted && _contactUid == 'G$gid') {
        setState(() {
          _essenceMids.remove(mid);
        });
      } else if (!ok && mounted) {
        _showEssenceOperationFailed();
      }
    } else {
      final ok = await TfApiClient.instance.addEssence(uid, password, gid, mid);
      if (ok && mounted && _contactUid == 'G$gid') {
        setState(() {
          if (!_essenceMids.contains(mid)) _essenceMids.add(mid);
        });
      } else if (!ok && mounted) {
        _showEssenceOperationFailed();
      }
    }
  }

  void _showEssenceOperationFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.commonFailedOperation),
      ),
    );
  }

  Future<void> _togglePin(ChatMessage message) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(_contactUid.substring(1));
    final mid = message.mid;
    if (uid == null || password == null || gid == null || mid == null) return;

    final existingPin = _pinnedMessages.cast<PinnedMessage?>().firstWhere(
      (p) => p?.messageId == mid,
      orElse: () => null,
    );

    if (existingPin != null) {
      final ok = await TfApiClient.instance.unpinMessage(
        uid,
        password,
        gid,
        existingPin.pinId,
      );
      if (ok && mounted) {
        setState(() {
          _pinnedMessages.removeWhere((p) => p.pinId == existingPin.pinId);
        });
      }
    } else {
      final ok = await TfApiClient.instance.pinMessage(uid, password, gid, mid);
      if (ok && mounted) {
        unawaited(_fetchPinnedMessages());
      }
    }
  }

  void _sendMessage() {
    unawaited(_sendMessageAsync());
  }

  Future<void> _sendMessageAsync() async {
    final text = _messageController.text.trim();
    final forwardTarget = _forwardingTo;
    if (text.isEmpty && forwardTarget == null) return;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final replyTarget = _replyingTo;
    final quoteMid = replyTarget?.mid ?? -1;
    final forwardedMid = forwardTarget?.mid ?? -1;
    final outgoingText = forwardTarget?.text ?? text;
    final outgoingType = forwardTarget?.type ?? MessageType.text;

    final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
    final userMessage = ChatMessage(
      id: clientMid,
      clientMid: clientMid,
      senderUid: uid,
      mid: null,
      text: outgoingText,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.pending,
      type: outgoingType,
      media: forwardTarget?.media,
      quoteMid: quoteMid >= 0 ? quoteMid : null,
      quotePreview: replyTarget == null
          ? null
          : QuotedMessagePreview(
              mid: replyTarget.mid,
              senderUid: replyTarget.senderUid,
              senderName: replyTarget.isMe
                  ? AuthState.instance.currentUser?.username
                  : replyTarget.senderName,
              content: replyTarget.text,
              contentType: replyTarget.type == MessageType.file
                  ? 'file'
                  : 'plain',
              isDeleted: replyTarget.isDeleted,
            ),
      forwardedMid: forwardedMid >= 0 ? forwardedMid : null,
      forwardPreview: forwardTarget == null
          ? null
          : QuotedMessagePreview(
              mid: forwardTarget.mid,
              senderUid: forwardTarget.senderUid,
              senderName: forwardTarget.isMe
                  ? AuthState.instance.currentUser?.username
                  : forwardTarget.senderName,
              content: forwardTarget.text,
              contentType: forwardTarget.type == MessageType.file
                  ? 'file'
                  : 'plain',
            ),
    );

    setState(() {
      _messages.add(userMessage);
      _rebuildImageEntries();
      _replyingTo = null;
      _forwardingTo = null;
    });
    _messageController.clear();
    unawaited(DraftService.instance.clearDraft('chat', _contactUid));
    _scrollToBottom();

    ChatDataService.instance.addSentMessage(_contactUid, userMessage);

    try {
      // WS，启动！
      bool wsSent = false;
      if (_wsConnected && forwardTarget == null) {
        if (_contactUid.startsWith('G')) {
          final gid = int.tryParse(_contactUid.substring(1));
          if (gid != null) {
            wsSent = await ChatWsService.instance.sendGroupTextMessage(
              gid,
              text,
              clientMid: clientMid,
              quote: quoteMid,
            );
          }
        } else {
          final targetUid = int.tryParse(_contactUid.substring(1));
          if (targetUid != null) {
            wsSent = await ChatWsService.instance.sendTextMessage(
              targetUid.toString(),
              text,
              clientMid: clientMid,
              quote: quoteMid,
            );
          }
        }
      }
      if (!wsSent) {
        // REST
        final recipient = _contactUid;
        final result = await TfApiClient.instance.sendMessage(
          uid,
          password,
          recipient: recipient,
          content: outgoingText,
          contentType: outgoingType == MessageType.file ? 'file' : 'plain',
          fileHash: forwardTarget?.media?.fileHash,
          clientMid: clientMid,
          quote: quoteMid,
          forwarded: forwardedMid,
        );
        if (result != null) {
          final mid = (result['mid'] as num?)?.toInt();
          _updateMessageStatus(clientMid, mid: mid, status: MessageStatus.sent);
        } else {
          _updateMessageStatus(clientMid, status: MessageStatus.failed);
          _restoreFailedDraft(text);
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.chatSendFailed),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // 准备 restful api 回退
        _pendingWsTimers[clientMid]?.cancel();
        _pendingWsTimers[clientMid] = Timer(
          const Duration(seconds: 15),
          () => _wsAckFallback(
            clientMid: clientMid,
            content: outgoingText,
            contentType: outgoingType == MessageType.file ? 'file' : 'plain',
            fileHash: forwardTarget?.media?.fileHash,
            quoteMid: quoteMid,
            forwardedMid: forwardedMid,
          ),
        );
      }
    } catch (e) {
      talker.error('ChatDetail text send failed', e);
      _updateMessageStatus(clientMid, status: MessageStatus.failed);
      _restoreFailedDraft(text);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chatSendFailed),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _restoreFailedDraft(String text) {
    if (text.isEmpty || _messageController.text.isNotEmpty) return;
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(offset: text.length);
  }

  /// REST 回退使用相同的 client mid 避免 dup
  Future<void> _wsAckFallback({
    required String clientMid,
    required String content,
    required String contentType,
    String? fileHash,
    required int quoteMid,
    required int forwardedMid,
  }) async {
    _pendingWsTimers.remove(clientMid);
    if (!mounted) return;
    // Only one REST attempt per client mid (guards the WS ack-fail retry
    // racing with the 15s fallback timer).
    if (!_restFallbackAttempted.add(clientMid)) return;

    final msgs = ChatDataService.instance.getMessages(_contactUid);
    final idx = msgs.indexWhere((m) => m.clientMid == clientMid);
    if (idx == -1 || msgs[idx].status == MessageStatus.sent) return;
    // Text messages rejected by the WS ack (banned / not_friends / ...) should
    // not be re-sent automatically; only file/media messages get the REST retry.
    if (msgs[idx].status == MessageStatus.failed && msgs[idx].media == null) {
      return;
    }

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final result = await TfApiClient.instance.sendMessage(
      uid,
      password,
      recipient: _contactUid,
      content: content,
      contentType: contentType,
      fileHash: fileHash,
      clientMid: clientMid,
      quote: quoteMid,
      forwarded: forwardedMid,
    );
    if (!mounted) return;
    if (result != null) {
      final serverMid = (result['mid'] as num?)?.toInt();
      _updateMessageStatus(
        clientMid,
        mid: serverMid,
        status: MessageStatus.sent,
      );
    } else {
      _updateMessageStatus(clientMid, status: MessageStatus.failed);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chatSendFailed),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _updateMessageStatus(
    String clientMid, {
    int? mid,
    MessageStatus? status,
  }) {
    _pendingWsTimers.remove(clientMid)?.cancel();
    final msgs = ChatDataService.instance.getMessages(_contactUid);
    final cIdx = msgs.indexWhere((m) => m.clientMid == clientMid);
    if (cIdx != -1) {
      final updated = msgs.toList();
      updated[cIdx] = updated[cIdx].copyWith(
        id: mid?.toString() ?? updated[cIdx].id,
        mid: mid ?? updated[cIdx].mid,
        status: status ?? updated[cIdx].status,
      );
      ChatDataService.instance.setMessages(_contactUid, updated);
    }
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.clientMid == clientMid);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(
          id: mid?.toString() ?? _messages[idx].id,
          mid: mid ?? _messages[idx].mid,
          status: status ?? _messages[idx].status,
        );
      }
      _rebuildImageEntries();
    });
  }

  void _updateMessageMedia(String clientMid, MessageMedia media) {
    final msgs = ChatDataService.instance.getMessages(_contactUid);
    final cIdx = msgs.indexWhere((m) => m.clientMid == clientMid);
    if (cIdx != -1) {
      final updated = msgs.toList();
      updated[cIdx] = updated[cIdx].copyWith(media: media);
      ChatDataService.instance.setMessages(_contactUid, updated);
    }
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.clientMid == clientMid);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(media: media);
      }
      _rebuildImageEntries();
    });
  }

  /// 根据当前 [_messages] 重建图片画廊条目与下标映射。
  ///
  /// 在 [_messages] 任何结构变更（含 id 变化）后调用；O(n)，n 为消息数。
  void _rebuildImageEntries() {
    _imageEntries.clear();
    _imageIndexById.clear();
    if (_messages.length > _galleryCap) return;
    for (final message in _messages) {
      final media = message.media;
      if (message.type == MessageType.image && media != null) {
        _imageEntries.add(
          LightboxImageItem(
            messageId: message.id,
            media: media,
            bytes: media.bytes != null
                ? Uint8List.fromList(media.bytes!)
                : null,
          ),
        );
        _imageIndexById[message.id] = _imageEntries.length - 1;
      }
    }
  }

  Future<void> _sendMediaMessage(
    PlatformFile platformFile,
    MessageType type,
  ) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final replyTarget = _replyingTo;
    final quoteMid = replyTarget?.mid ?? -1;

    String filePath;
    String fileName;
    int fileSize;
    List<int>? bytes;

    if (kIsWeb) {
      fileName = platformFile.name;
      filePath =
          'web_upload_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      fileSize = platformFile.bytes?.length ?? 0;
      bytes = platformFile.bytes;
    } else if (platformFile.bytes != null) {
      // 从剪贴板粘贴：文件内容已在内存中（bytes），没有磁盘路径。
      fileName = platformFile.name;
      filePath = 'clipboard_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      fileSize = platformFile.bytes!.length;
      bytes = platformFile.bytes;
    } else {
      filePath = platformFile.path!;
      fileName = path.basename(filePath);
      final file = File(filePath);
      // 获取文件大小
      fileSize = await file.length();
    }

    final maxSize = await TfApiClient.instance.getMaxFileSize();
    if (maxSize != null && fileSize > maxSize) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.storageFileTooLarge((maxSize / (1024 * 1024)).round()),
            ),
          ),
        );
      }
      return;
    }

    // 读文件到内存中（Web 在 platformFile.bytes 中）
    if (!kIsWeb) {
      bytes = platformFile.bytes ?? await File(filePath).readAsBytes();
    }

    if (bytes == null) return;

    String messageText = '';
    switch (type) {
      case MessageType.image:
        messageText = '[IMAGE]';
        break;
      case MessageType.video:
        messageText = '[VIDEO]';
        break;
      case MessageType.audio:
        messageText = '[AUDIO]';
        break;
      case MessageType.file:
        messageText = '[FILE] $fileName';
        break;
      default:
        messageText = fileName;
    }

    final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
    final media = MessageMedia(
      path: filePath,
      fileName: fileName,
      fileSize: fileSize,
      bytes: bytes,
    );
    final userMessage = ChatMessage(
      id: clientMid,
      clientMid: clientMid,
      senderUid: uid,
      text: messageText,
      timestamp: DateTime.now(),
      isMe: true,
      type: type,
      media: media,
      status: MessageStatus.pending,
      quoteMid: quoteMid >= 0 ? quoteMid : null,
      quotePreview: replyTarget == null
          ? null
          : QuotedMessagePreview(
              mid: replyTarget.mid,
              senderUid: replyTarget.senderUid,
              senderName: replyTarget.isMe
                  ? AuthState.instance.currentUser?.username
                  : replyTarget.senderName,
              content: replyTarget.text,
              contentType: replyTarget.type == MessageType.file
                  ? 'file'
                  : 'plain',
            ),
    );

    setState(() {
      _messages.add(userMessage);
      _rebuildImageEntries();
      _replyingTo = null;
    });
    ChatDataService.instance.addSentMessage(_contactUid, userMessage);
    _scrollToBottom();

    try {
      final fileBase64 = base64.encode(bytes);
      final response = await TfApiClient.instance.uploadFile(
        uid,
        password,
        fileName,
        fileBase64,
      );
      final hash = response?['hash'] as String?;
      if (hash == null) {
        _updateMessageStatus(clientMid, status: MessageStatus.failed);
        return;
      }

      final baseUrl = await TfApiClient.instance.getBaseUrl();
      _updateMessageMedia(
        clientMid,
        MessageMedia(
          path: '$baseUrl/file/get_file/$hash',
          fileName: fileName,
          fileSize: fileSize,
          mimeType: lookupMimeType(fileName),
          bytes: bytes,
          fileHash: hash,
        ),
      );

      await _dispatchFileSend(
        clientMid: clientMid,
        hash: hash,
        quoteMid: quoteMid,
      );
    } catch (e) {
      talker.error('ChatDetail file send failed', e);
      _updateMessageStatus(clientMid, status: MessageStatus.failed);
      _showSendFailedSnackBar();
    }
  }

  /// 按 hash 发送文件消息（WS 优先，失败走 REST，WS 发送后 15s 未收到 ack 再补 REST）。
  ///
  /// 上传直发（[_sendMediaMessage]）与服务器已有文件直发（[_sendServerFile]）共用。
  Future<void> _dispatchFileSend({
    required String clientMid,
    required String hash,
    required int quoteMid,
  }) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    bool wsSent = false;
    if (_wsConnected) {
      if (_contactUid.startsWith('G')) {
        final gid = int.tryParse(_contactUid.substring(1));
        if (gid != null) {
          wsSent = await ChatWsService.instance.sendGroupFileMessage(
            gid,
            hash,
            clientMid: clientMid,
            quote: quoteMid,
          );
        }
      } else {
        final peerUid = int.tryParse(_contactUid.substring(1));
        if (peerUid != null) {
          wsSent = await ChatWsService.instance.sendFileMessage(
            peerUid.toString(),
            hash,
            clientMid: clientMid,
            quote: quoteMid,
          );
        }
      }
    }

    if (!wsSent) {
      final recipient = _contactUid;
      final result = await TfApiClient.instance.sendMessage(
        uid,
        password,
        recipient: recipient,
        content: hash,
        contentType: 'file',
        clientMid: clientMid,
        fileHash: hash,
        quote: quoteMid,
      );
      if (result != null) {
        final mid = (result['mid'] as num?)?.toInt();
        _updateMessageStatus(clientMid, mid: mid, status: MessageStatus.sent);
      } else {
        _updateMessageStatus(clientMid, status: MessageStatus.failed);
        _showSendFailedSnackBar();
      }
    } else {
      // REST 再试一次
      _pendingWsTimers[clientMid]?.cancel();
      _pendingWsTimers[clientMid] = Timer(
        const Duration(seconds: 15),
        () => _wsAckFallback(
          clientMid: clientMid,
          content: hash,
          contentType: 'file',
          fileHash: hash,
          quoteMid: quoteMid,
          forwardedMid: -1,
        ),
      );
    }
  }

  void _showSendFailedSnackBar() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.chatSendFailed),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 发送服务端已存在的文件（来自 /file/get_user_files），免二次上传。
  Future<void> _sendServerFile(
    Map<String, dynamic> file,
    MessageType type,
  ) async {
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    final hash = file['hash'] as String? ?? '';
    if (hash.isEmpty) return;
    final fileName = file['file_name'] as String? ?? hash;
    final fileSize = (file['size'] as num?)?.toInt() ?? 0;
    final rawMime = file['mime_type'] as String?;
    final mimeType =
        (rawMime == null || rawMime == 'application/octet-stream')
        ? null
        : rawMime;
    final downloadUrl = file['download_url'] as String?;

    final replyTarget = _replyingTo;
    final quoteMid = replyTarget?.mid ?? -1;
    final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    // 服务端返回的 download_url 是相对路径，补全为绝对地址，
    // 与上传直发（_sendMediaMessage）保持一致。
    final mediaPath = (downloadUrl != null && downloadUrl.startsWith('http'))
        ? downloadUrl
        : '$baseUrl/file/get_file/$hash';
    final messageText = switch (type) {
      MessageType.image => '[IMAGE]',
      MessageType.video => '[VIDEO]',
      MessageType.audio => '[AUDIO]',
      MessageType.file => '[FILE] $fileName',
      _ => fileName,
    };

    final userMessage = ChatMessage(
      id: clientMid,
      clientMid: clientMid,
      senderUid: uid,
      text: messageText,
      timestamp: DateTime.now(),
      isMe: true,
      type: type,
      media: MessageMedia(
        path: mediaPath,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        fileHash: hash,
      ),
      status: MessageStatus.pending,
      quoteMid: quoteMid >= 0 ? quoteMid : null,
      quotePreview: replyTarget == null
          ? null
          : QuotedMessagePreview(
              mid: replyTarget.mid,
              senderUid: replyTarget.senderUid,
              senderName: replyTarget.isMe
                  ? AuthState.instance.currentUser?.username
                  : replyTarget.senderName,
              content: replyTarget.text,
              contentType: replyTarget.type == MessageType.file
                  ? 'file'
                  : 'plain',
            ),
    );

    if (!mounted) return;
    setState(() {
      _messages.add(userMessage);
      _rebuildImageEntries();
      _replyingTo = null;
    });
    ChatDataService.instance.addSentMessage(_contactUid, userMessage);
    _scrollToBottom();

    try {
      await _dispatchFileSend(
        clientMid: clientMid,
        hash: hash,
        quoteMid: quoteMid,
      );
    } catch (e) {
      talker.error('ChatDetail server file send failed', e);
      _updateMessageStatus(clientMid, status: MessageStatus.failed);
      _showSendFailedSnackBar();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    _followBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
    });
  }

  void _scrollToQuotedMessage(int mid) {
    _followBottom = false;
    final index = _messages.indexWhere((message) => message.mid == mid);
    if (index < 0) return;
    final targetContext = _messageKeys[mid]?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.35,
      );
      return;
    }
    if (!_scrollController.hasClients) return;
    final reverseIndex = _messages.length - 1 - index;
    final fraction = _messages.length <= 1
        ? 0.0
        : reverseIndex / (_messages.length - 1);
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent * fraction,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  int _indexOfMessage(ChatMessage target) {
    final mid = target.mid;
    if (mid != null) {
      final byMid = _messages.indexWhere((m) => m.mid == mid);
      if (byMid >= 0) return byMid;
    }
    final byId = _messages.indexWhere((m) => m.id == target.id);
    if (byId >= 0) return byId;
    final clientMid = target.clientMid;
    if (clientMid != null) {
      final byClientMid = _messages.indexWhere((m) => m.clientMid == clientMid);
      if (byClientMid >= 0) return byClientMid;
    }
    return -1;
  }

  void _scrollToMessageIndex(int index) {
    if (index < 0 || index >= _messages.length) return;
    _followBottom = false;
    final message = _messages[index];
    final mid = message.mid;

    // 目标上下文已就绪：瞬时精确对齐（无动画）
    final targetContext = mid != null
        ? _messageKeys[mid]?.currentContext
        : null;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: Duration.zero,
        alignment: 0.35,
      );
      return;
    }

    // 目标不在视口内：分段瞬时逼近。
    // 一次性 jumpTo 很远会让 ListView.builder 在单帧内布局海量 item 而冻结，
    // 因此每次只跳约 5 个视口高度，等一帧布局完成后再继续，直到接近目标。
    _isJumpingToMessage = true;
    _jumpStepToMessage(index: index, mid: mid);
  }

  void _jumpStepToMessage({required int index, int? mid, int retry = 0}) {
    if (!mounted || index >= _messages.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _messages.length) return;
      if (!_scrollController.hasClients) {
        // 列表尚未挂载（如跳转期间房间被切换）：最多等待 60 帧，
        // 避免列表永远没有客户端时无限空转。
        if (retry < 60) {
          _jumpStepToMessage(index: index, mid: mid, retry: retry + 1);
        } else {
          _isJumpingToMessage = false;
        }
        return;
      }

      // 目标已被构建出来：瞬时精确对齐，跳转完成
      final context = mid != null ? _messageKeys[mid]?.currentContext : null;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: Duration.zero,
          alignment: 0.35,
        );
        _isJumpingToMessage = false;
        return;
      }

      final position = _scrollController.position;
      // reverse:true 列表：index=0 为最新（底部），index 越大越旧（越靠上）
      final reverseIndex = _messages.length - 1 - index;
      final fraction = _messages.length <= 1
          ? 0.0
          : reverseIndex / (_messages.length - 1);
      final targetOffset = position.maxScrollExtent * fraction;
      final currentOffset = position.pixels;
      final distance = (targetOffset - currentOffset).abs();
      final maxStep = position.viewportDimension * 5.0;

      if (distance <= maxStep || targetOffset <= 0) {
        // 已接近目标（或目标就在顶部）：跳最后一段，再精确对齐一次
        position.jumpTo(
          targetOffset.clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
        _jumpFinalAlign(index: index, mid: mid);
        return;
      }

      // 向前推进一段（不超过 maxStep），等待布局后继续
      final nextOffset = targetOffset > currentOffset
          ? currentOffset + maxStep
          : currentOffset - maxStep;
      position.jumpTo(
        nextOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      _jumpStepToMessage(index: index, mid: mid);
    });
  }

  void _jumpFinalAlign({required int index, int? mid}) {
    if (!mounted || index >= _messages.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _messages.length) return;
      _isJumpingToMessage = false;
      final context = mid != null ? _messageKeys[mid]?.currentContext : null;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: Duration.zero,
          alignment: 0.35,
        );
      }
    });
  }

  void _showJumpMessageNotFound() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.chatSearchMessagesNoResults),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _jumpToMessage(ChatMessage target) async {
    _followBottom = false;
    final roomId = _contactUid;
    final roomGeneration = _roomGeneration;

    // 1. 目标消息已经在当前加载的列表里，直接定位
    var index = _indexOfMessage(target);
    if (index >= 0) {
      _scrollToMessageIndex(index);
      return;
    }

    final targetMid = target.mid;
    if (targetMid == null || target.isDeleted) {
      _showJumpMessageNotFound();
      return;
    }

    // 翻页加载期间也进入“跳转中”状态，防止实时消息插入/替换列表打断跳转
    _isJumpingToMessage = true;

    // 2. 目标不在当前列表，往前翻页加载直到找到或没有更多
    var exhausted = false;
    var aborted = false;
    var locatedInList = false;
    const maxPages = 30;
    try {
      for (var pageCount = 0; pageCount < maxPages; pageCount++) {
        if (!mounted || roomGeneration != _roomGeneration) return;
        // 已有加载在进行中（如上滑自动翻页）：等待其完成而不是直接放弃，
        // 否则目标明明存在也会被误报为"未找到"。
        if (_isLoadingMessages || _isLoadingOlder) {
          final settled = await _waitForOngoingMessageLoad();
          if (!mounted || roomGeneration != _roomGeneration) return;
          final indexNow = _indexOfMessage(target);
          if (indexNow >= 0) {
            locatedInList = true;
            _scrollToMessageIndex(indexNow);
            return;
          }
          if (!settled) {
            // 加载迟迟不结束（如网络卡住）：放弃本次跳转，也不报"未找到"
            aborted = true;
            break;
          }
          continue;
        }
        if (!_hasMoreMessages) {
          exhausted = true;
          break;
        }

        setState(() => _isLoadingOlder = true);
        MessageHistoryPage page;
        try {
          page = await ChatDataService.instance.loadOlderMessages(roomId);
        } catch (error, stackTrace) {
          talker.error('Jump-to-message: load older failed', error, stackTrace);
          if (mounted) setState(() => _isLoadingOlder = false);
          exhausted = true;
          break;
        }
        if (!mounted ||
            roomGeneration != _roomGeneration ||
            roomId != _contactUid) {
          return;
        }
        final msgs = ChatDataService.instance.getMessages(roomId);
        setState(() {
          _messages
            ..clear()
            ..addAll(msgs);
          _isLoadingOlder = false;
          _hasMoreMessages = page.hasMore;
        });

        index = _indexOfMessage(target);
        if (index >= 0) {
          locatedInList = true;
          _scrollToMessageIndex(index);
          return;
        }
        if (!page.hasMore || msgs.isEmpty) {
          exhausted = true;
          break;
        }
      }
    } finally {
      // 如果目标已在列表中被定位并交给分段滚动处理，
      // 则保持 _isJumpingToMessage = true，由 _jumpFinalAlign 在完成后复位；
      // 否则（未找到/被中断）在此复位。
      if (mounted && !locatedInList) _isJumpingToMessage = false;
    }

    if (mounted && exhausted && !aborted) _showJumpMessageNotFound();
  }

  /// 等待并发中的消息加载（自动翻页等）结束，最多等 [timeout]。
  /// 正常结束返回 true；超时返回 false（调用方应放弃跳转）。
  Future<bool> _waitForOngoingMessageLoad({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (mounted && (_isLoadingMessages || _isLoadingOlder)) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return !_isLoadingMessages && !_isLoadingOlder;
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    final avatarUrl = _currentRoom!.avatar;
    if (avatarUrl == null || _avatarLoadFailed) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(
          _currentRoom!.type == ChatType.group ? Icons.group : Icons.person,
          size: 20,
          color: colorScheme.onPrimaryContainer,
        ),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: colorScheme.primaryContainer,
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (_, error) {
        talker.warning(
          'Avatar load failed for ${_currentRoom!.id}: $avatarUrl',
        );
        if (mounted) setState(() => _avatarLoadFailed = true);
      },
    );
  }

  Widget _buildPinnedMessagesBar() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final pins = _pinnedMessages;
    if (pins.isEmpty) return const SizedBox.shrink();

    final currentIndex = _pinCurrentPage.clamp(0, pins.length - 1);
    final currentPin = pins[currentIndex];

    return Column(
      key: _pinnedBarKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () {
              ChatMessage? cachedMsg =
                  _pinnedMessageContents[currentPin.messageId];
              cachedMsg ??= _messages.cast<ChatMessage?>().firstWhere(
                (m) => m?.mid == currentPin.messageId,
                orElse: () => null,
              );
              _scrollToQuotedMessage(cachedMsg?.mid ?? currentPin.messageId);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Telegram-style left accent bar
                  Container(
                    width: 3,
                    height: 38,
                    margin: const EdgeInsets.only(left: 12, right: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Content area with animated pin switch
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _buildCurrentPinContent(
                        key: ValueKey(currentPin.messageId),
                        pin: currentPin,
                        pageLabel: pins.length > 1
                            ? ' · ${currentIndex + 1}/${pins.length}'
                            : null,
                        l10n: l10n,
                        colorScheme: colorScheme,
                      ),
                    ),
                  ),
                  // View-all button (only when multiple pins)
                  if (pins.length > 1)
                    IconButton(
                      icon: const Icon(Symbols.list, size: 18),
                      onPressed: _showPinnedMessagesSheet,
                      tooltip: l10n.viewAllPinned,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1 / MediaQuery.devicePixelRatioOf(context),
        ),
      ],
    );
  }

  Widget _buildCurrentPinContent({
    required Key key,
    required PinnedMessage pin,
    required String? pageLabel,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
  }) {
    final textTheme = Theme.of(context).textTheme;

    ChatMessage? cachedMsg = _pinnedMessageContents[pin.messageId];
    if (cachedMsg == null) {
      cachedMsg = _messages.cast<ChatMessage?>().firstWhere(
        (m) => m?.mid == pin.messageId,
        orElse: () => null,
      );
      if (cachedMsg != null) _pinnedMessageContents[pin.messageId] = cachedMsg;
    }

    final senderName = cachedMsg?.senderName?.trim().isNotEmpty == true
        ? cachedMsg!.senderName!
        : cachedMsg?.isMe == true
        ? (AuthState.instance.currentUser?.username ?? '')
        : ChatDataService.instance
              .getUser('U${cachedMsg?.senderUid ?? ''}')
              ?.username;

    final content = cachedMsg?.text ?? '';
    final hasAttachment = cachedMsg?.media != null;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top line: label + page indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.push_pin, size: 11, color: colorScheme.primary),
            const SizedBox(width: 3),
            Text(
              l10n.pinnedMessageLabel,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (pageLabel != null)
              Text(
                pageLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // Bottom line: sender + preview
        if (cachedMsg == null)
          Text(
            '...',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          )
        else
          Row(
            children: [
              if (senderName != null && senderName.isNotEmpty)
                Text(
                  '$senderName: ',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Expanded(
                child: content.isNotEmpty
                    ? Text(
                        content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      )
                    : hasAttachment
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.attach_file,
                            size: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              cachedMsg.media?.fileName ?? 'Attachment',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
      ],
    );
  }

  void _onEssenceChanged(int gid) {
    if (_contactUid == 'G$gid') unawaited(_fetchEssenceMessages());
  }

  void _openGroupProfile() {
    final room = _currentRoom;
    if (room?.type != ChatType.group || !_contactUid.startsWith('G')) return;
    final gid = _contactUid.substring(1);
    context.push(
      AppRoutes.groupProfile.replaceFirst(':gid', gid),
      extra: <String, dynamic>{'groupName': room!.name},
    );
  }

  Future<void> _openEssenceScreen() async {
    final room = _currentRoom;
    final gid = int.tryParse(_contactUid.substring(1));
    if (room?.type != ChatType.group || gid == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupEssenceScreen(gid: gid, groupName: room!.name),
      ),
    );
    if (mounted && _contactUid == 'G$gid') {
      unawaited(_fetchEssenceMessages());
    }
  }

  Widget _buildEssenceBar() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: cs.surfaceContainerHigh,
      child: InkWell(
        onTap: _openEssenceScreen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Symbols.auto_awesome, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                l10n.essenceLabel(_essenceMids.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPinnedMessagesSheet() {
    final canUnpin = _canModerateGroup;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => PinnedMessagesSheet(
        roomId: _contactUid,
        pins: _pinnedMessages,
        canUnpin: canUnpin,
        onUnpin: canUnpin
            ? (pinId) async {
                final uid = AuthState.instance.uid;
                final password = AuthState.instance.password;
                final gid = int.tryParse(_contactUid.substring(1));
                if (uid == null || password == null || gid == null) return;
                final ok = await TfApiClient.instance.unpinMessage(
                  uid,
                  password,
                  gid,
                  pinId,
                );
                if (ok) {
                  unawaited(_fetchPinnedMessages());
                }
              }
            : null,
        onJumpToMessage: (mid) {
          _scrollToQuotedMessage(mid);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_currentRoom == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.chatDetailLoading)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 600;
    final essenceButton = IconButton(
      icon: const Icon(Icons.auto_awesome),
      onPressed: _openEssenceScreen,
    );
    final settingButton = IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () async {
        final result = await Navigator.push<ChatMessage>(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomSettingsScreen(chatRoom: _currentRoom!),
          ),
        );
        if (result != null && mounted) {
          unawaited(_jumpToMessage(result));
        }
        if (mounted && _currentRoom?.type == ChatType.group) {
          unawaited(_loadMentionUsers());
          unawaited(_fetchEssenceMessages());
        }
      },
    );
    List<IconButton> actiontmp = [];
    if (_currentRoom?.type == ChatType.group && _essenceEnabled) {
      actiontmp = [essenceButton, settingButton];
    } else {
      actiontmp = [settingButton];
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: !isWide
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.chat),
              )
            : null,
        automaticallyImplyLeading: false,
        backgroundColor: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            InkWell(
              onTap: _currentRoom!.type == ChatType.group
                  ? _openGroupProfile
                  : null,
              customBorder: const CircleBorder(),
              child: _buildAvatar(colorScheme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentRoom!.name,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_currentRoom!.type == ChatType.group)
                    Text(
                      l10n.chatDetailGroupChat,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: actiontmp,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 只重建指示器自身，不触发整页 setState（同步分页会多次通知进度）。
            ListenableBuilder(
              listenable: MessageSyncService.instance,
              builder: (context, _) =>
                  SyncIndicator(isSyncing: _isRoomSyncing, hint: _syncHint),
            ),
            if (_isLoadingMessages || _isLoadingOlder)
              LinearProgressIndicator(
                minHeight: 2,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.transparent,
              ),
            if (_currentRoom!.type == ChatType.group &&
                _pinnedMessages.isNotEmpty)
              _buildPinnedMessagesBar(),
            if (_currentRoom!.type == ChatType.group &&
                _essenceMids.isNotEmpty &&
                _essenceEnabled)
              _buildEssenceBar(),
            if (_currentRoom!.type == ChatType.group &&
                _groupEnterHint.isNotEmpty &&
                _showGroupEnterHint)
              Material(
                color: colorScheme.secondaryContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  title: Text(
                    _groupEnterHint,
                    style: TextStyle(color: colorScheme.onSecondaryContainer),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _showGroupEnterHint = false);
                      unawaited(
                        DraftService.instance.acknowledge(
                          'group_enter_hint',
                          _contactUid.substring(1),
                          _groupEnterHint,
                        ),
                      );
                    },
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: _onScrollMetricsChanged,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onUserScroll,
                        child: _messages.isEmpty
                            ? RefreshIndicator(
                                onRefresh: _onRefresh,
                                child: ListView(
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.4,
                                      child: Center(
                                        child: Text(
                                          l10n.chatDetailNoMessages,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final messageIndex =
                                      _messages.length - 1 - index;
                                  final message = _messages[messageIndex];
                                  final previous = messageIndex > 0
                                      ? _messages[messageIndex - 1]
                                      : null;
                                  final showAvatar =
                                      previous == null ||
                                      previous.senderUid != message.senderUid ||
                                      message.timestamp
                                              .difference(previous.timestamp)
                                              .inMinutes >=
                                          5;
                                  final key = message.mid == null
                                      ? null
                                      : _messageKeys.putIfAbsent(
                                          message.mid!,
                                          GlobalKey.new,
                                        );
                                  return Dismissible(
                                    key: ValueKey('swipe-${message.id}'),
                                    direction: message.isDeleted
                                        ? DismissDirection.none
                                        : DismissDirection.endToStart,
                                    dismissThresholds: const {
                                      DismissDirection.endToStart: 0.22,
                                    },
                                    resizeDuration: null,
                                    movementDuration: const Duration(
                                      milliseconds: 120,
                                    ),
                                    confirmDismiss: (_) async {
                                      _startReply(message);
                                      return false;
                                    },
                                    background: Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 24,
                                        ),
                                        child: Icon(
                                          Icons.reply,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    child: KeyedSubtree(
                                      key: key,
                                      child: MessageBubble(
                                        message: message,
                                        onReply: _startReply,
                                        onForward: _startForward,
                                        onRecall: _recallMessage,
                                        onQuoteTap: _scrollToQuotedMessage,
                                        showAvatar: showAvatar,
                                        galleryItems: _imageEntries.isEmpty
                                            ? null
                                            : _imageEntries,
                                        galleryIndex:
                                            _imageIndexById[message.id] ?? 0,
                                        canRecall: _canRecall(message),
                                        isEssence:
                                            message.mid != null &&
                                            _essenceMids.contains(
                                              message.mid,
                                            ) &&
                                            _essenceEnabled,
                                        isPinned:
                                            message.mid != null &&
                                            _pinnedMessages.any(
                                              (p) => p.messageId == message.mid,
                                            ),
                                        canPin:
                                            _currentRoom?.type ==
                                                ChatType.group &&
                                            _canModerateGroup &&
                                            message.mid != null &&
                                            !message.isDeleted,
                                        essenceEnabled: _essenceEnabled,
                                        onPinToggle: message.mid != null
                                            ? () => _togglePin(message)
                                            : null,
                                        onEssenceToggle:
                                            message.mid != null &&
                                                _essenceEnabled
                                            ? () => _toggleEssence(message)
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: AnimatedScale(
                      scale: _showBackToBottom ? 1 : 0.8,
                      duration: const Duration(milliseconds: 180),
                      child: AnimatedOpacity(
                        opacity: _showBackToBottom ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !_showBackToBottom,
                          child: FloatingActionButton.small(
                            heroTag: 'chat-back-to-bottom',
                            tooltip: l10n.chatBackToBottom,
                            onPressed: _scrollToBottom,
                            child: const Icon(Icons.arrow_downward),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ChatInputBar(
              controller: _messageController,
              onSend: _sendMessage,
              onFilePicked: _sendMediaMessage,
              onServerFilePicked: _sendServerFile,
              mentionUsers: _mentionUsers,
              actionMessage: _replyingTo ?? _forwardingTo,
              actionIsForward: _forwardingTo != null,
              onClearAction: () => setState(() {
                _replyingTo = null;
                _forwardingTo = null;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
