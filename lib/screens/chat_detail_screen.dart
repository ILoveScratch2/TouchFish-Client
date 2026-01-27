import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../routes/app_routes.dart';
import '../l10n/app_localizations.dart';


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

  @override
  void initState() {
    super.initState();
    _loadChatRoom();
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
            status: 'offline',
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
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
    );

    setState(() {
      _messages.add(userMessage);
    });

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      final l10n = AppLocalizations.of(context)!;
      final replyMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: text,
        timestamp: DateTime.now(),
        isMe: false,
        senderName: _currentRoom?.name ?? l10n.chatDetailOther,
        senderAvatar: _currentRoom?.avatar,
      );

      setState(() {
        _messages.add(replyMessage);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
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
            ),
          ],
        ),
      ),
    );
  }
}
