import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/local_message_search_result.dart';
import '../services/chat_data_service.dart';
import '../utils/talker.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';

class GlobalChatSearchScreen extends StatefulWidget {
  const GlobalChatSearchScreen({super.key});

  @override
  State<GlobalChatSearchScreen> createState() => _GlobalChatSearchScreenState();
}

class _GlobalChatSearchScreenState extends State<GlobalChatSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<LocalMessageSearchResult> _results = const [];
  bool _loading = false;
  bool _failed = false;
  int _searchSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final seq = ++_searchSeq;
    final query = value.trim();
    setState(() {
      _results = const [];
      _loading = query.isNotEmpty;
      _failed = false;
    });
    if (query.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await ChatDataService.instance.searchAllRoomsMessages(
          query,
        );
        if (mounted && seq == _searchSeq) {
          setState(() => _results = results);
        }
      } catch (e) {
        talker.error('GlobalChatSearch: search failed', e);
        if (mounted && seq == _searchSeq) setState(() => _failed = true);
      } finally {
        if (mounted && seq == _searchSeq) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rooms = {
      for (final room in ChatDataService.instance.rooms) room.id: room.name,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatSearchMessages)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: _search,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Symbols.search),
                hintText: l10n.chatSearchMessagesPlaceholder,
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _failed
                ? ErrorState(
                    title: l10n.commonLoadFailed,
                    onRetry: () => _search(_controller.text),
                    retryLabel: l10n.retry,
                  )
                : _results.isEmpty
                ? EmptyState(
                    icon: _controller.text.trim().isEmpty
                        ? Symbols.search
                        : Symbols.search_off,
                    title: _loading
                        ? l10n.searchInProgress
                        : _controller.text.trim().isEmpty
                        ? l10n.chatSearchMessagesHint
                        : l10n.chatSearchMessagesNoResults,
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return ListTile(
                        leading: const Icon(Symbols.forum),
                        title: Text(rooms[result.roomId] ?? result.roomId),
                        subtitle: Text(
                          result.message.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, result),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
