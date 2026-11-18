import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../models/support_ticket.dart';
import '../models/user_profile.dart';
import '../services/api/tf_api_client.dart';
import '../services/forum_data_bus.dart';
import '../services/snackbar_service.dart';
import '../theme/tokens.dart';
import '../utils/talker.dart';
import 'account/profile_picture.dart';
import 'forum_attachments.dart';
import 'markdown_renderer.dart';
import 'sticker_text_renderer.dart';
import 'support/ticket_compose_sheet.dart';

/// 贴纸渲染
final _stickerTestPatternFd = RegExp(r':[A-Za-z0-9_]+\+[A-Za-z0-9_-]+:');

enum _PostMenuAction { copy, report, delete }

class ForumPostCard extends StatefulWidget {
  final ForumPost post;
  final VoidCallback? onTap;
  final Map<String, UserProfile?>? profileCache;
  final bool enableMarkdown;

  /// 右侧栏正在阅读
  final bool selected;

  /// 当前用户是否有权删除
  final bool canDelete;
  final VoidCallback? onDelete;

  const ForumPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.profileCache,
    this.enableMarkdown = true,
    this.selected = false,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  State<ForumPostCard> createState() => _ForumPostCardState();
}

class _ForumPostCardState extends State<ForumPostCard> {
  UserProfile? _author;
  int _commentCount = 0;
  String? _lastCommentUid;
  String? _lastCommentContent;
  UserProfile? _featuredCommentAuthor;
  bool _loaded = false;

  static final Map<int, Future<UserProfile?>> _authorRequests = {};

  static Future<UserProfile?> _fetchAuthor(int uid) {
    final existing = _authorRequests[uid];
    if (existing != null) return existing;
    final future = TfApiClient.instance.getUserByUid(uid).whenComplete(() {
      _authorRequests.remove(uid);
    });
    _authorRequests[uid] = future;
    return future;
  }

  /// 评论摘要请求去重与缓存
  static final Map<String, Future<List<ForumComment>>> _commentRequests = {};
  static const int _commentCacheLimit = 200;

  static Future<List<ForumComment>> _fetchComments(int fid, int pid) {
    final key = '$fid/$pid';
    final cached = _commentRequests[key];
    if (cached != null) return cached;

    if (_commentRequests.length >= _commentCacheLimit) {
      _commentRequests.clear();
    }
    final future = TfApiClient.instance.getAllComments(fid, pid);
    _commentRequests[key] = future;
    future.catchError((Object _) {
      _commentRequests.remove(key);
      return const <ForumComment>[];
    });
    return future;
  }

  ForumPost get post => widget.post;

  @override
  void initState() {
    super.initState();
    ForumDataBus.instance.change.addListener(_onForumChanged);
    _loadData();
  }

  @override
  void dispose() {
    ForumDataBus.instance.change.removeListener(_onForumChanged);
    super.dispose();
  }

