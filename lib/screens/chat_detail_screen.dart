import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' show lookupMimeType;
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../routes/app_routes.dart';
import '../l10n/app_localizations.dart';
import '../widgets/mention_text_field.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../services/chat_ws_service.dart';
import '../services/chat_data_service.dart';
import '../services/draft_service.dart';
import '../utils/talker.dart';
import 'chat_room_settings_screen.dart';
import '../widgets/pinned_messages_sheet.dart';

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
  final Map<int, GlobalKey> _messageKeys = {};
  final Map<String, Timer> _pendingWsTimers = {};
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
  bool _pinnedBarCollapsed = false;
  PageController? _pinPageController;
  int _pinCurrentPage = 0;
  final GlobalKey _pinnedBarKey = GlobalKey();
  bool _fetchingPins = false;

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
    _messageKeys.clear();
    _messages.clear();
    _currentRoom = null;
    _avatarLoadFailed = false;
    _isLoadingOlder = false;
    _isLoadingMessages = false;
    _hasMoreMessages = true;
    _groupEnterHint = '';
    _showGroupEnterHint = true;
    _followBottom = true;
    _showBackToBottom = false;
    _replyingTo = null;
    _canModerateGroup = false;
    _suppressDraftSave = true;
    _messageController.clear();
    _suppressDraftSave = false;
    unawaited(_restoreDraft(_contactUid));
    _loadChatRoom();
    _startRealMessaging();
  }

  @override
  void dispose() {
    for (final timer in _pendingWsTimers.values) {
      timer.cancel();
    }
    _pendingWsTimers.clear();
    _detachRealtimeListeners();
    _ackErrorSub?.cancel();
    _draftTimer?.cancel();
    unawaited(_saveDraft());
    _messageController.dispose();
    _scrollController.dispose();
    _pinPageController?.dispose();
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

  void _onAckError(String error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final msg = switch (error) {
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
    _realtimeListenersAttached = true;
  }

  void _detachRealtimeListeners() {
    if (!_realtimeListenersAttached) return;
    ChatWsService.instance.removeListener(_onWsStateChanged);
    ChatDataService.instance.removeListener(_onChatDataChanged);
    _realtimeListenersAttached = false;
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

    if (_isLoadingMessages || _isLoadingOlder || !_hasMoreMessages) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent > 0 &&
        position.pixels > position.maxScrollExtent - 50) {
      _loadOlder();
    }
    _updatePinnedPageFromScroll();
  }

  void _updatePinnedPageFromScroll() {
    if (_pinnedMessages.length <= 1 || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0 || _messages.length <= 1) return;

    // 这很复杂
    final total = _messages.length;
    final extentPerItem = position.maxScrollExtent / (total - 1);
    final viewportTop = position.pixels;

    // 最新
    int? abovePage;
    int aboveMsgIndex = total; // smaller = newer

    // 回退最老
    int? belowPage;
    int belowMsgIndex = -1; // larger = older

    for (int i = 0; i < _pinnedMessages.length; i++) {
      final msgIndex = _messages.indexWhere(
        (m) => m.mid == _pinnedMessages[i].messageId,
      );
      if (msgIndex < 0) continue;

      final visualIndex = total - 1 - msgIndex;
      final itemPosition = visualIndex * extentPerItem;

      if (itemPosition < viewportTop) {
        // e
        if (msgIndex < aboveMsgIndex) {
          aboveMsgIndex = msgIndex;
          abovePage = i;
        }
      } else {
        // e
        if (msgIndex > belowMsgIndex) {
          belowMsgIndex = msgIndex;
          belowPage = i;
        }
      }
    }

    final page = abovePage ?? belowPage ?? (_pinnedMessages.length - 1);
    if (page != _pinCurrentPage && mounted) {
      setState(() => _pinCurrentPage = page);
      _pinPageController?.animateToPage(
        page,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
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
    if (_followBottom) _scrollToBottom(animated: false);
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
    _refreshRoom();
    final cached = ChatDataService.instance.getMessages(_contactUid);
    final previousLastId = _messages.isNotEmpty ? _messages.last.id : null;
    final countChanged = cached.length != _messages.length;
    final lastIdChanged = cached.isNotEmpty && cached.last.id != previousLastId;
    final wasNearBottom = _isNearBottom;
    setState(() {
      _messages.clear();
      _messages.addAll(cached);
    });
    if ((countChanged || lastIdChanged) && wasNearBottom) {
      _scrollToBottom();
    }
    if (countChanged || lastIdChanged) {
      _markVisibleMessagesRead(previousLastId: previousLastId);
    }
    if (_currentRoom?.type == ChatType.group) {
      unawaited(_fetchPinnedMessages());
    }
  }

  void _loadChatRoom() {
    final chatData = ChatDataService.instance;
    final profile = chatData.getUser(_contactUid);
    _mentionUsers.clear();
    _pinnedMessages.clear();
    _pinnedMessageContents.clear();
    _pinnedBarCollapsed = false;
    _pinCurrentPage = 0;
    _pinPageController?.dispose();
    _pinPageController = null;
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
    setState(() {
      _forwardingTo = message;
      _replyingTo = null;
    });
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
      setState(() {
        _pinnedMessages = pins;
        if (pins.isNotEmpty) {
          _pinCurrentPage = pins.length - 1;
          _pinPageController?.dispose();
          _pinPageController = PageController(initialPage: pins.length - 1);
        }
      });
    } catch (_) {
      // server eror 不能一直 retry 啦
    } finally {
      _fetchingPins = false;
    }
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
      final ok = await TfApiClient.instance.pinMessage(
        uid,
        password,
        gid,
        mid,
      );
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
    final msgs = ChatDataService.instance.getMessages(_contactUid);
    final idx = msgs.indexWhere((m) => m.clientMid == clientMid);
    if (idx == -1 || msgs[idx].status != MessageStatus.pending) return;

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
    });
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
      filePath =
          'clipboard_${DateTime.now().millisecondsSinceEpoch}_$fileName';
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
    } catch (e) {
      talker.error('ChatDetail file send failed', e);
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
    final textTheme = Theme.of(context).textTheme;

    final pins = _pinnedMessages;
    if (pins.isEmpty) return const SizedBox.shrink();

    _pinPageController ??= PageController(initialPage: pins.length - 1);

    return Column(
      key: _pinnedBarKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: colorScheme.surfaceContainerHigh,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(
                  () => _pinnedBarCollapsed = !_pinnedBarCollapsed,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.push_pin,
                        size: 15,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.pinnedMessageCount(pins.length),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pins.length > 1) ...[
                        const SizedBox(width: 4),
                        _buildPageIndicator(),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Symbols.list, size: 16),
                          onPressed: () => _showPinnedMessagesSheet(),
                          tooltip: l10n.viewAllPinned,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                      Icon(
                        _pinnedBarCollapsed
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (!_pinnedBarCollapsed)
                SizedBox(
                  height: 42,
                  child: PageView.builder(
                    controller: _pinPageController,
                    scrollDirection: Axis.vertical,
                    itemCount: pins.length,
                    onPageChanged: (page) => setState(() => _pinCurrentPage = page),
                    itemBuilder: (context, index) {
                      final pin = pins[index];
                      return _buildPinnedMessagePreview(pin);
                    },
                  ),
                ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1 / MediaQuery.devicePixelRatioOf(context),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        _pinnedMessages.length.clamp(0, 3),
        (index) {
          final isActive = index == _pinCurrentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: isActive ? 10 : 4,
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinnedMessagePreview(PinnedMessage pin) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    ChatMessage? cachedMsg = _pinnedMessageContents[pin.messageId];
    if (cachedMsg == null) {
      cachedMsg = _messages.cast<ChatMessage?>().firstWhere(
        (m) => m?.mid == pin.messageId,
        orElse: () => null,
      );
      if (cachedMsg != null) {
        _pinnedMessageContents[pin.messageId] = cachedMsg;
      }
    }

    final senderName = cachedMsg?.senderName ??
        (cachedMsg?.isMe == true
            ? (AuthState.instance.currentUser?.username ?? '')
            : ChatDataService.instance
                .getUser('U${cachedMsg?.senderUid ?? ''}')
                ?.username);
    final content = cachedMsg?.text ?? '';
    final hasAttachment = cachedMsg?.media != null;

    String formatTimestamp(DateTime dt) {
      final now = DateTime.now();
      if (now.difference(dt).inDays > 365) {
        return DateFormat('yyyy/MM/dd HH:mm').format(dt);
      } else if (now.difference(dt).inDays > 0) {
        return DateFormat('MM/dd HH:mm').format(dt);
      }
      return DateFormat('HH:mm').format(dt);
    }

    final timestamp = cachedMsg != null
        ? formatTimestamp(cachedMsg.timestamp)
        : '';

    return InkWell(
      onTap: () {
        final mid = cachedMsg?.mid ?? pin.messageId;
        _scrollToQuotedMessage(mid);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: cachedMsg == null
            ? Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading...',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: cachedMsg.senderAvatar != null
                        ? NetworkImage(cachedMsg.senderAvatar!)
                        : null,
                    child: cachedMsg.senderAvatar == null
                        ? Icon(Icons.person, size: 14, color: colorScheme.onPrimaryContainer)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (senderName != null && senderName.isNotEmpty)
                              Flexible(
                                child: Text(
                                  senderName,
                                  style: textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (timestamp.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                timestamp,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        if (content.isNotEmpty)
                          Text(
                            content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          )
                        else if (hasAttachment)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.attach_file,
                                size: 14,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cachedMsg.media!.fileName ?? 'Attachment',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
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
            _buildAvatar(colorScheme),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChatRoomSettingsScreen(chatRoom: _currentRoom!),
                ),
              );
              if (mounted && _currentRoom?.type == ChatType.group) {
                unawaited(_loadMentionUsers());
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                                      if (message.isMe) {
                                        _startForward(message);
                                      } else {
                                        _startReply(message);
                                      }
                                      return false;
                                    },
                                    background: Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 24,
                                        ),
                                        child: Icon(
                                          message.isMe
                                              ? Icons.forward
                                              : Icons.reply,
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
                                        canRecall: _canRecall(message),
                                        isPinned: message.mid != null &&
                                            _pinnedMessages.any((p) => p.messageId == message.mid),
                                        canPin: _currentRoom?.type == ChatType.group &&
                                            _canModerateGroup &&
                                            message.mid != null &&
                                            !message.isDeleted,
                                        onPinToggle: message.mid != null
                                            ? () => _togglePin(message)
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
