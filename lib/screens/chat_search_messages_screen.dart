import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../utils/message_search.dart';
import '../widgets/ui/highlighted_text.dart';
import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import '../services/chat_data_service.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/refreshable.dart';

class ChatSearchMessagesScreen extends StatefulWidget {
  final String roomId;

  const ChatSearchMessagesScreen({super.key, required this.roomId});

  @override
  State<ChatSearchMessagesScreen> createState() =>
      _ChatSearchMessagesScreenState();
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
    final messages = await ChatDataService.instance.getSearchableMessages(
      widget.roomId,
    );
    if (!mounted) return;

    final results =
        messages
            .where(
              (message) => message.text.toLowerCase().contains(normalizedQuery),
            )
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _isSearching = false;
      _searchResults = results;
    });
  }

  /// 重跑一次本地搜索（可带到新同步下来的消息）。
  ///
  /// 空关键词直接返回：`contains('')` 恒真，会把整段历史当成搜索结果灌进来。
  Future<void> _refresh() async {
    if (_searchController.text.trim().isEmpty) return;
    await _executeSearch(_searchController.text);
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
                ? EmptyState(
                    icon: Symbols.search,
                    title: l10n.chatSearchMessagesHint,
                  )
                : _searchResults.isEmpty && !_isSearching
                // 空态也要能下拉重试（与其它列表屏一致）：最想刷新的时候
                // 恰好什么都没有的时候。
                ? PullToRefresh.content(
                    onRefresh: _refresh,
                    child: EmptyState(
                      icon: Symbols.search_off,
                      title: l10n.chatSearchMessagesNoResults,
                    ),
                  )
                : PullToRefresh.list(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                          subtitle: HighlightedText(
                            buildSearchExcerpt(
                              message.text,
                              _searchController.text,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Text(
                            _formatTime(message.timestamp),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          onTap: () {
                            // 返回对话界面并跳转到该消息的位置
                            Navigator.pop(context, message);
                          },
                        );
                      },
                    ),
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
