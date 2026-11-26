import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/refreshable.dart';

class ForumSearchScreen extends StatefulWidget {
  final int? forumId;

  const ForumSearchScreen({super.key, this.forumId});

  @override
  State<ForumSearchScreen> createState() => _ForumSearchScreenState();
}

class _ForumSearchScreenState extends State<ForumSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _searchSequence = 0;
  List<Map<String, dynamic>> _forums = const [];
  List<Map<String, dynamic>> _posts = const [];
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    final sequence = ++_searchSequence;
    setState(() {
      _forums = const [];
      _posts = const [];
      _loading = query.isNotEmpty;
      _failed = false;
    });
    if (query.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search(query, sequence));
    });
  }

  Future<void> _refresh() async {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final sequence = ++_searchSequence;
    setState(() {
      _loading = true;
      _failed = false;
    });
    await _search(query, sequence);
  }

  Future<void> _search(String query, int sequence) async {
    try {
      final result = await TfApiClient.instance.searchForum(
        query,
        forumId: widget.forumId,
      );
      if (!mounted || sequence != _searchSequence) return;
      final forums = _readRows(result['forums']);
      final posts = _readRows(result['posts']);
      setState(() {
        _forums = forums;
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || sequence != _searchSequence) return;
      setState(() {
        _forums = const [];
        _posts = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  List<Map<String, dynamic>> _readRows(Object? rows) {
    if (rows is! List) return const [];
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hint = widget.forumId == null
        ? l10n.forumSearchHint
        : l10n.forumSearchCurrentForumHint;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.forumId == null
              ? l10n.forumSearchTitle
              : l10n.forumSearchPostsTitle,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              controller: _controller,
              autoFocus: true,
              hintText: hint,
              leading: const Icon(Icons.search),
              onChanged: _onChanged,
              onSubmitted: (_) => unawaited(_refresh()),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(child: _buildResults(l10n, hint)),
        ],
      ),
    );
  }

  Widget _buildResults(AppLocalizations l10n, String hint) {
    if (_failed) {
      return ErrorState(
        title: l10n.commonLoadFailed,
        onRetry: _refresh,
        retryLabel: l10n.retry,
      );
    }
    if (_forums.isEmpty && _posts.isEmpty) {
      final isEmpty = _controller.text.trim().isEmpty;
      return EmptyState(
        icon: isEmpty ? Icons.search : Icons.search_off,
        title: isEmpty
            ? hint
            : _loading
            ? l10n.searchInProgress
            : l10n.searchNoResults,
      );
    }
    return PullToRefresh.list(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_forums.isNotEmpty) _heading(l10n.forumSearchForumsHeader),
          for (final forum in _forums)
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text((forum['forum_name'] ?? '').toString()),
              subtitle: Text(
                (forum['introduction'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => context.push('/forum/${forum['fid']}'),
            ),
          if (_posts.isNotEmpty) _heading(l10n.forumSearchPostsHeader),
          for (final post in _posts)
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text((post['title'] ?? '').toString()),
              subtitle: Text(
                (post['content'] ?? '').toString().replaceAll('\n', ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () =>
                  context.push('/forum/${post['fid']}/post/${post['pid']}'),
            ),
        ],
      ),
    );
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
  );
}
