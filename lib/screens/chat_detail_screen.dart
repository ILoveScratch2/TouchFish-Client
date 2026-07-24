import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
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
import '../utils/talker.dart';
import 'chat_room_settings_screen.dart';

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
  ChatRoom? _currentRoom;
  final List<MentionUser> _mentionUsers = [];
  bool _isInitialized = false;
  bool _wsConnected = false;
  bool _avatarLoadFailed = false;
  bool _isLoadingOlder = false;
  bool _hasMoreMessages = true;
  bool _realtimeListenersAttached = false;
  StreamSubscription? _ackErrorSub;
  String _groupEnterHint = '';
  bool _showGroupEnterHint = true;
  ChatMessage? _replyingTo;
  ChatMessage? _forwardingTo;
  bool _canModerateGroup = false;

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
      _initRoom();
    }
  }

  void _initRoom() {
    _messages.clear();
    _currentRoom = null;
    _avatarLoadFailed = false;
    _isLoadingOlder = false;
    _hasMoreMessages = true;
    _groupEnterHint = '';
    _showGroupEnterHint = true;
    _replyingTo = null;
    _canModerateGroup = false;
    _loadChatRoom();
    _startRealMessaging();
  }

  @override
  void dispose() {
    _detachRealtimeListeners();
    _ackErrorSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
    final chatData = ChatDataService.instance;

    final messages = await chatData.refreshMessagesForContact(_contactUid);
    _refreshRoom();

    if (!mounted) return;
    setState(() {
      _messages.clear();
      _messages.addAll(messages);
    });
    _scrollToBottom();
    _markVisibleMessagesRead();
  }

  Future<void> _onRefresh() async {
    await _loadAndShowMessages();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingOlder || !_hasMoreMessages) return;
    if (_scrollController.position.pixels < 200) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_isLoadingOlder) return;

    setState(() => _isLoadingOlder = true);

    final oldLen = _messages.length;
    final oldOffset = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    final oldMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final merged = await ChatDataService.instance.loadOlderMessages(
      _contactUid,
    );

    if (!mounted) return;
    if (merged.isEmpty) {
      setState(() {
        _isLoadingOlder = false;
        _hasMoreMessages = false;
      });
      return;
    }
    setState(() {
      _messages.clear();
      _messages.addAll(merged);
      _isLoadingOlder = false;
      _hasMoreMessages = merged.length > oldLen;
    });

    if (merged.length > oldLen && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final delta = _scrollController.position.maxScrollExtent - oldMax;
          _scrollController.jumpTo(oldOffset + delta);
        }
      });
    }
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
      // Profile not cached — fetch for direct chats
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
    return pos.maxScrollExtent == 0 || pos.pixels >= pos.maxScrollExtent - 200;
  }

  void _onChatDataChanged() {
    if (!mounted) return;
    _refreshRoom();
    final cached = ChatDataService.instance.getMessages(_contactUid);
    final previousLastId = _messages.isNotEmpty ? _messages.last.id : null;
    final countChanged = cached.length != _messages.length;
    final lastIdChanged = cached.isNotEmpty && cached.last.id != previousLastId;
    setState(() {
      _messages.clear();
      _messages.addAll(cached);
    });
    if ((countChanged || lastIdChanged) && _isNearBottom) {
      _scrollToBottom();
    }
    if (countChanged || lastIdChanged) {
      _markVisibleMessagesRead(previousLastId: previousLastId);
    }
  }

  void _loadChatRoom() {
    final chatData = ChatDataService.instance;
    final profile = chatData.getUser(_contactUid);
    _mentionUsers.clear();
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

    // Fetch profile to ensure we have latest data + avatar
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
      _groupEnterHint = enterHint.trim();
      _canModerateGroup = currentRole == 'owner' || currentRole == 'admin';
    });
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
    _scrollToBottom();

    // Add to cache BEFORE sending (so WS ack can find and update it)
    ChatDataService.instance.addSentMessage(_contactUid, userMessage);

    try {
      // Send via WebSocket, with REST fallback
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
        // REST fallback
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
    } catch (e) {
      talker.error('ChatDetail text send failed', e);
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
    // Update _messageCache
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
    // Update UI list
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
      // Web: bytes already in browser memory — no separate read needed
      bytes = platformFile.bytes;
    } else {
      filePath = platformFile.path!;
      fileName = path.basename(filePath);
      final file = File(filePath);
      // Get size WITHOUT reading the file into memory yet
      fileSize = await file.length();
    }

    // Early size check BEFORE allocating memory and BEFORE adding message to UI
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

    // Now read bytes (non-web only; web bytes already loaded above)
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToQuotedMessage(int mid) {
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
    final fraction = _messages.length <= 1
        ? 0.0
        : index / (_messages.length - 1);
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
                    onPressed: () =>
                        setState(() => _showGroupEnterHint = false),
                  ),
                ),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
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
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final previous = index > 0
                              ? _messages[index - 1]
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
                            movementDuration: const Duration(milliseconds: 120),
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
                                padding: const EdgeInsets.only(right: 24),
                                child: Icon(
                                  message.isMe ? Icons.forward : Icons.reply,
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
                              ),
                            ),
                          );
                        },
                      ),
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
