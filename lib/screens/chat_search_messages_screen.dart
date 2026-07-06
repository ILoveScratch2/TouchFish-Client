import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import '../services/chat_data_service.dart';

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
  Timer? _searchDebounce;
  bool _isSearching = false;
  List<ChatMessage> _searchResults = [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

    _searchDebounce?.cancel();
    setState(() {
      _isSearching = true;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    var messages = ChatDataService.instance.getMessages(widget.roomId);
    if (messages.isEmpty) {
      messages = await ChatDataService.instance.refreshMessagesForContact(widget.roomId);
    }
    if (!mounted) return;

    final results = messages
        .where((message) => message.text.toLowerCase().contains(normalizedQuery))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _isSearching = false;
      _searchResults = results;
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
