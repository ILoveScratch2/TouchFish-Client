import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/chat_data_service.dart';

/// 转发选择屏幕。
///
/// 默认展示所有好友和群聊；输入关键字后回车过滤（子串匹配，不调用 API）。
/// 点击某个目标后依次弹出"是否确认转发"、"转发后到达哪里"两个对话框，
/// 确认后通过 REST API 以 `forwarded` 参数发送原消息。
class ForwardScreen extends StatefulWidget {
  final ChatMessage message;

  const ForwardScreen({super.key, required this.message});

  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardTarget {
  final String roomId;
  final String name;
  final String? avatar;
  final bool isGroup;

  const _ForwardTarget({
    required this.roomId,
    required this.name,
    this.avatar,
    required this.isGroup,
  });
}

class _ForwardScreenState extends State<ForwardScreen> {
  final TextEditingController _controller = TextEditingController();
  String _keyword = '';
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ForwardTarget> get _allTargets {
    final data = ChatDataService.instance;
    final targets = <_ForwardTarget>[];

    // 好友（联系人）
    for (final contact in data.contacts) {
      targets.add(
        _ForwardTarget(
          roomId: contact.id,
          name: contact.name,
          avatar: contact.avatar,
          isGroup: false,
        ),
      );
    }

    // 群聊（rooms 中以 G 开头的）
    for (final room in data.rooms) {
      if (room.id.startsWith('G')) {
        targets.add(
          _ForwardTarget(
            roomId: room.id,
            name: room.name,
            avatar: room.avatar,
            isGroup: true,
          ),
        );
      }
    }

    // 去重（同一 id 只保留一个）
    final seen = <String>{};
    final unique = <_ForwardTarget>[];
    for (final target in targets) {
      if (seen.add(target.roomId)) unique.add(target);
    }
    return unique;
  }

  List<_ForwardTarget> get _filteredTargets {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) return _allTargets;
    return _allTargets
        .where(
          (target) =>
              target.name.toLowerCase().contains(keyword) ||
              target.roomId.toLowerCase().contains(keyword),
        )
        .toList();
  }

  void _onSubmitted(String _) {
    setState(() => _keyword = _controller.text);
  }

  Future<void> _onTargetTap(_ForwardTarget target) async {
    final l10n = AppLocalizations.of(context)!;
    if (_sending) return;

    // 第一个确认框：是否确认转发
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.forwardConfirmTitle),
        content: Text(l10n.forwardConfirmContent(target.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // 执行转发
    final success = await _performForward(target);
    if (!success || !mounted) return;

    // 若转发成功，再询问"转发后到达哪里"
    final goToTarget = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.forwardWhereTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.forwardStay),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.forwardGoToTarget),
          ),
        ],
      ),
    );
    if (goToTarget == null || !mounted) return;

    // 关闭本屏幕
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (goToTarget) {
      // 到达转发位置的聊天框
      context.push('/chat/${target.roomId}');
    }
    // 否则停留原位（不做任何跳转）
  }

  Future<bool> _performForward(_ForwardTarget target) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final mid = widget.message.mid;
    if (uid == null || password == null || mid == null) return false;

    setState(() => _sending = true);
    try {
      final content = switch (widget.message.type) {
        MessageType.file => widget.message.text,
        MessageType.image => '[IMAGE]',
        MessageType.video => '[VIDEO]',
        MessageType.audio => '[AUDIO]',
        MessageType.text => widget.message.text,
      };
      final contentType = widget.message.type == MessageType.file
          ? 'file'
          : widget.message.media != null
          ? 'file'
          : 'plain';

      final result = await TfApiClient.instance.sendMessage(
        uid,
        password,
        recipient: target.roomId,
        content: content,
        contentType: contentType,
        fileHash: widget.message.media?.fileHash,
        // forwarded: mid,
      );
      if (!mounted) return false;
      if (result != null) {
        // 乐观地在本地消息缓存中加入一条转发消息
        final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
        final userMessage = ChatMessage(
          id: clientMid,
          clientMid: clientMid,
          senderUid: uid,
          mid: (result['mid'] as num?)?.toInt(),
          text: content,
          timestamp: DateTime.now(),
          isMe: true,
          status: MessageStatus.sent,
          type: widget.message.type,
          media: widget.message.media,
          forwardedMid: mid,
          forwardPreview: QuotedMessagePreview(
            mid: mid,
            senderUid: widget.message.senderUid,
            senderName: widget.message.isMe
                ? AuthState.instance.currentUser?.username
                : widget.message.senderName,
            content: widget.message.text,
            contentType: widget.message.type == MessageType.file
                ? 'file'
                : 'plain',
            fileHash: widget.message.media?.fileHash,
            fileName: widget.message.media?.fileName,
          ),
        );
        ChatDataService.instance.addSentMessage(target.roomId, userMessage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.forwardSuccess),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return true;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.forwardFailed),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.forwardFailed),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final targets = _filteredTargets;
    final hasSearched = _keyword.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l10n.cancel,
        ),
        title: Text(l10n.forwardSearchTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSubmitted,
              onChanged: (_) {
                // 输入过程中立即实时过滤
                setState(() => _keyword = _controller.text);
              },
              decoration: InputDecoration(
                hintText: l10n.forwardSearchHint,
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _sending
                ? const Center(child: CircularProgressIndicator())
                : targets.isEmpty
                ? _buildEmptyState(context, l10n, colorScheme, hasSearched)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: targets.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 76),
                    itemBuilder: (context, index) {
                      final target = targets[index];
                      return _buildTargetTile(context, target);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    bool hasSearched,
  ) {
    if (!hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_alt, size: 96, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              l10n.forwardSearchHint,
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
    // 搜索无结果：大的放大镜
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 128, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            l10n.forwardSearchNotFound,
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

  Widget _buildTargetTile(BuildContext context, _ForwardTarget target) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage:
            target.avatar != null ? NetworkImage(target.avatar!) : null,
        onBackgroundImageError: (_, _) {},
        child: target.avatar == null
            ? Icon(
                target.isGroup ? Icons.group : Icons.person,
                color: colorScheme.onPrimaryContainer,
              )
            : null,
      ),
      title: Text(
        target.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        target.isGroup ? Icons.group : Icons.person,
        color: colorScheme.outlineVariant,
      ),
      onTap: () => unawaited(_onTargetTap(target)),
    );
  }
}