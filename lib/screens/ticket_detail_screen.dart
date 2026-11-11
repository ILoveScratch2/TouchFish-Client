import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';

import '../l10n/app_localizations.dart';
import '../models/file_attachment.dart';
import '../models/support_ticket.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/file_service.dart';
import '../services/image_compression_service.dart';
import '../services/snackbar_service.dart';
import '../services/ticket_inbox_service.dart';
import '../utils/talker.dart';
import '../utils/time_ago.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/forum_attachments.dart';
import '../widgets/support/ticket_labels.dart';

/// 工单详情
/// 复制了很多论坛帖子详情
const double _kTicketDetailMaxWidth = 680;

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  final SupportTicket initial;
  final bool adminMode;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.initial,
    this.adminMode = false,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  static const _pollInterval = Duration(seconds: 60);

  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<FileAttachment> _pending = [];

  late SupportTicket _ticket = widget.initial;
  Timer? _pollTimer;
  bool _working = false;
  bool _uploading = false;
  int _lastReplyCount = 0;

  /// 头像与用户名缓存
  final Map<int, String?> _avatarUrls = {};
  final Map<int, String?> _userNames = {};

  @override
  void initState() {
    super.initState();
    _lastReplyCount = widget.initial.messages.length;
    _refresh(silent: true);
    // 通知
    TicketInboxService.instance.addListener(_onInboxChanged);
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      // 正在打字或已有待发附件时跳过
      if (mounted &&
          !_working &&
          _pending.isEmpty &&
          _replyController.text.trim().isEmpty) {
        _refresh(silent: true);
      }
    });
  }

  void _onInboxChanged() {
    // 帧末刷新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _working) return;
      _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    TicketInboxService.instance.removeListener(_onInboxChanged);
    _pollTimer?.cancel();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final detail = await TfApiClient.instance.getTicketDetail(
      uid,
      password,
      widget.ticketId,
    );
    if (!mounted) return;
    if (detail == null) {
      if (!silent) {
        TouchFishSnackbarService.instance.show(
          AppLocalizations.of(context)!.ticketSubmitFailed,
        );
      }
      return;
    }
    final grew = detail.messages.length > _lastReplyCount;
    setState(() {
      _ticket = detail;
      _lastReplyCount = detail.messages.length;
    });
    _resolvePeople();
    if (grew) _scrollToLatest();
  }

  Future<void> _resolvePeople() async {
    final uids = <int>{
      _ticket.uid,
      ..._ticket.messages.map((m) => m.senderUid),
      if (_ticket.assigneeUid != null) _ticket.assigneeUid!,
    };
    final missing = uids.where((id) => _userNames[id] == null).toList();
    if (missing.isEmpty) return;
    for (final id in missing) {
      final profile = await TfApiClient.instance.getUserByUid(id);
      if (!mounted) return;
      if (profile == null) continue;
      setState(() {
        _avatarUrls[id] = profile.avatar;
        _userNames[id] = profile.username;
      });
    }
  }

  String _displayName(int uid, String? provided) {
    final fromServer = provided?.trim();
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    final cached = _userNames[uid]?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    final l10n = AppLocalizations.of(context)!;
    return l10n.ticketUnknownUser;
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showFailure(String? error) {
    final l10n = AppLocalizations.of(context)!;
    TouchFishSnackbarService.instance.show(
      restrictionNotice(l10n, error) ?? l10n.ticketSubmitFailed,
    );
  }

  Future<void> _pickAttachments() async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    try {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final maxSize = await TfApiClient.instance.getMaxFileSize();
        if (maxSize != null && bytes.length > maxSize) {
          if (mounted) {
            TouchFishSnackbarService.instance.show(
              l10n.storageFileTooLarge((maxSize / (1024 * 1024)).round()),
            );
          }
          continue;
        }
        final prepared = await ImageCompressionService.instance
            .prepareForUpload(bytes: bytes, fileName: file.name);
        final uploadBytes = prepared?.bytes ?? bytes;
        final uploadName = prepared?.fileName ?? file.name;
        final hash = await FileService.instance.uploadBytes(
          uid: uid,
          password: password,
          fileName: uploadName,
          bytes: uploadBytes,
        );
        if (hash == null || hash.isEmpty || !mounted) continue;
        setState(() {
          _pending.add(
            FileAttachment(
              hash: hash,
              fileName: uploadName,
              fileSize: uploadBytes.length,
              mimeType: lookupMimeType(uploadName),
            ),
          );
        });
      }
    } catch (error, stackTrace) {
      talker.error('Ticket attachment upload failed', error, stackTrace);
      if (mounted) {
        TouchFishSnackbarService.instance.show(l10n.ticketUploadFailed);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _sendReply() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final content = _replyController.text.trim();
    if (uid == null || password == null) return;
    if (content.isEmpty && _pending.isEmpty) return;

    setState(() => _working = true);
    final error = await TfApiClient.instance.sendTicketMessage(
      uid,
      password,
      widget.ticketId,
      content,
      attachments: _pending.map((item) => item.hash).toList(),
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (error != null) {
      _showFailure(error);
      return;
    }
    _replyController.clear();
    setState(_pending.clear);
    await _refresh(silent: true);
    _scrollToLatest();
  }

  Future<void> _changeStatus(TicketStatus status) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    setState(() => _working = true);
    final error = await TfApiClient.instance.handleTicket(
      uid,
      password,
      widget.ticketId,
      status: status.wire,
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (error != null) {
      _showFailure(error);
      return;
    }
    TouchFishSnackbarService.instance.show(
      AppLocalizations.of(context)!.ticketHandled,
    );
    await _refresh(silent: true);
  }

  Future<void> _updateMeta({
    TicketPriority? priority,
    int? assigneeUid,
    bool clearAssignee = false,
  }) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    setState(() => _working = true);
    final error = await TfApiClient.instance.updateTicketMeta(
      uid,
      password,
      widget.ticketId,
      priority: priority,
      assigneeUid: assigneeUid,
      clearAssignee: clearAssignee,
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (error != null) {
      _showFailure(error);
      return;
    }
    await _refresh(silent: true);
  }

  List<TicketStatus> _nextStatuses() {
    switch (_ticket.status) {
      case TicketStatus.open:
        return const [
          TicketStatus.processing,
          TicketStatus.resolved,
          TicketStatus.rejected,
        ];
      case TicketStatus.processing:
        return const [TicketStatus.resolved, TicketStatus.rejected];
      case TicketStatus.resolved:
      case TicketStatus.rejected:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nextStatuses = _nextStatuses();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: Text(
          _ticket.title.isEmpty ? l10n.ticketMyTickets : _ticket.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: l10n.ticketMyTickets,
            icon: const Icon(Icons.refresh),
            onPressed: _working ? null : () => _refresh(),
          ),
          if (widget.adminMode && nextStatuses.isNotEmpty)
            PopupMenuButton<TicketStatus>(
              enabled: !_working,
              tooltip: l10n.ticketChangeStatus,
              icon: const Icon(Icons.flag_outlined),
              itemBuilder: (_) => [
                for (final status in nextStatuses)
                  PopupMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Icon(
                          ticketStatusIcon(status),
                          size: 18,
                          color: ticketStatusColor(scheme, status),
                        ),
                        const SizedBox(width: 10),
                        Text(ticketStatusLabel(l10n, status)),
                      ],
                    ),
                  ),
              ],
              onSelected: _changeStatus,
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildBody(context, l10n)),
                if (widget.adminMode)
                  SliverToBoxAdapter(child: _buildAdminPanel(context, l10n)),
                SliverToBoxAdapter(child: _buildReplyHeader(context, l10n)),
                if (_ticket.messages.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyReplies(context, l10n))
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildReplyCard(context, index),
                      childCount: _ticket.messages.length,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(height: bottomPadding + 96),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding + 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _kTicketDetailMaxWidth,
                ),
                child: _buildReplyBar(context, l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final creatorName = _displayName(_ticket.uid, _ticket.creatorName);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kTicketDetailMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('/user/${_ticket.uid}'),
                child: Row(
                  children: [
                    ProfilePictureWidget(
                      avatarUrl: _avatarUrls[_ticket.uid],
                      radius: 20,
                      fallbackText: creatorName,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(creatorName, style: theme.textTheme.titleSmall),
                          Text(
                            _formatDateTime(_ticket.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatTimeAgo(
                        l10n,
                        _ticket.createdAt.millisecondsSinceEpoch ~/ 1000,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_ticket.title.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _ticket.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  TicketMetaChip(
                    label: ticketTypeLabel(l10n, _ticket.type),
                    color: ticketTypeColor(scheme, _ticket.type),
                    icon: ticketTypeIcon(_ticket.type),
                  ),
                  TicketMetaChip(
                    label: ticketStatusLabel(l10n, _ticket.status),
                    color: ticketStatusColor(scheme, _ticket.status),
                    icon: ticketStatusIcon(_ticket.status),
                  ),
                  TicketMetaChip(
                    label: ticketPriorityLabel(l10n, _ticket.priority),
                    color: ticketPriorityColor(scheme, _ticket.priority),
                    icon: Icons.flag,
                  ),
                  if (_ticket.targetId != null)
                    TicketMetaChip(
                      label: _targetLabel(l10n),
                      color: scheme.outline,
                      icon: Icons.link,
                    ),
                ],
              ),
              if (_ticket.content.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  _ticket.content,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
              if (!widget.adminMode && _ticket.assigneeUid != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.assignment_ind_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${l10n.ticketAssignee}：'
                      '${_displayName(_ticket.assigneeUid!, _ticket.assigneeName)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              if (_ticket.attachments.isNotEmpty)
                ForumAttachmentsRow(attachments: _ticket.attachments),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _targetLabel(AppLocalizations l10n) {
    final type = ticketTargetTypeLabel(l10n, _ticket.targetType);
    if (type == null) return l10n.ticketTarget;
    return '${l10n.ticketTarget}：$type';
  }

  /// 运营操作
  Widget _buildAdminPanel(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uid = AuthState.instance.uid;
    final assigneeLabel = _ticket.assigneeUid == null
        ? l10n.ticketUnassigned
        : _displayName(_ticket.assigneeUid!, _ticket.assigneeName);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kTicketDetailMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_ind_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.ticketAssignee}：$assigneeLabel',
                        style: theme.textTheme.labelMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _working || uid == null
                            ? null
                            : () => _updateMeta(assigneeUid: uid),
                        child: Text(l10n.ticketAssignToMe),
                      ),
                      if (_ticket.assigneeUid != null)
                        TextButton(
                          onPressed: _working
                              ? null
                              : () => _updateMeta(clearAssignee: true),
                          child: Text(l10n.ticketClearAssignee),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.ticketPriority,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      for (final priority in TicketPriority.values)
                        ChoiceChip(
                          label: Text(ticketPriorityLabel(l10n, priority)),
                          visualDensity: VisualDensity.compact,
                          selected: _ticket.priority == priority,
                          onSelected: _working
                              ? null
                              : (_) => _updateMeta(priority: priority),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.ticketChangeStatus,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      for (final status in _nextStatuses())
                        FilledButton.tonalIcon(
                          onPressed: _working
                              ? null
                              : () => _changeStatus(status),
                          icon: Icon(ticketStatusIcon(status), size: 16),
                          label: Text(ticketStatusLabel(l10n, status)),
                        ),
                      if (_nextStatuses().isEmpty)
                        Text(
                          ticketStatusLabel(l10n, _ticket.status),
                          style: theme.textTheme.labelMedium,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyHeader(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kTicketDetailMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Text(
                l10n.ticketReplies(_ticket.messages.length),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Divider()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyReplies(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.ticketThreadEmptyTitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// 回复卡片
  Widget _buildReplyCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final message = _ticket.messages[index];
    final displayName = _displayName(message.senderUid, message.senderName);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kTicketDetailMaxWidth),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.push('/user/${message.senderUid}'),
                  child: ProfilePictureWidget(
                    avatarUrl: _avatarUrls[message.senderUid],
                    radius: 16,
                    fallbackText: displayName,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 名字占满剩余宽度
                          // 时间最右
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (message.isStaff) ...[
                                  const SizedBox(width: 6),
                                  TicketMetaChip(
                                    label: l10n.ticketStaffReply,
                                    color: scheme.secondary,
                                    icon: Icons.support_agent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatTimeAgo(
                              l10n,
                              message.createdAt.millisecondsSinceEpoch ~/ 1000,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (message.content.trim().isNotEmpty)
                        SelectableText(
                          message.content,
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (message.attachments.isNotEmpty)
                        ForumAttachmentsRow(attachments: message.attachments),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 底部快捷回复
  Widget _buildReplyBar(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final currentUser = AuthState.instance.currentUser;
    final closed = _ticket.status.isClosed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < _pending.length; index++)
                  InputChip(
                    label: Text(
                      _pending[index].fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: _working
                        ? null
                        : () => setState(() => _pending.removeAt(index)),
                  ),
              ],
            ),
          ),
        Material(
          elevation: 2,
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ProfilePictureWidget(
                    avatarUrl: currentUser?.avatar,
                    radius: 16,
                    fallbackText: currentUser?.username ?? '?',
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: closed
                          ? l10n.ticketReopenHint
                          : l10n.ticketMessageHint,
                      border: InputBorder.none,
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _working || _uploading ? null : _pickAttachments,
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.ticketAddFile,
                ),
                IconButton(
                  onPressed: _working ? null : _sendReply,
                  icon: _working
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send, size: 20, color: scheme.primary),
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.ticketSend,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
