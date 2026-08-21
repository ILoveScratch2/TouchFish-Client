import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/chat_data_service.dart';
import '../services/snackbar_service.dart';
import '../widgets/optimized_image.dart';

/// 群精华消息列表页。
///
/// 通过 [TfApiClient.queryEssence] 获取精华消息编号（mid），
/// 再结合本地缓存/服务器历史解析出真正的 [ChatMessage] 内容进行展示，
/// 并依照 mid 降序排列。
///
/// 若当前用户拥有管理员/群主权限，则每条消息右侧显示红色 auto_awesome
/// 按钮，点击后调用 [TfApiClient.removeEssence] 移除精华并刷新列表。
class GroupEssenceScreen extends StatefulWidget {
  final int gid;
  final String groupName;

  const GroupEssenceScreen({
    super.key,
    required this.gid,
    required this.groupName,
  });

  @override
  State<GroupEssenceScreen> createState() => _GroupEssenceScreenState();
}

class _GroupEssenceScreenState extends State<GroupEssenceScreen> {
  List<int> _essenceMids = [];
  final Map<int, ChatMessage?> _messages = {};
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _loadFailed = false;

  int get _uid => AuthState.instance.uid ?? 0;
  String get _password => AuthState.instance.password ?? '';

  List<int> get _sortedMids {
    final mids = [..._essenceMids]..sort((a, b) => b.compareTo(a));
    return mids;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    final uid = _uid;
    final password = _password;
    try {
      final result = await TfApiClient.instance.queryEssence(
        uid,
        password,
        widget.gid,
      );
      if (result == null) throw StateError('Failed to load essence messages');
      final mids = result.mids;
      final roomId = 'G${widget.gid}';
      final chatData = ChatDataService.instance;
      var page = await chatData.refreshMessagesForContact(roomId);
      var cached = chatData.getMessages(roomId);
      final wanted = mids.toSet();
      for (var attempt = 0;
          wanted.any((mid) => !cached.any((message) => message.mid == mid)) &&
              page.hasMore &&
              attempt < 100;
          attempt++) {
        page = await chatData.loadOlderMessages(roomId);
        cached = chatData.getMessages(roomId);
      }
      final byMid = <int, ChatMessage>{};
      for (final message in cached) {
        final mid = message.mid;
        if (mid != null) byMid[mid] = message;
      }
      final isAdmin = await _checkAdmin(uid, password);
      if (!mounted) return;
      setState(() {
        _essenceMids = mids;
        _messages
          ..clear()
          ..addEntries(_essenceMids.map((mid) => MapEntry(mid, byMid[mid])));
        _isAdmin = isAdmin;
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<bool> _checkAdmin(int uid, String password) async {
    if (AuthState.instance.currentUser?.hasAdminAccess == true) return true;
    try {
      final members = await TfApiClient.instance.getGroupMembers(
        uid,
        password,
        widget.gid,
      );
      final memberList = members?['members'] as List<dynamic>? ?? const [];
      for (final raw in memberList) {
        if (raw is Map && (raw['uid'] as num?)?.toInt() == uid) {
          final role = raw['role']?.toString().toLowerCase();
          return role == 'owner' || role == 'admin';
        }
      }
    } catch (_) {
      // 网络异常时按无权限处理
    }
    return false;
  }

  Future<void> _removeEssence(int mid) async {
    final uid = _uid;
    final password = _password;
    final ok = await TfApiClient.instance.removeEssence(
      uid,
      password,
      widget.gid,
      mid,
    );
    if (!mounted) return;
    if (ok) {
      await _load(showLoading: false);
    } else {
      TouchFishSnackbarService.instance
          .show(AppLocalizations.of(context)!.commonFailedOperation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(AppLocalizations.of(context)!.retry),
                  ),
                )
          : _essenceMids.isEmpty
              ? _buildEmpty(context)
              : _buildList(context),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.auto_awesome,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.essenceLabel(0),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sortedMids.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 60,
        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      itemBuilder: (context, index) {
        final mid = _sortedMids[index];
        return _EssenceMessageTile(
          mid: mid,
          message: _messages[mid],
          canRemove: _isAdmin,
          onRemove: _isAdmin ? () => _removeEssence(mid) : null,
        );
      },
    );
  }
}

class _EssenceMessageTile extends StatelessWidget {
  final int mid;
  final ChatMessage? message;
  final bool canRemove;
  final VoidCallback? onRemove;

  const _EssenceMessageTile({
    required this.mid,
    this.message,
    this.canRemove = false,
    this.onRemove,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays > 365) {
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    } else if (now.difference(dt).inDays > 0) {
      return DateFormat('MM/dd HH:mm').format(dt);
    }
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final msg = message;

    String? senderName;
    String? senderAvatar;
    if (msg != null) {
      if (msg.senderName?.trim().isNotEmpty == true) {
        senderName = msg.senderName;
      } else if (msg.isMe) {
        senderName = AuthState.instance.currentUser?.username ?? 'You';
      } else if (msg.senderUid != null) {
        senderName =
            ChatDataService.instance.getUser('U${msg.senderUid}')?.username;
      }
      if (msg.isMe) {
        senderAvatar = AuthState.instance.currentUser?.avatar;
      } else if (msg.senderUid != null) {
        senderAvatar =
            ChatDataService.instance.getUser('U${msg.senderUid}')?.avatar;
      }
      senderAvatar ??= msg.senderAvatar;
    }

    final timestamp = msg != null ? _formatTime(msg.timestamp) : '';
    final content = msg?.text ?? '';
    final hasAttachment = msg?.media != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: senderAvatar != null
                ? resizedImageProvider(
                    NetworkImage(senderAvatar),
                    MediaQuery.of(context).devicePixelRatio,
                    width: 36,
                    height: 36,
                  )
                : null,
            child: senderAvatar == null
                ? Icon(
                    Symbols.person,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (senderName != null)
                      Flexible(
                        child: Text(
                          senderName,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (timestamp.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        timestamp,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (content.isNotEmpty)
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  )
                else if (hasAttachment)
                  Text(
                    msg!.media!.fileName ?? l10n.essenceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  )
                else if (msg?.isDeleted == true)
                  Text(
                    l10n.messageRecalled,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  )
                else
                  Text(
                    '$mid',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              icon: Icon(Symbols.auto_awesome, color: colorScheme.error),
              onPressed: onRemove,
              tooltip: l10n.essenceRemove,
            ),
        ],
      ),
    );
  }
}