  void _onForumChanged() {
    final pid = post.id;
    if (!ForumDataBus.instance.change.value.affects(pid)) return;
    final fid = int.tryParse(post.forumId);
    if (fid != null) _commentRequests.remove('$fid/$pid');
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ForumPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPost = oldWidget.post;
    final newPost = widget.post;
    // 左栏刷新回来的是新实例、同一 id：只比 id 会让评论数永远停在旧值。
    if (oldPost.id != newPost.id ||
        oldPost.authorUid != newPost.authorUid ||
        oldPost.commentCount != newPost.commentCount ||
        oldPost.lastCommentUid != newPost.lastCommentUid ||
        oldPost.lastCommentContent != newPost.lastCommentContent) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      await _loadDataInner();
    } catch (e) {
      talker.error('ForumDetailScreen: post card load failed', e);
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _loadDataInner() async {
    final fid = int.tryParse(post.forumId);
    final pid = int.tryParse(post.id);
    final authorUid = post.authorUid;
    final cache = widget.profileCache;

    UserProfile? author;
    var commentCount = post.commentCount;
    var lastCommentUid = post.lastCommentUid;
    var lastCommentContent = post.lastCommentContent;
    UserProfile? featuredAuthor;

    if (cache != null && cache.containsKey(authorUid)) {
      author = cache[authorUid];
    } else {
      final uid = int.tryParse(authorUid);
      if (uid != null) {
        author = await _fetchAuthor(uid);
        cache?[authorUid] = author;
      }
    }
    // 新服务端在列表里直接带评论摘要；没有摘要时才退回逐帖拉取（旧服务器）
    if (lastCommentUid == null || lastCommentContent == null) {
      if (fid != null && pid != null) {
        final comments = await _fetchComments(fid, pid);
        commentCount = comments.length;
        if (comments.isNotEmpty) {
          lastCommentUid = comments.last.authorUid;
          lastCommentContent = comments.last.content;
        }
      }
    }
    if (lastCommentUid != null) {
      if (cache != null && cache.containsKey(lastCommentUid)) {
        featuredAuthor = cache[lastCommentUid];
      } else {
        final uid = int.tryParse(lastCommentUid);
        if (uid != null) {
          featuredAuthor = await _fetchAuthor(uid);
          cache?[lastCommentUid] = featuredAuthor;
        }
      }
    }

    if (mounted) {
      setState(() {
        _author = author;
        _commentCount = commentCount;
        _lastCommentUid = lastCommentUid;
        _lastCommentContent = lastCommentContent;
        _featuredCommentAuthor = featuredAuthor;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 由列表下发
    final enableMarkdown = widget.enableMarkdown;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final author = _author;
    final commentCount = _commentCount;
    final lastCommentContent = _lastCommentContent;
    final hasCommentPreview =
        lastCommentContent != null && lastCommentContent.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      color: widget.selected
          ? colorScheme.secondaryContainer.withValues(alpha: 0.45)
          : null,
      child: InkWell(
        borderRadius: TFRadius.cardRadius,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfilePictureWidget(
                    avatarUrl: author?.avatar,
                    radius: 16,
                    fallbackText: author?.username ?? post.authorUid,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author?.username ?? 'UID:${post.authorUid}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          _formatDate(post.createdAt),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (post.isPinned)
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  PopupMenuButton<_PostMenuAction>(
                    tooltip: l10n.forumMore,
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onSelected: (action) => _handleMenu(context, action),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _PostMenuAction.copy,
                        child: _menuRow(Icons.copy, l10n.forumCopyContent),
                      ),
                      PopupMenuItem(
                        value: _PostMenuAction.report,
                        child: _menuRow(Icons.flag_outlined, l10n.ticketReport),
                      ),
                      if (widget.canDelete)
                        PopupMenuItem(
                          value: _PostMenuAction.delete,
                          child: _menuRow(
                            Icons.delete_outline,
                            l10n.forumPostDelete,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (post.title.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (_stickerTestPatternFd.hasMatch(post.content))
                StickerTextRenderer(
                  text: previewMarkdown(post.content),
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else if (enableMarkdown)
                MarkdownRenderer(
                  data: previewMarkdown(post.content),
                )
              else
                Text(
                  previewMarkdown(post.content),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (post.content.trim().runes.length > 200)
                Padding(
                  padding: const EdgeInsets.only(top: TFSpace.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.more_horiz,
                        size: TFSize.iconXs,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        l10n.forumPostTruncated,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              // 评论数只出现一次
              if (!_loaded)
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '...',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              else if (!hasCommentPreview)
                Row(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$commentCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              if (hasCommentPreview)
                _buildCommentPreview(
                  context,
                  _lastCommentUid ?? '',
                  lastCommentContent,
                  commentCount,
                ),
              if (post.attachments.isNotEmpty)
                ForumAttachmentsRow(attachments: post.attachments),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: TFSize.iconSm),
        const SizedBox(width: TFSpace.md),
        Text(label),
      ],
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    _PostMenuAction action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case _PostMenuAction.copy:
        await Clipboard.setData(ClipboardData(text: widget.post.content));
        if (!context.mounted) return;
        TouchFishSnackbarService.instance.show(l10n.forumCopied);
      case _PostMenuAction.report:
        await showTicketComposeSheet(
          context,
          type: TicketType.report,
          targetType: 'post',
          targetId: '${widget.post.forumId}:${widget.post.id}',
          initialTitle: l10n.ticketReport,
        );
      case _PostMenuAction.delete:
        widget.onDelete?.call();
    }
  }

  Widget _buildCommentPreview(
    BuildContext context,
    String commentAuthorUid,
    String commentContent,
    int commentCount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final commentAuthor = _featuredCommentAuthor;
    final displayName =
        commentAuthor?.username ?? 'UID:$commentAuthorUid';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.forumComments(commentCount),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ProfilePictureWidget(
                  avatarUrl: commentAuthor?.avatar,
                  radius: 12,
                  fallbackText: displayName,
                ),
                const SizedBox(width: 8),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    commentContent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
