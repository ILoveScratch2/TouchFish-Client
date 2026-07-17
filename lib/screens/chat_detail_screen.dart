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
import 'group_management_screen.dart';


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
  ChatRoom? _currentRoom;
  final List<MentionUser> _mentionUsers = [];
  bool _isInitialized = false;
  bool _wsConnected = false;
  bool _avatarLoadFailed = false;
  bool _isLoadingOlder = false;
  bool _hasMoreMessages = true;
  bool _realtimeListenersAttached = false;
  StreamSubscription? _ackErrorSub;

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
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)),
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
    final hasNewVisibleTail = previousLastId == null || lastMsg.id != previousLastId;
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
    // Trigger when user scrolls near the top
    if (_scrollController.position.pixels < 50) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_isLoadingOlder) return;

    setState(() => _isLoadingOlder = true);

    final oldLen = _messages.length;
    final oldOffset = _scrollController.hasClients ? _scrollController.position.pixels : 0.0;
    final oldMax = _scrollController.hasClients ? _scrollController.position.maxScrollExtent : 0.0;
    final merged = await ChatDataService.instance.loadOlderMessages(_contactUid);

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
      if (_currentRoom?.name != updated.name || _currentRoom?.avatar != updated.avatar) {
        _avatarLoadFailed = false;
        _currentRoom = updated;
        if (mounted) setState(() {});
      }
    } else if (!_contactUid.startsWith('G')) {
      // Profile not cached — fetch for direct chats
      final targetUid = _contactUid.startsWith('U') ? int.tryParse(_contactUid.substring(1)) : null;
      if (targetUid != null) {
        TfApiClient.instance.getUserByUid(targetUid).then((p) {
          if (p != null && mounted) {
            talker.info('ChatDetail: refreshRoom fetched uid=${p.uid} avatar=${p.avatar}');
            chatData.cacheUserProfile(p);
            _avatarLoadFailed = false;
            setState(() {
              _currentRoom = ChatRoom(
                id: _contactUid,
                name: chatData.displayNameForRoom(_contactUid, p.username),
                avatar: p.avatar,
                type: _contactUid.startsWith('G') ? ChatType.group : ChatType.direct,
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
    return pos.pixels >= pos.maxScrollExtent - 100;
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

    _currentRoom = ChatRoom(
      id: _contactUid,
      name: chatData.displayNameForRoom(
        _contactUid,
        profile?.username ?? (_contactUid.startsWith('G') ? 'Group ${_contactUid.substring(1)}' : _contactUid),
      ),
      avatar: profile?.avatar,
      type: _contactUid.startsWith('G') ? ChatType.group : ChatType.direct,
    );
    _avatarLoadFailed = false;
    setState(() {});

    // Fetch profile to ensure we have latest data + avatar
    final targetUid = _contactUid.startsWith('U') ? int.tryParse(_contactUid.substring(1)) : null;
    if (targetUid != null) {
      TfApiClient.instance.getUserByUid(targetUid).then((p) {
        if (p != null && mounted) {
          talker.info('ChatDetail: fetched profile uid=${p.uid} avatar=${p.avatar}');
          chatData.cacheUserProfile(p);
          _avatarLoadFailed = false;
          setState(() {
            _currentRoom = ChatRoom(
              id: _contactUid,
              name: chatData.displayNameForRoom(_contactUid, p.username),
              avatar: p.avatar,
              type: _contactUid.startsWith('G') ? ChatType.group : ChatType.direct,
            );
          });
        }
      });
    }
  }

  void _sendMessage() {
    unawaited(_sendMessageAsync());
  }

  Future<void> _sendMessageAsync() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
    final userMessage = ChatMessage(
      id: clientMid,
      clientMid: clientMid,
      mid: null,
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.pending,
      type: MessageType.text,
    );

    setState(() => _messages.add(userMessage));
    _messageController.clear();
    _scrollToBottom();

    // Add to cache BEFORE sending (so WS ack can find and update it)
    ChatDataService.instance.addSentMessage(_contactUid, userMessage);

    try {
      // Send via WebSocket, with REST fallback
      bool wsSent = false;
      if (_wsConnected) {
        if (_contactUid.startsWith('G')) {
          final gid = int.tryParse(_contactUid.substring(1));
          if (gid != null) {
            wsSent = await ChatWsService.instance.sendGroupTextMessage(
              gid,
              text,
              clientMid: clientMid,
            );
          }
        } else {
          final targetUid = int.tryParse(_contactUid.substring(1));
          if (targetUid != null) {
            wsSent = await ChatWsService.instance.sendTextMessage(
              targetUid.toString(),
              text,
              clientMid: clientMid,
            );
          }
        }
      }
      if (!wsSent) {
        // REST fallback
        final recipient = _contactUid;
        final result = await TfApiClient.instance.sendMessage(uid, password,
          recipient: recipient, content: text, clientMid: clientMid,
        );
        if (result != null) {
          final mid = (result['mid'] as num?)?.toInt();
          _updateMessageStatus(clientMid, mid: mid, status: MessageStatus.sent);
        } else {
          _updateMessageStatus(clientMid, status: MessageStatus.failed);
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.chatSendFailed), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
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
          SnackBar(content: Text(l10n.chatSendFailed), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _updateMessageStatus(String clientMid, {int? mid, MessageStatus? status}) {
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

  Future<void> _sendMediaMessage(PlatformFile platformFile, MessageType type) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    String filePath;
    String fileName;
    int fileSize;
    List<int>? bytes;

    if (kIsWeb) {
      fileName = platformFile.name;
      filePath = 'web_upload_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      fileSize = platformFile.bytes?.length ?? 0;
      bytes = platformFile.bytes;
    } else {
      filePath = platformFile.path!;
      fileName = path.basename(filePath);
      final file = File(filePath);
      fileSize = await file.length();
      bytes = platformFile.bytes ?? await file.readAsBytes();
    }

    String messageText = '';
    switch (type) {
      case MessageType.image: messageText = '[IMAGE]'; break;
      case MessageType.video: messageText = '[VIDEO]'; break;
      case MessageType.audio: messageText = '[AUDIO]'; break;
      case MessageType.file: messageText = '[FILE] $fileName'; break;
      default: messageText = fileName;
    }

    final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
    final media = MessageMedia(path: filePath, fileName: fileName, fileSize: fileSize, bytes: bytes);
    final userMessage = ChatMessage(
      id: clientMid,
      clientMid: clientMid,
      text: messageText,
      timestamp: DateTime.now(),
      isMe: true,
      type: type,
      media: media,
      status: MessageStatus.pending,
    );

    setState(() => _messages.add(userMessage));
    ChatDataService.instance.addSentMessage(_contactUid, userMessage);
    _scrollToBottom();

    if (bytes == null) {
      _updateMessageStatus(clientMid, status: MessageStatus.failed);
      return;
    }

    final maxSize = await TfApiClient.instance.getMaxFileSize();
    if (maxSize != null && bytes.length > maxSize) {
      _updateMessageStatus(clientMid, status: MessageStatus.failed);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.storageFileTooLarge((maxSize / (1024 * 1024)).round()))),
        );
      }
      return;
    }

    try {
      final fileBase64 = base64.encode(bytes);
      final response = await TfApiClient.instance.uploadFile(uid, password, fileName, fileBase64);
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
            );
          }
        } else {
          final peerUid = int.tryParse(_contactUid.substring(1));
          if (peerUid != null) {
            wsSent = await ChatWsService.instance.sendFileMessage(
              peerUid.toString(),
              hash,
              clientMid: clientMid,
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
        );
        if (result != null) {
          final mid = (result['mid'] as num?)?.toInt();
          _updateMessageStatus(clientMid, mid: mid, status: MessageStatus.sent);
        } else {
          _updateMessageStatus(clientMid, status: MessageStatus.failed);
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.chatSendFailed), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
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
          SnackBar(content: Text(l10n.chatSendFailed), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
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
        talker.warning('Avatar load failed for ${_currentRoom!.id}: $avatarUrl');
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
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go(AppRoutes.chat))
            : null,
        automaticallyImplyLeading: false,
        backgroundColor: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            _buildAvatar(colorScheme),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_currentRoom!.name, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                if (_currentRoom!.type == ChatType.group)
                  Text(l10n.chatDetailGroupChat, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              ]),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {
            if (_currentRoom!.type == ChatType.group) {
              final gid = int.tryParse(widget.roomId.replaceFirst('G', ''));
              if (gid != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GroupManagementScreen(gid: gid, groupName: _currentRoom!.name),
                ));
              }
            } else {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatRoomSettingsScreen(chatRoom: _currentRoom!),
              ));
            }
          }),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(
                              child: Text(l10n.chatDetailNoMessages, textAlign: TextAlign.center,
                                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                        itemBuilder: (context, index) => MessageBubble(message: _messages[index]),
                      ),
                    ),
            ),
            ChatInputBar(
              controller: _messageController, onSend: _sendMessage,
              onFilePicked: _sendMediaMessage, mentionUsers: _mentionUsers,
            ),
          ],
        ),
      ),
    );
  }
}
