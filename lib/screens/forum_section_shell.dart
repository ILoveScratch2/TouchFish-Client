import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/settings_service.dart';
import '../utils/wide_screen_helper.dart';
import '../widgets/layout/forum_post_pane_scope.dart';
import '../widgets/layout/section_two_pane_shell.dart';
import 'forum_detail_screen.dart';
import 'forum_screen.dart';

/// 论坛区
class ForumSectionShell extends StatefulWidget {
  /// 当前路由位置（`/forum`、`/forum/:id`、`/forum/:id/post/:pid`）。
  final String location;

  /// 右侧内容（嵌套子路由）。
  final Widget child;

  const ForumSectionShell({
    super.key,
    required this.location,
    required this.child,
  });

  /// 解析论坛区位置：论坛 id、帖子 id、是否搜索页
  @visibleForTesting
  static ({String? forumId, String? postId, bool isSearch}) parseLocation(
    String location,
  ) {
    final segments = Uri.parse(location).pathSegments;
    if (segments.length < 2 || segments[0] != 'forum') {
      return (forumId: null, postId: null, isSearch: false);
    }
    final segment = segments[1];
    if (segment == 'search') {
      return (forumId: null, postId: null, isSearch: true);
    }
    if (segment.isEmpty) {
      return (forumId: null, postId: null, isSearch: false);
    }
    final postId = segments.length >= 4 && segments[2] == 'post'
        ? segments[3]
        : null;
    return (forumId: segment, postId: postId, isSearch: false);
  }

  @override
  State<ForumSectionShell> createState() => _ForumSectionShellState();
}

class _ForumSectionShellState extends State<ForumSectionShell> {
  bool _postFullScreen = false;
  String? _postFullScreenId;

  @override
  void initState() {
    super.initState();
    SettingsService.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  bool _isPostFullScreen(String? postId) =>
      postId != null && _postFullScreen && _postFullScreenId == postId;

  void _togglePostFullScreen(String? postId) {
    setState(() {
      final next = !_isPostFullScreen(postId);
      _postFullScreen = next;
      _postFullScreenId = postId;
    });
  }

  Widget _buildPostPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.forumSelectPostPlaceholder,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = ForumSectionShell.parseLocation(widget.location);
    final forumId = route.forumId;
    final splitAllowed =
        WideScreenHelper.forumTwoPane(context) && !route.isSearch;
    final split =
        splitAllowed &&
        (route.postId != null || !WideScreenHelper.forumHideEmptyPane);
    final postFullScreen = _isPostFullScreen(route.postId);
    final twoPane = split && !postFullScreen;

    final Widget left;
    Widget right = widget.child;
    if (!splitAllowed) {
      left = widget.child;
    } else if (forumId == null) {
      left = ForumScreen(isAside: split);
    } else if (postFullScreen) {
      left = _wrapPostPane(context, route.postId, widget.child);
    } else {
      left = ForumDetailScreen(
        key: ValueKey('forum-$forumId'),
        forumId: forumId,
        isAside: split,
        openPostId: route.postId,
      );
      if (split && route.postId == null) {
        right = _buildPostPlaceholder(context);
      } else if (split) {
        right = _wrapPostPane(context, route.postId, widget.child);
      }
    }

    return SectionTwoPaneShell(
      storageKeyPrefix: 'forum',
      twoPane: twoPane,
      list: left,
      child: right,
    );
  }

  Widget _wrapPostPane(BuildContext context, String? postId, Widget child) {
    return ForumPostPaneScope(
      fullScreen: _isPostFullScreen(postId),
      toggleFullScreen: () => _togglePostFullScreen(postId),
      child: child,
    );
  }
}
