import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../utils/talker.dart';
import '../widgets/optimized_image.dart';

/// 群聊搜索界面。
///
/// 点击聊天界面右上角放大镜后进入；支持 Enter 或点击搜索按钮触发
/// `TfApiClient.instance.searchGroup`。`allow_direct_join = 0` 的群不展示。
class GroupSearchScreen extends StatefulWidget {
  const GroupSearchScreen({super.key});

  @override
  State<GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends State<GroupSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    unawaited(_initBaseUrl());
  }

  Future<void> _initBaseUrl() async {
    try {
      _baseUrl = await TfApiClient.instance.getBaseUrl();
    } catch (e) {
      talker.debug('GroupSearch: getBaseUrl failed', e);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static bool _allowsDirectJoin(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = const [];
        _hasSearched = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      List<Map<String, dynamic>> results;
      try {
        int number = int.parse(keyword);
        results = await TfApiClient.instance.infoGroup(number);
      } on FormatException {
        results = await TfApiClient.instance.searchGroup(keyword);
      }
      if (!mounted) return;
      setState(() {
        _results = results
            .where((g) => _allowsDirectJoin(g['allow_direct_join']))
            .toList();
        _loading = false;
      });
    } catch (e) {
      talker.error('GroupSearch: searchGroup failed', e);
      if (mounted) {
        setState(() {
          _results = const [];
          _loading = false;
        });
      }
    }
  }

  String? _avatarUrlFor(Map<String, dynamic> group) {
    final gid = (group['gid'] as num?)?.toInt();
    if (gid == null || _baseUrl == null) return null;
    return '$_baseUrl/avatar/get_avatar/group/$gid';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupSearchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: l10n.groupSearchHint,
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: l10n.groupSearchHint,
                  onPressed: _search,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? _buildEmptyState(context, l10n, colorScheme)
                    : _buildResultList(context, l10n, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 96, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            _hasSearched ? l10n.groupSearchNotFound : l10n.groupSearchStartHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildResultList(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
      itemBuilder: (context, index) {
        final group = _results[index];
        final gid = (group['gid'] as num?)?.toInt() ?? 0;
        final groupname = (group['groupname'] as String?) ?? '';
        final enterHint = (group['enter_hint'] as String?) ?? '';
        final introduction = (group['introduction'] as String?) ?? '';
        final avatarUrl = _avatarUrlFor(group);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: avatarUrl != null
                ? resizedImageProvider(
                    NetworkImage(avatarUrl),
                    MediaQuery.of(context).devicePixelRatio,
                    width: 48,
                    height: 48,
                  )
                : null,
            onBackgroundImageError: (_, _) {},
          ),
          title: Text(
            groupname,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (enterHint.isNotEmpty)
                Text(
                  enterHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (introduction.isNotEmpty)
                Text(
                  introduction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          onTap: () {
            context.push(
              '/group/$gid',
              extra: <String, dynamic>{
                'initialData': group,
                'groupName': groupname,
              },
            );
          },
        );
      },
    );
  }
}
