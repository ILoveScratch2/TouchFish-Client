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
import 'chat_room_settings_screen.dart';


class ChatDetailScreen extends StatefulWidget {
  final String roomId;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  ChatRoom? _currentRoom;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadChatRoom();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadChatRoom() {
    final allRooms = ChatDemoData.getDemoChatRooms();
    final allContacts = ChatDemoData.getDemoContacts();
    final l10n = AppLocalizations.of(context)!;
    _currentRoom = allRooms.firstWhere(
      (room) => room.id == widget.roomId,
      orElse: () {
        final contact = allContacts.firstWhere(
          (c) => c.id == widget.roomId,
          orElse: () => Contact(
            id: widget.roomId,
            name: l10n.chatDetailUnknownUser,
            avatar: null,
          ),
        );
        return ChatRoom(
          id: contact.id,
          name: contact.name,
          avatar: contact.avatar,
          type: ChatType.direct,
          lastMessage: null,
          lastMessageTime: null,
          unreadCount: 0,
          isPinned: false,
        );
      },
    );

    setState(() {});
    
    // examples
    if (_messages.isEmpty && widget.roomId == '1') {
      _messages.addAll([
        ChatMessage(
          id: '1',
          text: 'Welcome to use **TouchFish**!',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          isMe: false,
          senderName: _currentRoom?.name,
          type: MessageType.text,
        ),
        ChatMessage(
          id: '2',
          text: '''Now it supports **Markdown** rendering!

MARKDOWN:
- *italic text*
- **bold text**
- \`inline code\`

CODE:

\`\`\`dart
void main() {
  print('Hello, Flutter!');
}
\`\`\`''',
          timestamp: DateTime.now().subtract(const Duration(minutes: 9)),
          isMe: false,
          senderName: _currentRoom?.name,
          type: MessageType.text,
        ),
        ChatMessage(
          id: '3',
          text: '''It also supports tables:

| Feature | Status |
|------|------|
| TCP Trans | ✅ |
| Register API | ✅ |
| Info API | ✅ |
| Forum API | Developing |''',
          timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
          isMe: false,
          senderName: _currentRoom?.name,
          type: MessageType.text,
        ),
        ChatMessage(
          id: '4',
          text: r'It also supports math: $E = mc^2$ and $$\int_{0}^{\infty} e^{-x^2} dx = \frac{\sqrt{\pi}}{2}$$',
          timestamp: DateTime.now().subtract(const Duration(minutes: 7)),
          isMe: false,
          senderName: _currentRoom?.name,
          type: MessageType.text,
        ),
        ChatMessage(
          id: '5',
          text: 'You can disable Markdown rendering in the settings.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
          isMe: true,
          type: MessageType.text,
        ),
      ]);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      type: MessageType.text,
    );

    setState(() {
      _messages.add(userMessage);
    });

    _messageController.clear();
    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 500), () {
      final l10n = AppLocalizations.of(context)!;
      final replyMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: text,
        timestamp: DateTime.now(),
        isMe: false,
        senderName: _currentRoom?.name ?? l10n.chatDetailOther,
        senderAvatar: _currentRoom?.avatar,
        type: MessageType.text,
      );

      setState(() {
        _messages.add(replyMessage);
      });
      _scrollToBottom();
    });
  }

  void _sendMediaMessage(PlatformFile platformFile, MessageType type) {
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
      fileSize = file.lengthSync();
      if (type == MessageType.image && platformFile.bytes != null) {
        bytes = platformFile.bytes;
      }
    }

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

    final media = MessageMedia(
      path: filePath,
      fileName: fileName,
      fileSize: fileSize,
      bytes: bytes,
    );

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: messageText,
      timestamp: DateTime.now(),
      isMe: true,
      type: type,
      media: media,
    );

    setState(() {
      _messages.add(userMessage);
    });

    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 500), () {
      final l10n = AppLocalizations.of(context)!;
      final replyMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: messageText,
        timestamp: DateTime.now(),
        isMe: false,
        senderName: _currentRoom?.name ?? l10n.chatDetailOther,
        senderAvatar: _currentRoom?.avatar,
        type: type,
        media: media,
      );

      setState(() {
        _messages.add(replyMessage);
      });
      _scrollToBottom();
    });
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (_currentRoom == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.chatDetailLoading),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
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
            if (_currentRoom!.avatar != null)
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(_currentRoom!.avatar!),
                onBackgroundImageError: (_, __) {},
                child: _currentRoom!.avatar == null
                    ? Icon(
                        _currentRoom!.type == ChatType.group ? Icons.group : Icons.person,
                        size: 20,
                      )
                    : null,
              )
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  _currentRoom!.type == ChatType.group ? Icons.group : Icons.person,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatRoomSettingsScreen(
                    chatRoom: _currentRoom!,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        l10n.chatDetailNoMessages,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            ChatInputBar(
              controller: _messageController,
              onSend: _sendMessage,
              onFilePicked: _sendMediaMessage,
            ),
          ],
        ),
      ),
    );
  }
}
