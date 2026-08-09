import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/settings_service.dart';
import '../widgets/markdown_renderer.dart';
import '../services/api/tf_api_client.dart';
import '../routes/app_routes.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';

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
  String? _groupAvatarUrl;

  int get _gid => int.tryParse(widget.gid) ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
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

      // 群成员可拉取完整设置与成员列表
      if (uid != null && password != null) {
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
            _isMember = memberList.any(
              (m) => (m['uid'] as num?)?.toInt() == uid,
            );
            if (settings != null) {
              final hint = settings['enter_hint'] as String?;
              final intro = settings['introduction'] as String?;
              final review = _asBool(settings['require_review']);
              if (hint != null && hint.isNotEmpty) _enterHint = hint;
              if (intro != null && intro.isNotEmpty) _introduction = intro;
              if (review != null) _requireReview = review;
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
          talker.debug(
            'GroupProfile: getGroupMembers failed (not a member?)',
            e,
          );
        }

        // 非群成员时尝试拉取群设置（用于展示是否需管理员审核）
        if (!_isMember) {
          try {
            final settings = await TfApiClient.instance.getGroupSettings(
              uid,
              password,
              _gid,
            );
            if (settings != null && mounted) {
              final review = _asBool(settings['require_review']);
              final hint = settings['enter_hint'] as String?;
              final intro = settings['introduction'] as String?;
              if (review != null) _requireReview = review;
              if (hint != null && hint.isNotEmpty) _enterHint = hint;
              if (intro != null && intro.isNotEmpty) _introduction = intro;
            }
          } catch (e) {
            talker.debug('GroupProfile: getGroupSettings failed', e);
          }
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

  Future<void> _joinGroup(AppLocalizations l10n) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      _showSnack(l10n.storageNotLoggedIn);
      return;
    }
    setState(() => _isJoining = true);
    try {
      final result = await TfApiClient.instance.joinGroup(
        uid,
        password,
        _gid,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
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
                ? NetworkImage(_groupAvatarUrl!)
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
                Clipboard.setData(ClipboardData(text: widget.gid));
                _showSnack(l10n.groupProfileGroupIdCopied);
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

