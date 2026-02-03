import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/message_model.dart';

class ChatSearchMessagesScreen extends StatefulWidget {
  final String roomId;

  const ChatSearchMessagesScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<ChatSearchMessagesScreen> createState() => _ChatSearchMessagesScreenState();
}

class _ChatSearchMessagesScreenState extends State<ChatSearchMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<ChatMessage> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      final demoResults = [
        ChatMessage(
          id: '1',
          text: '这是一条包含"${query}"的示例消息',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isMe: false,
          senderName: 'XSFX',
        ),
        ChatMessage(
          id: '2',
          text: '另一条相关的消息提到了${query}',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isMe: true,
        ),
        ChatMessage(
          id: '3',
          text: '还有一条关于${query}的讨论',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          isMe: false,
          senderName: 'Piaoztsdy',
        ),
      ];

      setState(() {
        _isSearching = false;
        _searchResults = demoResults;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatSearchMessages),
        bottom: _isSearching
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.chatSearchMessagesPlaceholder,
                prefixIcon: const Icon(Symbols.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Symbols.close),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              onChanged: _performSearch,
              autofocus: true,
            ),
          ),

          // Search results
          Expanded(
            child: _searchController.text.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Symbols.search,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.chatSearchMessagesHint,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty && !_isSearching
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Symbols.search_off,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.chatSearchMessagesNoResults,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final message = _searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(
                                Icons.person,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            title: Text(
                              message.senderName ?? l10n.chatDetailOther,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              message.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              _formatTime(message.timestamp),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            onTap: () {
                              // 应该导航到对应消息的位置，但这里并没有
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return '${time.month}/${time.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}
