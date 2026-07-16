import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';

class GroupManagementScreen extends StatefulWidget {
  final int gid;
  final String groupName;

  const GroupManagementScreen({super.key, required this.gid, required this.groupName});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  Map<String, dynamic>? _settings;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _joinRequests = [];
  bool _isLoading = true;
  int? _currentUserRole;
  String? _groupAvatarUrl;

  int get _uid => AuthState.instance.uid ?? 0;
  String get _password => AuthState.instance.password ?? '';
  bool get _isOwner => _currentUserRole == 2;
  bool get _isAdmin => _currentUserRole != null && _currentUserRole! >= 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _groupAvatarUrl ??= '${await TfApiClient.instance.getBaseUrl()}/avatar/get_avatar/group/${widget.gid}';
      final members = await TfApiClient.instance.getGroupMembers(_uid, _password, widget.gid);
      if (members != null && mounted) {
        _settings = members['settings'] as Map<String, dynamic>?;
        _members = (members['members'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        _currentUserRole = _members
            .where((m) => m['uid'] == _uid)
            .map((m) => m['role'] == 'owner' ? 2 : (m['role'] == 'admin' ? 1 : 0))
            .firstOrNull;
      }
      if (_isAdmin) {
        final requests = await TfApiClient.instance.getJoinRequests(_uid, _password, widget.gid);
        if (mounted) _joinRequests = requests;
      }
    } catch (e) {
      talker.error('GroupManagement load failed', e);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleAdmin(int targetUid, bool currentlyAdmin) async {
    final ok = await TfApiClient.instance.setGroupAdmin(_uid, _password, widget.gid, targetUid, !currentlyAdmin);
    if (ok) _load();
  }

  Future<void> _removeMember(int targetUid) async {
    final ok = await TfApiClient.instance.removeGroupMember(_uid, _password, widget.gid, targetUid);
    if (ok) _load();
  }

  Future<void> _transferOwner(AppLocalizations l10n, int newOwner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.groupTransferOwner),
        content: Text(l10n.groupTransferOwnerConfirm),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => ctx.pop(true), child: Text(l10n.groupTransferOwnerConfirmAction)),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await TfApiClient.instance.transferGroupOwner(_uid, _password, widget.gid, newOwner);
      if (ok) _load();
    }
  }

  Future<void> _handleRequest(int rid, bool approved) async {
    final ok = await TfApiClient.instance.handleJoinRequest(_uid, _password, rid, approved);
    if (!ok) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showSnack(l10n.commonFailedOperation);
      }
      return;
    }
    _load();
  }

  Future<void> _toggleSetting(String key, bool value) async {
    await TfApiClient.instance.updateGroupSettings(_uid, _password, widget.gid, {key: value});
    _load();
  }

  Future<void> _inviteMember(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.groupInviteMember),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.groupInviteMemberHint,
            prefixIcon: const Icon(Icons.person_add),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.groupInviteMember),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    int? invitedUid = int.tryParse(result);
    if (invitedUid == null) {
      // Try username lookup
      final profile = await TfApiClient.instance.getUserByUsername(result);
      if (profile != null) {
        invitedUid = int.tryParse(profile.uid);
      }
    }
    if (invitedUid != null) {
      final ok = await TfApiClient.instance.inviteToGroup(_uid, _password, widget.gid, invitedUid);
      if (ok != null) {
        _showSnack(ok['pending'] == true ? l10n.groupInvitePendingReview : l10n.groupInviteJoined);
        _load();
      } else {
        _showSnack(l10n.groupInviteFailed);
      }
    } else {
      _showSnack(l10n.commonUserNotFound);
    }
  }

  Future<void> _uploadAvatar(AppLocalizations l10n) async {
    if (!_isOwner && !_isAdmin) {
      _showSnack(l10n.groupAvatarPermissionDenied);
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _showSnack(l10n.commonFileReadError);
        return;
      }
      final base64Str = base64.encode(bytes);
      final ok = await TfApiClient.instance.uploadGroupAvatar(
        _uid, _password, widget.gid, base64Str,
      );
      if (ok) {
        _showSnack(l10n.groupAvatarUpdateSuccess);
        _groupAvatarUrl = null; // bust cache to reload
        _load();
      } else {
        _showSnack(l10n.groupAvatarUploadFailedSize);
      }
    } catch (e) {
      talker.error('GroupManagement uploadAvatar failed', e);
      _showSnack('${l10n.commonFailedOperation}: $e');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Group avatar
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: _groupAvatarUrl != null ? NetworkImage(_groupAvatarUrl!) : null,
                        onBackgroundImageError: (_, __) {},
                        child: const Icon(Icons.group, size: 48, color: Colors.white54),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _uploadAvatar(l10n),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: cs.primary,
                            child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isOwner) ...[
                  _buildSection(l10n.groupSettingsSection),
                  ..._buildSettingsTiles(l10n),
                  const Divider(),
                ],
                Row(
                  children: [
                    Expanded(child: _buildSection('${l10n.groupMembersSection} (${_members.length})')),
                    FilledButton.tonalIcon(
                      onPressed: () => _inviteMember(l10n),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: Text(l10n.groupInviteMember),
                    ),
                  ],
                ),
                ..._members.map((m) => _buildMemberTile(l10n, cs, m)),
                if (_isAdmin && _joinRequests.isNotEmpty) ...[
                  const Divider(),
                  _buildSection('${l10n.groupJoinRequestsSection} (${_joinRequests.length})'),
                  ..._joinRequests.map((r) => _buildRequestTile(cs, r)),
                ],
              ],
            ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  List<Widget> _buildSettingsTiles(AppLocalizations l10n) {
    final settings = _settings ?? {};
    return [
      SwitchListTile.adaptive(
        value: settings['allow_direct_join'] == true,
        title: Text(l10n.groupAllowDirectJoin),
        subtitle: Text(l10n.groupAllowDirectJoinDesc),
        onChanged: (v) => _toggleSetting('allow_direct_join', v),
      ),
      SwitchListTile.adaptive(
        value: settings['require_review'] == true,
        title: Text(l10n.groupRequireReview),
        subtitle: Text(l10n.groupRequireReviewDesc),
        onChanged: (v) => _toggleSetting('require_review', v),
      ),
    ];
  }

  Widget _buildMemberTile(AppLocalizations l10n, ColorScheme cs, Map<String, dynamic> member) {
    final uid = member['uid'] as int;
    final role = member['role'] as String;
    final isMe = uid == _uid;
    final roleLabel = role == 'owner' ? l10n.roleOwner : (role == 'admin' ? l10n.roleAdmin : '');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Icon(role == 'owner' ? Icons.star : Icons.person, color: cs.onPrimaryContainer),
      ),
      title: Text('${member['username']}${isMe ? ' ${l10n.commonMe}' : ''}'),
      subtitle: roleLabel.isNotEmpty ? Text(roleLabel, style: TextStyle(color: cs.primary, fontSize: 12)) : null,
      trailing: _isOwner && !isMe
          ? PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'admin') _toggleAdmin(uid, role == 'admin');
                if (action == 'owner') _transferOwner(l10n, uid);
                if (action == 'remove') _removeMember(uid);
              },
              itemBuilder: (_) => [
                if (role == 'admin')
                  PopupMenuItem(value: 'admin', child: Text(l10n.groupRemoveAdmin))
                else
                  PopupMenuItem(value: 'admin', child: Text(l10n.groupSetAdmin)),
                PopupMenuItem(value: 'owner', child: Text(l10n.groupTransferOwner)),
                PopupMenuItem(value: 'remove', child: Text(l10n.groupRemoveMemberAction)),
              ],
            )
          : null,
    );
  }

  Widget _buildRequestTile(ColorScheme cs, Map<String, dynamic> req) {
    final l10n = AppLocalizations.of(context)!;
    final username = req['username'] as String? ?? '';
    final inviter = req['inviter_name'] as String?;
    final desc = inviter != null && inviter.isNotEmpty
        ? l10n.groupJoinInvitedBy(inviter)
        : l10n.groupJoinDirectRequest;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.secondaryContainer,
        child: Icon(Icons.person_add, color: cs.onSecondaryContainer),
      ),
      title: Text(username),
      subtitle: Text(desc),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.check, color: cs.primary),
            onPressed: () => _handleRequest(req['rid'] as int, true),
          ),
          IconButton(
            icon: Icon(Icons.close, color: cs.error),
            onPressed: () => _handleRequest(req['rid'] as int, false),
          ),
        ],
      ),
    );
  }
}
