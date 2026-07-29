import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';

class ForumSearchScreen extends StatefulWidget {
  final int? forumId;
  const ForumSearchScreen({super.key, this.forumId});
  @override State<ForumSearchScreen> createState() => _ForumSearchScreenState();
}

class _ForumSearchScreenState extends State<ForumSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _forums = const [];
  List<Map<String, dynamic>> _posts = const [];
  bool _loading = false;
  @override void dispose() { _controller.dispose(); _debounce?.cancel(); super.dispose(); }
  Future<void> _search(String value) async {
    if (value.trim().isEmpty) { setState(() { _forums = const []; _posts = const []; }); return; }
    setState(() => _loading = true);
    try {
      final result = await TfApiClient.instance.searchForum(value.trim(), forumId: widget.forumId);
      if (mounted) setState(() { _forums = (result['forums'] as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(); _posts = (result['posts'] as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
    appBar: AppBar(title: Text(widget.forumId == null ? l10n.forumSearchTitle : l10n.forumSearchPostsTitle)),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: SearchBar(controller: _controller, autoFocus: true, hintText: widget.forumId == null ? l10n.forumSearchHint : l10n.forumSearchCurrentForumHint, leading: const Icon(Icons.search), onChanged: (value) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 350), () => _search(value)); })),
      if (_loading) const LinearProgressIndicator(),
      Expanded(child: ListView(children: [
        if (_forums.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(l10n.forumSearchForumsHeader, style: const TextStyle(fontWeight: FontWeight.bold))),
        for (final forum in _forums) ListTile(leading: const Icon(Icons.forum_outlined), title: Text((forum['forum_name'] ?? '').toString()), subtitle: Text((forum['introduction'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => context.push('/forum/${forum['fid']}')),
        if (_posts.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(l10n.forumSearchPostsHeader, style: const TextStyle(fontWeight: FontWeight.bold))),
        for (final post in _posts) ListTile(leading: const Icon(Icons.article_outlined), title: Text((post['title'] ?? '').toString()), subtitle: Text((post['content'] ?? '').toString().replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis), onTap: () => context.push('/forum/${post['fid']}/post/${post['pid']}')),
      ])),
    ]),
  );}
}
