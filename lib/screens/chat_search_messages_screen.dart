import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/api_error.dart';
import '../models/message_model.dart';
import '../services/api/api_error_localization.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/chat_data_service.dart';
import '../services/snackbar_service.dart';
import '../utils/message_search.dart';
import '../utils/talker.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/highlighted_text.dart';
import '../widgets/ui/load_more_footer.dart';
import '../widgets/ui/refreshable.dart';

/// 会话内消息搜索
class ChatSearchMessagesScreen extends StatefulWidget {
  final String roomId;

  const ChatSearchMessagesScreen({super.key, required this.roomId});

  @override
  State<ChatSearchMessagesScreen> createState() =>
      _ChatSearchMessagesScreenState();
}

class _ChatSearchMessagesScreenState extends State<ChatSearchMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  /// 服务端最小关键词长度
  int _minLength = 2;

  String _query = '';

  /// 请求序号
  int _searchSeq = 0;

  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _serverErrorText;

  List<ChatMessage> _results = const <ChatMessage>[];
  final Set<String> _resultKeys = <String>{};

  /// 服务端返回结果中最小的 mid
  int? _serverCursorMid;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadServerConfig());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServerConfig() async {
    try {
      final config = await TfApiClient.instance.fetchServerInfo();
      final minLength = config?.minSearchLength ?? 0;
      if (!mounted || minLength <= 0 || minLength == _minLength) return;
      final length = _query.runes.length;
      final wasEligible = length >= _minLength;
      setState(() => _minLength = minLength);
      if (_query.isNotEmpty &&
          _searchDebounce?.isActive != true &&
          wasEligible != (length >= minLength)) {
        unawaited(_runSearch(_query));
      }
    } catch (e) {
      talker.debug('ChatSearchMessages: load server config failed', e);
    }
  }

  void _onChanged(String raw) {
    _searchDebounce?.cancel();
    final query = raw.trim();
    _searchSeq++;
    setState(() => _resetSearch(query));
    if (query.isEmpty) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_runSearch(query)),
    );
  }

  void _resetSearch(String query) {
    _query = query;
    _isSearching = query.isNotEmpty;
    _isLoadingMore = false;
    _hasMore = false;
    _serverErrorText = null;
    _results = const <ChatMessage>[];
    _resultKeys.clear();
    _serverCursorMid = null;
  }

  Future<void> _runSearch(String query) async {
    _searchDebounce?.cancel();
    final seq = ++_searchSeq;
    setState(() => _resetSearch(query));

    // 本地
    try {
      final local = await ChatDataService.instance.getSearchableMessages(
        widget.roomId,
      );
      if (!mounted || seq != _searchSeq) return;
      final normalized = query.toLowerCase();
      final hits = local
          .where(
            (message) =>
                !message.isDeleted &&
                message.text.toLowerCase().contains(normalized),
          )
          .toList();
      setState(() => _appendResults(hits));
    } catch (e) {
      talker.warning('ChatSearchMessages: local search failed', e);
    }

    // 服务端
    if (!mounted || seq != _searchSeq) return;
    if (query.runes.length < _minLength) {
      setState(() => _isSearching = false);
      return;
    }
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      setState(() => _isSearching = false);
      return;
    }

    try {
      final page = await ChatDataService.instance.searchRoomMessagesFromServer(
        widget.roomId,
        query,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _appendResults(page.messages);
        _serverCursorMid = _oldestMid(page.messages);
        _hasMore = page.hasMore && _serverCursorMid != null;
        _isSearching = false;
      });
      _scheduleAutoLoadMore();
    } on ApiErrorException catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _serverErrorText = localizeApiError(context, e.error);
        _isSearching = false;
      });
    } catch (e) {
      talker.error('ChatSearchMessages: server search failed', e);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _serverErrorText = AppLocalizations.of(context)!.commonLoadFailed;
        _isSearching = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isSearching || _isLoadingMore || !_hasMore) return;
    final cursor = _serverCursorMid;
    if (cursor == null) return;

    final seq = _searchSeq;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ChatDataService.instance.searchRoomMessagesFromServer(
        widget.roomId,
        _query,
        beforeMid: cursor,
      );
      if (!mounted || seq != _searchSeq) return;
      final nextCursor = _oldestMid(page.messages);
      setState(() {
        _appendResults(page.messages);
        _hasMore = page.hasMore && nextCursor != null && nextCursor < cursor;
        _serverCursorMid = nextCursor;
        _isLoadingMore = false;
      });
      _scheduleAutoLoadMore();
    } on ApiErrorException catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
      TouchFishSnackbarService.instance.show(
        localizeApiError(context, e.error),
        type: SnackbarType.error,
      );
    } catch (e) {
      talker.error('ChatSearchMessages: load more failed', e);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
      TouchFishSnackbarService.instance.show(
        AppLocalizations.of(context)!.commonFailedOperation,
        type: SnackbarType.error,
      );
    }
  }

  /// 结果不足
  void _scheduleAutoLoadMore() {
    if (!_hasMore || _isLoadingMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasMore || _isLoadingMore) return;
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent > 0) return;
      unawaited(_loadMore());
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 320) return;
    unawaited(_loadMore());
  }

  /// 按 mid/id 去重
  void _appendResults(Iterable<ChatMessage> incoming) {
    if (incoming.isEmpty) return;
    final merged = List<ChatMessage>.of(_results);
    for (final message in incoming) {
      final key = _resultKey(message);
      if (_resultKeys.add(key)) merged.add(message);
    }
    merged.sort(_compareResults);
    _results = merged;
  }

  static String _resultKey(ChatMessage message) {
    final mid = message.mid;
    if (mid != null) return 'mid:$mid';
    return 'id:${message.id}';
  }

  static int? _oldestMid(Iterable<ChatMessage> messages) {
    int? oldest;
    for (final message in messages) {
      final mid = message.mid;
      if (mid == null) continue;
      if (oldest == null || mid < oldest) oldest = mid;
    }
    return oldest;
  }

  static int _compareResults(ChatMessage a, ChatMessage b) {
    final byTime = b.timestamp.compareTo(a.timestamp);
    if (byTime != 0) return byTime;
    return (b.mid ?? 0).compareTo(a.mid ?? 0);
  }

  /// 重搜索
  Future<void> _refresh() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    await _runSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final hasQuery = _searchController.text.trim().isNotEmpty;

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
                          _onChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              onChanged: _onChanged,
              onSubmitted: (value) {
                final query = value.trim();
                if (query.isNotEmpty) unawaited(_runSearch(query));
              },
              autofocus: true,
            ),
          ),
          if (_serverErrorText != null && _results.isNotEmpty)
            _buildServerErrorHint(l10n, colorScheme),
          Expanded(
            child: !hasQuery
                ? EmptyState(
                    icon: Symbols.search,
                    title: l10n.chatSearchMessagesHint,
                  )
                : _results.isEmpty
                ? (_isSearching
                      ? const SizedBox.shrink()
                      : PullToRefresh.content(
                          onRefresh: _refresh,
                          child: _serverErrorText != null
                              ? ErrorState(
                                  title: l10n.commonLoadFailed,
                                  description: _serverErrorText,
                                  onRetry: () => unawaited(_refresh()),
                                  retryLabel: l10n.retry,
                                )
                              : EmptyState(
                                  icon: Symbols.search_off,
                                  title: l10n.chatSearchMessagesNoResults,
                                ),
                        ))
                : PullToRefresh.list(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _results.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _results.length) {
                          return LoadMoreFooter(
                            loading: _isLoadingMore,
                            hasMore: true,
                            showNoMore: false,
                          );
                        }
                        return _buildResultTile(context, l10n, _results[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerErrorHint(AppLocalizations l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Symbols.info, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _serverErrorText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(
    BuildContext context,
    AppLocalizations l10n,
    ChatMessage message,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final senderName =
        ChatDataService.instance.senderDisplayName(widget.roomId, message) ??
        l10n.chatDetailUnknownUser;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: message.isMe
            ? colorScheme.tertiaryContainer
            : colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          color: message.isMe
              ? colorScheme.onTertiaryContainer
              : colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        senderName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: HighlightedText(
        buildSearchExcerpt(message.text, _query),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Text(
        _formatTime(message.timestamp),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      onTap: () {
        Navigator.pop(context, message);
      },
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
