import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';

class ForumScreen extends StatelessWidget {
  const ForumScreen({super.key});

  // Demo: current user uid
  static const _currentUserUid = '1';

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
        body: TabBarView(
          children: [
            _ForumListView(
              forums: ForumDemoData.getJoinedForums(_currentUserUid),
              emptyMessage: l10n.forumNoJoined,
            ),
            _ForumListView(
              forums: ForumDemoData.getDemoForums(),
            ),
          ],
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
