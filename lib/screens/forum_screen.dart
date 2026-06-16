import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../widgets/account/profile_picture.dart';
import '../utils/talker.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Forum>? _allForums;
  Set<String> _joinedIds = {};
  bool _isLoading = true;
  String? _error;

  List<Forum> get _joinedForums =>
      _allForums?.where((f) => _joinedIds.contains(f.id)).toList() ?? [];
  List<Forum> get _exploreForums =>
      _allForums?.where((f) => !_joinedIds.contains(f.id)).toList() ?? [];

  @override
  void initState() {
    super.initState();
    _loadForums();
  }

  Future<void> _loadForums() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = AuthState.instance.uid;
      final password = AuthState.instance.password;
      final results = await Future.wait([
        TfApiClient.instance.getForumList(),
        if (uid != null && password != null)
          TfApiClient.instance.getMyMemberships(uid, password),
      ]);
      if (mounted) {
        final memberships = results.length > 1
            ? results[1] as List<Map<String, int>>
            : <Map<String, int>>[];
        setState(() {
          _allForums = results[0] as List<Forum>;
          _joinedIds = memberships.map((m) => m['fid'].toString()).toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      talker.error('ForumScreen: getForumList failed', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _showCreateForumDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final nameController = TextEditingController();
    final introController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.forumCreateTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.forumPostTitle,
                  hintText: l10n.forumCreateTitleHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.forumPostTitleRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: introController,
                decoration: InputDecoration(
                  labelText: l10n.forumPostDescription,
                  hintText: l10n.forumCreateDescriptionHint,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final uid = AuthState.instance.uid;
              final password = AuthState.instance.password;
              if (uid == null || password == null) {
                Navigator.pop(context, false);
                return;
              }
              final name = nameController.text.trim();
              final intro = introController.text.trim();
              final success = await TfApiClient.instance.createForum(
                uid, password, name, intro.isNotEmpty ? intro : '',
              );
              if (!context.mounted) return;
              if (success) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.forumCreateSuccess)),
                );
                _loadForums();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.forumCreateFailed),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(l10n.forumPublish),
          ),
        ],
      ),
    );
    nameController.dispose();
    introController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoggedIn = AuthState.instance.isLoggedIn;

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
        floatingActionButton: isLoggedIn
            ? FloatingActionButton(
                onPressed: () => _showCreateForumDialog(context, l10n),
                child: const Icon(Icons.add),
              )
            : null,
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
                          forums: _joinedForums,
                          emptyMessage: l10n.forumNoJoined,
                          onReturn: () { if (mounted) _loadForums(); },
                        ),
                        _ForumListView(
                          forums: _exploreForums,
                          onReturn: () { if (mounted) _loadForums(); },
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
  final VoidCallback? onReturn;

  const _ForumListView({required this.forums, this.emptyMessage, this.onReturn});

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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: forums.length,
      itemBuilder: (context, index) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _ForumListTile(forum: forums[index], onReturn: onReturn),
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 4),
    );
  }
}

class _ForumListTile extends StatelessWidget {
  final Forum forum;
  final VoidCallback? onReturn;

  const _ForumListTile({required this.forum, this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await context.push('/forum/${forum.id}');
          onReturn?.call();
        },
        child: ListTile(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          leading: ProfilePictureWidget(
            avatarUrl: forum.avatarUrl,
            radius: 20,
            fallbackIcon: Icons.forum,
          ),
          title: Text(forum.name),
          subtitle: Text(
            forum.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
