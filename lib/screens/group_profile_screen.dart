import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import '../models/settings_service.dart';
import '../widgets/markdown_renderer.dart';
import '../services/api/tf_api_client.dart';
import '../services/chat_data_service.dart';
import '../services/snackbar_service.dart';
import '../routes/app_routes.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';
import '../utils/clipboard_utils.dart';
import '../widgets/optimized_image.dart';
import '../widgets/text_entry_dialog.dart';

const double _kProfileMaxWidth = 680;

/// 群聊资料界面，仿照 UserProfileScreen。
///
/// - [gid]：群聊 id（例如 "123"）
/// - [initialData]：可选，来自 searchGroup 的结果，用于在非群成员时展示基础资料
/// - [initialGroupName]：可选，群聊名称兜底（例如从聊天列表带入）
class GroupProfileScreen extends StatefulWidget {
  final String gid;
  final Map<String, dynamic>? initialData;
  final String? initialGroupName;

  const GroupProfileScreen({
    super.key,
    required this.gid,
    this.initialData,
    this.initialGroupName,
  });

  @override
  State<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends State<GroupProfileScreen> {
  bool _isLoading = true;
  String? _error;

  String _groupName = '';
  String _creator = ''; // "@<groupcreater>" 的显示部分
  int? _creatorUid;
  String _introduction = '';
  String _enterHint = '';
  int? _memberCount;
  bool? _requireReview;
  bool _isMember = false;
  bool _isJoining = false;
  bool _joinPending = false;
  bool _allowDirectJoin = false;
  bool _publicMessages = false;
  List<TfGroupPreviewMember> _previewMembers = const [];
  List<ChatMessage>? _previewMessages;
  bool _previewMessagesLoading = false;
  int? _previewOldestMid;
  bool _previewHasMore = false;
  String? _groupAvatarUrl;
  String? _baseUrl;

  int get _gid => int.tryParse(widget.gid) ?? 0;

  @override
  void initState() {
    super.initState();
    ChatDataService.instance.addListener(_onChatDataChanged);
    _load();
  }

  @override
  void dispose() {
    ChatDataService.instance.removeListener(_onChatDataChanged);
    super.dispose();
  }

  void _onChatDataChanged() {
    if (mounted) setState(() {});
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final baseUrl = await TfApiClient.instance.getBaseUrl();
      _baseUrl = baseUrl;
      _groupAvatarUrl = '$baseUrl/avatar/get_avatar/group/$_gid';

      final uid = AuthState.instance.uid;
      final password = AuthState.instance.password;

      // 先以搜索结果为初值（若是从搜索进入）
      final data = widget.initialData;
      if (data != null) {
        _groupName =
            (data['groupname'] as String?) ?? widget.initialGroupName ?? '';
        _creatorUid = (data['creater'] as num?)?.toInt();
        _introduction = (data['introduction'] as String?) ?? '';
        _enterHint = (data['enter_hint'] as String?) ?? '';
        _requireReview = _asBool(data['require_review']);
        final members = data['members'];
        if (members is List) _memberCount = members.length;
        if (uid != null) {
          _isMember = members is List && members.any((m) => m == uid);
        }
      } else {
        _groupName = widget.initialGroupName ?? '';
      }

      if (_creatorUid != null) _creator = _creatorUid.toString();

      // 群组预览：任意登录用户可访问，作为基础资料与成员数来源
      if (uid != null && password != null) {
        try {
          final preview = await TfApiClient.instance.previewGroup(
            uid,
            password,
            _gid,
          );
          if (preview != null && mounted) {
            if (preview.groupname.isNotEmpty) _groupName = preview.groupname;
            if (preview.introduction.isNotEmpty) {
              _introduction = preview.introduction;
            }
            _memberCount = preview.memberCount;
            _isMember = preview.isMember;
            _allowDirectJoin = preview.allowDirectJoin;
            _publicMessages = preview.publicMessages;
            _requireReview = preview.requireReview;
            if (preview.enterHint.isNotEmpty) _enterHint = preview.enterHint;
            _previewMembers = preview.members;
            final owner = _previewMembers.firstWhere(
              (m) => m.role == 'owner',
              orElse: () => const TfGroupPreviewMember(
                uid: 0,
                username: '',
                role: '',
              ),
            );
            if (owner.uid != 0) _creatorUid = owner.uid;
            if (owner.username.isNotEmpty) _creator = owner.username;
          }
        } catch (e) {
          talker.debug('GroupProfile: previewGroup failed', e);
        }

        // 群成员额外拉取完整成员列表与设置
        if (_isMember) {
          try {
            final result = await TfApiClient.instance.getGroupMembers(
              uid,
              password,
              _gid,
            );
            if (result != null && mounted) {
              final settings = result['settings'] as Map<String, dynamic>?;
              final memberList =
                  (result['members'] as List<dynamic>?)
                          ?.cast<Map<String, dynamic>>() ??
                      const <Map<String, dynamic>>[];
              _memberCount = memberList.length;
              if (settings != null) {
                final hint = settings['enter_hint'] as String?;
                final intro = settings['introduction'] as String?;
                final review = _asBool(settings['require_review']);
                if (hint != null && hint.isNotEmpty) _enterHint = hint;
                if (intro != null && intro.isNotEmpty) _introduction = intro;
                if (review != null) _requireReview = review;
                _publicMessages = _asBool(settings['public_messages']) ?? _publicMessages;
              }
              final owner = memberList.firstWhere(
                (m) => m['role'] == 'owner',
                orElse: () => const <String, dynamic>{},
              );
              final ownerUid = (owner['uid'] as num?)?.toInt();
              final ownerName = owner['username'] as String?;
              if (ownerUid != null) _creatorUid = ownerUid;
              if (ownerName != null && ownerName.isNotEmpty) {
                _creator = ownerName;
              } else if (_creatorUid != null) {
                _creator = _creatorUid.toString();
              }
            }
          } catch (e) {
            talker.debug('GroupProfile: getGroupMembers failed', e);
          }
        } else if (_publicMessages) {
          unawaited(_loadPreviewMessages(uid, password));
        }
      }

      if (_creator.isEmpty && _creatorUid != null) {
        _creator = _creatorUid.toString();
      }
      if (_groupName.isEmpty) _groupName = 'Group $_gid';

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      talker.error('GroupProfileScreen: _load failed', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  static const int _kPreviewPageSize = 50;

  Future<void> _loadPreviewMessages(int uid, String password) async {
    setState(() => _previewMessagesLoading = true);
    try {
      final msgs = await TfApiClient.instance.queryMessageHistory(
        uid,
        password,
        0,
        groupId: _gid,
        limit: _kPreviewPageSize,
      );
      if (!mounted) return;
      _applyPreviewPage(msgs, replace: true);
    } catch (e) {
      talker.debug('GroupProfile: preview messages failed', e);
      if (mounted) setState(() => _previewMessages = const []);
    } finally {
      if (mounted) setState(() => _previewMessagesLoading = false);
    }
  }

  Future<void> _loadOlderPreviewMessages() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final beforeMid = _previewOldestMid;
    if (uid == null || password == null || beforeMid == null) return;
    setState(() => _previewMessagesLoading = true);
    try {
      final msgs = await TfApiClient.instance.queryMessageHistory(
        uid,
        password,
        0,
        groupId: _gid,
        beforeMid: beforeMid,
        limit: _kPreviewPageSize,
      );
      if (!mounted) return;
      _applyPreviewPage(msgs, replace: false);
    } catch (e) {
      talker.debug('GroupProfile: preview older messages failed', e);
    } finally {
      if (mounted) setState(() => _previewMessagesLoading = false);
    }
  }

  void _applyPreviewPage(List<ChatMessage> page, {required bool replace}) {
    final merged = replace
        ? List<ChatMessage>.from(page)
        : <ChatMessage>[...page, ...?_previewMessages];
    final mids = merged.map((m) => m.mid ?? 0).where((m) => m > 0);
    setState(() {
      _previewMessages = merged;
      _previewOldestMid = mids.isEmpty ? null : mids.reduce((a, b) => a < b ? a : b);
      _previewHasMore = page.length >= _kPreviewPageSize;
    });
    _prefetchPreviewSenders(merged.map((m) => m.senderUid));
  }

  /// 解析预览消息发送者昵称。
  ///
  /// 历史消息不携带昵称：优先取本地用户缓存，其次用预览成员列表兜底，
  /// 都缺失时回退到 UID。
  String _previewSenderName(int? uid) {
    if (uid == null || uid < 0) return '';
    final cached =
        ChatDataService.instance.getUser('U$uid')?.username.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    for (final m in _previewMembers) {
      if (m.uid == uid) {
        final name = m.username.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return 'U$uid';
  }

  /// 为缓存与预览成员都缺失的发送者补拉资料（完成后通知刷新）。
  void _prefetchPreviewSenders(Iterable<int?> uids) {
    final known = _previewMembers.map((m) => m.uid).toSet();
    for (final uid in uids.toSet()) {
      if (uid == null || uid < 0) continue;
      if (known.contains(uid)) continue;
      if (ChatDataService.instance.getUser('U$uid') != null) continue;
      ChatDataService.instance.ensureUserProfile(uid).catchError((e) {
        talker.debug('GroupProfile: ensureUserProfile failed uid=$uid', e);
      });
    }
  }

  Future<void> _joinGroup(AppLocalizations l10n) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      _showSnack(l10n.storageNotLoggedIn);
      return;
    }
    // 需要审核的群：可选填写申请留言（留空直接提交）
    String? requestMessage;
    if (_requireReview == true) {
      final input = await showDialog<String>(
        context: context,
        builder: (ctx) => TextEntryDialog(
          title: l10n.groupJoinMessageTitle,
          hintText: l10n.groupJoinMessageHint,
          cancelLabel: l10n.commonCancel,
          confirmLabel: l10n.confirm,
          icon: Icons.message_outlined,
          maxLines: 3,
          allowEmpty: true,
        ),
      );
      if (input == null) return; // 用户取消
      requestMessage = input.isEmpty ? null : input;
    }
    setState(() => _isJoining = true);
    try {
      final result = await TfApiClient.instance.joinGroup(
        uid,
        password,
        _gid,
        message: requestMessage,
      );
      if (!mounted) return;
      if (result == null) {
        _showSnack(l10n.groupProfileJoinFailed);
      } else if (result['pending'] == true) {
        setState(() => _joinPending = true);
        _showSnack(l10n.groupProfileJoinPending);
      } else {
        setState(() => _isMember = true);
        _showSnack(l10n.groupProfileJoinSuccess);
        unawaited(_load());
      }
    } catch (e) {
      talker.error('GroupProfile: joinGroup failed', e);
      _showSnack(l10n.groupProfileJoinFailed);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showSnack(String message) {
    if (mounted) {
      TouchFishSnackbarService.instance.show(message);
    }
  }

  Future<void> _copyText(String text, String successMessage) async {
    final copied = await copyTextToClipboard(text);
    if (!mounted) return;
    TouchFishSnackbarService.instance.show(
      copied ? successMessage : AppLocalizations.of(context)!.copyFailedText,
      type: copied ? SnackbarType.info : SnackbarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.groupProfileNotFound),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.chat);
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kProfileMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileHeader(context, l10n, colorScheme),
                      _buildActionButtons(context, l10n),
                      const SizedBox(height: 16),
                      if (_introduction.isNotEmpty) ...[
                        _buildIntroductionCard(context, l10n, colorScheme),
                        const SizedBox(height: 16),
                      ],
                      if (_enterHint.isNotEmpty) ...[
                        _buildEnterHintCard(context, l10n, colorScheme),
                        const SizedBox(height: 16),
                      ],
                      _buildDetailsCard(context, l10n, colorScheme),
                      if (!_isMember && _previewMembers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildMembersPreview(context, l10n, colorScheme),
                      ],
                      if (!_isMember && _publicMessages) ...[
                        const SizedBox(height: 16),
                        _buildMessagePreview(context, l10n, colorScheme),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildProfileHeader(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surface, width: 4),
          ),
          child: CircleAvatar(
            radius: 72,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: _groupAvatarUrl != null
                ? resizedImageProvider(
                    NetworkImage(_groupAvatarUrl!),
                    MediaQuery.of(context).devicePixelRatio,
                    width: 144,
                    height: 144,
                  )
                : null,
            onBackgroundImageError: (_, _) {},
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _groupName,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '@$_creator',
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildIntroductionCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final settingsService = SettingsService.instance;
    final enableMarkdown = settingsService.getValue<bool>(
      'enableMarkdownRendering',
      true,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.groupProfileIntroduction,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            enableMarkdown
                ? MarkdownRenderer(data: _introduction, selectable: true)
                : Text(
                    _introduction,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterHintCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.info_outline,
          color: colorScheme.primary,
        ),
        title: Text(
          l10n.groupProfileEnterHint,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(_enterHint),
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              context,
              Symbols.fingerprint,
              l10n.groupProfileGroupId,
              widget.gid,
              onTap: () {
                _copyText(widget.gid, l10n.groupProfileGroupIdCopied);
              },
            ),
            if (_memberCount != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                Symbols.group,
                l10n.groupMembersSection,
                _memberCount.toString(),
              ),
            ],
            if (_requireReview != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                Symbols.shield,
                _requireReview!
                    ? l10n.groupProfileRequireReview
                    : l10n.groupProfileRequireReviewNo,
                '',
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Symbols.content_copy,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
      ],
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }

  Widget _buildMembersPreview(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.groupMembersSection,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final member in _previewMembers)
                  _buildPreviewMemberChip(context, l10n, member, colorScheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewMemberChip(
    BuildContext context,
    AppLocalizations l10n,
    TfGroupPreviewMember member,
    ColorScheme colorScheme,
  ) {
    final muid = member.uid;
    final name = member.username.isNotEmpty ? member.username : 'U$muid';
    final role = member.role;
    final avatarUrl = _baseUrl != null
        ? '$_baseUrl/avatar/get_avatar/user/$muid'
        : null;
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          CircleAvatar(
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
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          if (role == 'owner' || role == 'admin')
            Text(
              role == 'owner' ? l10n.roleOwner : l10n.roleAdmin,
              style: TextStyle(fontSize: 10, color: colorScheme.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildMessagePreview(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final msgs = _previewMessages;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.visibility,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.groupProfilePreviewSection,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.groupProfilePreviewHint,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (msgs == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (msgs.isEmpty)
              Text(
                l10n.groupProfilePreviewEmpty,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else ...[
              if (_previewHasMore)
                Center(
                  child: TextButton(
                    onPressed: _previewMessagesLoading
                        ? null
                        : _loadOlderPreviewMessages,
                    child: Text(l10n.groupProfilePreviewLoadOlder),
                  ),
                ),
              for (final msg in msgs.reversed)
                _buildPreviewMessageRow(context, msg, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewMessageRow(
    BuildContext context,
    ChatMessage msg,
    ColorScheme colorScheme,
  ) {
    final sender = _previewSenderName(msg.senderUid);
    final String body;
    if (msg.isDeleted) {
      body = AppLocalizations.of(context)!.messageRecalled;
    } else if (msg.type == MessageType.text) {
      body = msg.text;
    } else {
      body = '[${msg.contentType}]';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sender.isNotEmpty)
            Text(
              sender,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          const SizedBox(height: 2),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    if (_isMember) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.go('/chat/G$_gid'),
              icon: const Icon(Symbols.send),
              label: Text(l10n.userProfileSendMessage),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    final String label;
    final Widget icon;
    final VoidCallback? onPressed;
    if (_joinPending) {
      label = l10n.groupProfileJoinPending;
      icon = const Icon(Symbols.hourglass);
      onPressed = null;
    } else if (!_allowDirectJoin) {
      label = l10n.groupProfileInviteOnly;
      icon = const Icon(Symbols.lock);
      onPressed = null;
    } else {
      label = l10n.groupProfileJoin;
      icon = _isJoining
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Symbols.group_add);
      onPressed = _isJoining ? null : () => _joinGroup(l10n);
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: Text(label),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

