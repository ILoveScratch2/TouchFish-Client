import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import '../models/user_profile.dart';
import '../services/auth_state.dart';
import '../services/chat_data_service.dart';
import 'data_saving_image.dart';
import 'markdown_renderer.dart';
import 'sheet_scaffold.dart';

/// 解析合并转发来源房间的展示名。
String redirectRoomDisplayName(AppLocalizations l10n, MergedForwardPreview p) {
  final name = p.sourceRoomName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  return p.sourceIsGroup ? l10n.mergedForwardGroup : l10n.mergedForwardPrivate;
}

/// 解析发送者资料：本人优先取当前登录用户，其次本地缓存。
///
/// 注意：uid 0 是合法的（例如 root 用户），只有负数才是无效值。
UserProfile? _resolveProfile(int? uid) {
  if (uid == null || uid < 0) return null;
  if (AuthState.instance.uid == uid) {
    final me = AuthState.instance.currentUser;
    if (me != null) return me;
  }
  return ChatDataService.instance.getUser('U$uid');
}

/// 解析合并转发条目的发送者显示名。
///
/// 优先级：快照冻结的昵称 → 本人资料 → 本地缓存资料 → UID 兜底。
/// 冻结昵称保证即使接收方离线、缓存缺失或资料拉取失败也能正确显示。
String redirectSenderName(
  int? uid,
  AppLocalizations l10n, {
  String? frozenName,
}) {
  final frozen = frozenName?.trim() ?? '';
  if (frozen.isNotEmpty) return frozen;

  if (uid == null || uid < 0) {
    return l10n.redirectUnknownSender;
  }

  final profile = _resolveProfile(uid);
  final name = profile?.username.trim() ?? '';
  if (name.isNotEmpty) return name;

  // 本人资料可能尚未进入缓存，但 AuthState 一定持有
  if (uid == AuthState.instance.uid) {
    final me = AuthState.instance.currentUser?.username.trim();
    if (me != null && me.isNotEmpty) return me;
  }

  // 保底：显示 UID（含 uid 0），而不是"未知发送者"
  return 'UID:$uid';
}

String? _senderAvatar(int? uid) {
  if (uid == null || uid < 0) return null;

  final profile = _resolveProfile(uid);
  if (profile?.avatar != null) return profile!.avatar;

  // 本人资料可能尚未进入缓存，但 AuthState 一定持有
  if (uid == AuthState.instance.uid) {
    return AuthState.instance.currentUser?.avatar;
  }

  return null;
}

/// 触发缺失发送者资料的补拉（后台进行，缓存后通知刷新）。
void _prefetchSenders(Iterable<int?> uids) {
  for (final uid in uids.toSet()) {
    if (uid == null || uid < 0) continue;
    if (_resolveProfile(uid) != null) continue;
    // 异步预加载，出错不影响显示
    ChatDataService.instance.ensureUserProfile(uid).catchError((e) {
      // 静默处理错误，不影响 UI 渲染
      debugPrint('Failed to prefetch sender profile for uid=$uid: $e');
    });
  }
}

class RedirectMessageCard extends StatelessWidget {
  final MergedForwardPreview redirect;
  final Color textColor;

  const RedirectMessageCard({
    super.key,
    required this.redirect,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sourceRoomName = redirectRoomDisplayName(l10n, redirect);
    final count = redirect.messageCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => RedirectHistorySheet(redirect: redirect),
          );
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryFixedDim.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Row(
            children: [
              Icon(Symbols.history, size: 16, color: textColor),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.redirectCardLabel(sourceRoomName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (count > 0)
                      Text(
                        l10n.redirectMessagesCount(count),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.82),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Symbols.chevron_right,
                size: 16,
                color: textColor.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RedirectInlineContent extends StatefulWidget {
  final MergedForwardPreview redirect;
  final Color textColor;

  const RedirectInlineContent({
    super.key,
    required this.redirect,
    required this.textColor,
  });

  @override
  State<RedirectInlineContent> createState() => _RedirectInlineContentState();
}

class _RedirectInlineContentState extends State<RedirectInlineContent> {
  @override
  void initState() {
    super.initState();
    _prefetchSenders(widget.redirect.messages.map((e) => e.senderUid));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final redirect = widget.redirect;
    final textColor = widget.textColor;
    final sourceRoomName = redirectRoomDisplayName(l10n, redirect);
    final entry = redirect.messages.isNotEmpty ? redirect.messages.first : null;
    final content = entry?.content ?? '';

    return ListenableBuilder(
      listenable: ChatDataService.instance,
      builder: (context, _) {
        final resolvedName = entry == null
            ? null
            : redirectSenderName(
                entry.senderUid,
                l10n,
                frozenName: entry.senderName,
              );
        final resolvedAvatar = entry == null
            ? null
            : _senderAvatar(entry.senderUid);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Symbols.subdirectory_arrow_right,
                  size: 14,
                  color: textColor.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                _SenderAvatar(avatar: resolvedAvatar, radius: 8),
                const SizedBox(width: 4),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (resolvedName != null &&
                            resolvedName.trim().isNotEmpty) ...[
                          TextSpan(
                            text: resolvedName,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: ' · ',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        TextSpan(
                          text: l10n.redirectFromRoom(sourceRoomName),
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (content.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: MarkdownRenderer(data: content, selectable: true),
              ),
          ],
        );
      },
    );
  }
}

class RedirectHistorySheet extends StatefulWidget {
  final MergedForwardPreview redirect;

  const RedirectHistorySheet({super.key, required this.redirect});

  @override
  State<RedirectHistorySheet> createState() => _RedirectHistorySheetState();
}

class _RedirectHistorySheetState extends State<RedirectHistorySheet> {
  @override
  void initState() {
    super.initState();
    _prefetchSenders(widget.redirect.messages.map((e) => e.senderUid));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final redirect = widget.redirect;
    final sourceRoomName = redirectRoomDisplayName(l10n, redirect);
    final messages = redirect.messages;

    return ListenableBuilder(
      listenable: ChatDataService.instance,
      builder: (context, _) => SheetScaffold(
        titleText: l10n.redirectHistoryTitle(sourceRoomName),
        child: messages.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (redirect.messageCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        l10n.redirectMessagesCount(redirect.messageCount),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 1 / MediaQuery.devicePixelRatioOf(context),
                      ),
                      itemBuilder: (context, index) {
                        final entry = messages[index];
                        final senderName = redirectSenderName(
                          entry.senderUid,
                          l10n,
                          frozenName: entry.senderName,
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SenderAvatar(
                                avatar: _senderAvatar(entry.senderUid),
                                radius: 12,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      senderName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (entry.content.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: MarkdownRenderer(
                                          data: entry.content.trim(),
                                          selectable: true,
                                        ),
                                      ),
                                    if (entry.fileHash != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          entry.fileName ?? entry.fileHash!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.redirectNoContent,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SenderAvatar extends StatelessWidget {
  final String? avatar;
  final double radius;

  const _SenderAvatar({required this.avatar, required this.radius});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      child: avatar != null
          ? ClipOval(
              child: DataSavingImage(
                url: avatar!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
              ),
            )
          : Icon(
              Icons.person,
              size: radius * 1.2,
              color: colorScheme.onPrimaryContainer,
            ),
    );
  }
}
