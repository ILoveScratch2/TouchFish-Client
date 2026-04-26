import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../services/api/tf_api_client.dart';
import '../utils/talker.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Forum>? _allForums;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadForums();
  }

  Future<void> _loadForums() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final forums = await TfApiClient.instance.getForumList();
      if (mounted) setState(() { _allForums = forums; _isLoading = false; });
    } catch (e) {
      talker.error('ForumScreen: getForumList failed', e);
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.forumTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.forumTabJoined),
              Tab(text: l10n.forumTabExplore),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.forumLoadFailed),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadForums,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadForums,
                    child: TabBarView(
                      children: [
                        _ForumListView(
                          forums: _allForums ?? [],
                          emptyMessage: l10n.forumNoJoined,
                        ),
                        _ForumListView(
                          forums: _allForums ?? [],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ForumListView extends StatelessWidget {
  final List<Forum> forums;
  final String? emptyMessage;

  const _ForumListView({required this.forums, this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (forums.isEmpty && emptyMessage != null) {
      return Center(
        child: Text(
          emptyMessage!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: forums.length,
        itemBuilder: (context, index) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _ForumListTile(forum: forums[index]),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(height: 4),
      ),
    );
  }
}

class _ForumListTile extends StatelessWidget {
  final Forum forum;
  const _ForumListTile({required this.forum});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        leading: Icon(
          Icons.forum,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(forum.name),
        subtitle: Text(
          forum.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/forum/${forum.id}'),
      ),
    );
  }
}
