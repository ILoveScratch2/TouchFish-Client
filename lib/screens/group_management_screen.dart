import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  Future<void> _transferOwner(int newOwner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('转让群主'),
        content: const Text('转让后你将失去群主权限，确定继续吗？'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => ctx.pop(true), child: const Text('确认转让')),
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
    if (ok == null) {
      if (mounted) _showSnack('操作失败，请重试');
      return;
    }
    _load();
  }

  Future<void> _toggleSetting(String key, bool value) async {
    await TfApiClient.instance.updateGroupSettings(_uid, _password, widget.gid, {key: value});
    _load();
  }

  Future<void> _inviteMember() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邀请成员'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入好友的用户名或 UID',
            prefixIcon: Icon(Icons.person_add),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('邀请'),
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
        _showSnack(ok['pending'] == true ? '已发送邀请，等待审核' : '已邀请加入群组');
        _load();
      } else {
        _showSnack('邀请失败，请确认对方存在且已是你的好友');
      }
    } else {
      _showSnack('未找到该用户');
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                if (_isOwner) ...[
                  _buildSection('群组设置'),
                  ..._buildSettingsTiles(cs),
                  const Divider(),
                ],
                Row(
                  children: [
                    Expanded(child: _buildSection('成员 (${_members.length})')),
                    FilledButton.tonalIcon(
                      onPressed: _inviteMember,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('邀请'),
                    ),
                  ],
                ),
                ..._members.map((m) => _buildMemberTile(cs, m)),
                if (_isAdmin && _joinRequests.isNotEmpty) ...[
                  const Divider(),
                  _buildSection('入群申请 (${_joinRequests.length})'),
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

  List<Widget> _buildSettingsTiles(ColorScheme cs) {
    final settings = _settings ?? {};
    return [
      SwitchListTile.adaptive(
        value: settings['allow_direct_join'] == true,
        title: const Text('允许直接加入'),
        subtitle: const Text('非群成员可以自行申请加入群组'),
        onChanged: (v) => _toggleSetting('allow_direct_join', v),
      ),
      SwitchListTile.adaptive(
        value: settings['require_review'] == true,
        title: const Text('需要审核'),
        subtitle: const Text('邀请和加入申请均需群主审核'),
        onChanged: (v) => _toggleSetting('require_review', v),
      ),
    ];
  }

  Widget _buildMemberTile(ColorScheme cs, Map<String, dynamic> member) {
    final uid = member['uid'] as int;
    final role = member['role'] as String;
    final isMe = uid == _uid;
    final roleLabel = role == 'owner' ? '群主' : (role == 'admin' ? '管理员' : '');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Icon(role == 'owner' ? Icons.star : Icons.person, color: cs.onPrimaryContainer),
      ),
      title: Text('${member['username']}${isMe ? ' (我)' : ''}'),
      subtitle: roleLabel.isNotEmpty ? Text(roleLabel, style: TextStyle(color: cs.primary, fontSize: 12)) : null,
      trailing: _isOwner && !isMe
          ? PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'admin') _toggleAdmin(uid, role == 'admin');
                if (action == 'owner') _transferOwner(uid);
                if (action == 'remove') _removeMember(uid);
              },
              itemBuilder: (_) => [
                if (role == 'admin')
                  const PopupMenuItem(value: 'admin', child: Text('取消管理员'))
                else
                  const PopupMenuItem(value: 'admin', child: Text('设为管理员')),
                const PopupMenuItem(value: 'owner', child: Text('转让群主')),
                const PopupMenuItem(value: 'remove', child: Text('移出群组')),
              ],
            )
          : null,
    );
  }

  Widget _buildRequestTile(ColorScheme cs, Map<String, dynamic> req) {
    final username = req['username'] as String? ?? '';
    final inviter = req['inviter_name'] as String?;
    final desc = inviter != null && inviter.isNotEmpty ? '由 $inviter 邀请' : '直接申请加入';

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
