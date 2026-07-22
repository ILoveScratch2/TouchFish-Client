import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';
import '../widgets/app_alert_dialog.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';

class ForumMemberListSheet extends StatefulWidget {
  final String forumId;
  final ForumMember? currentIdentity;
  final List<ForumMember> members;
  final VoidCallback? onChanged;

  const ForumMemberListSheet({
    super.key,
    required this.forumId,
    required this.currentIdentity,
    required this.members,
    this.onChanged,
  });

  @override
  State<ForumMemberListSheet> createState() => _ForumMemberListSheetState();
}

class _ForumMemberListSheetState extends State<ForumMemberListSheet> {
  Map<String, UserProfile?> _profiles = {};
  late List<ForumMember> _members;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _members = List.of(widget.members);
    _loadProfiles();
  }

  Future<void> _fetchMembers() async {
    final uid = AuthState.instance.uid;
    final pwd = AuthState.instance.password;
    final fid = int.tryParse(widget.forumId);
    if (uid == null || pwd == null || fid == null) return;
    setState(() => _isLoading = true);
    final members = await TfApiClient.instance.getMembers(uid, pwd, fid);
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
      _loadProfiles();
      widget.onChanged?.call();
    }
  }

  Future<void> _loadProfiles() async {
    final profiles = <String, UserProfile?>{};
    final futures = _members.map((m) async {
      final uid = int.tryParse(m.accountUid);
      if (uid != null) {
        profiles[m.accountUid] = await TfApiClient.instance.getUserByUid(uid);
      }
    });
    await Future.wait(futures);
    if (mounted) setState(() => _profiles = profiles);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isModerator = (widget.currentIdentity?.role ?? 0) >= 50;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          _buildHeader(context, l10n, _members.length),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                ? Center(
                    child: Text(
                      l10n.adminPendingForumsEmpty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final account = _profiles[member.accountUid];
                      return _buildMemberTile(
                        context,
                        l10n,
                        member,
                        account,
                        isModerator,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 20, right: 16, bottom: 12),
      child: Row(
        children: [
          Text(
            l10n.forumMembersCount(count),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddMemberDialog(context, l10n),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMembers),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMemberDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final uidController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.forumInviteMember),
        content: TextField(
          controller: uidController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'UID',
            hintText: 'Enter user UID',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final targetUid = int.tryParse(uidController.text.trim());
              if (targetUid == null) return;
              final uid = AuthState.instance.uid;
              final pwd = AuthState.instance.password;
              final fid = int.tryParse(widget.forumId);
              if (uid == null || pwd == null || fid == null) return;
              final ok = await TfApiClient.instance.addMember(
                uid,
                pwd,
                fid,
                targetUid,
                0,
              );
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: Text(l10n.forumInviteMember),
          ),
        ],
      ),
    );
    uidController.dispose();
    if (result == true && mounted) {
      await _fetchMembers();
    }
  }

  Widget _buildMemberTile(
    BuildContext context,
    AppLocalizations l10n,
    ForumMember member,
    UserProfile? account,
    bool isModerator,
  ) {
    final displayName = account?.username ?? 'UID:${member.accountUid}';
    final canManage =
        isModerator && (widget.currentIdentity?.role ?? 0) > member.role;

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 12),
      leading: ProfilePictureWidget(
        avatarUrl: account?.avatar,
        radius: 20,
        fallbackText: displayName,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (member.joinedAt == null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.pending_actions, size: 20),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Text(_getRoleLabel(l10n, member.role)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: const Text(
              '·',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text('@$displayName')),
        ],
      ),
      trailing: canManage
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    _showRoleEditSheet(context, l10n, member, account);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    showTouchFishErrorDialog<void>(
                      context,
                      title: l10n.forumRemoveMember,
                      message: l10n.forumRemoveMemberHint,
                      icon: Icons.person_remove_alt_1_rounded,
                      selectableMessage: false,
                      actions: [
                        TouchFishDialogAction<void>(label: l10n.cancel),
                        TouchFishDialogAction<void>(
                          label: l10n.forumRemoveMember,
                          isPrimary: true,
                          isDestructive: true,
                        ),
                      ],
                    ).then((_) async {
                      final uid = AuthState.instance.uid;
                      final pwd = AuthState.instance.password;
                      final fid = int.tryParse(widget.forumId);
                      final targetUid = int.tryParse(member.accountUid);
                      if (uid == null ||
                          pwd == null ||
                          fid == null ||
                          targetUid == null)
                        return;
                      final ok = await TfApiClient.instance.removeMember(
                        uid,
                        pwd,
                        fid,
                        targetUid,
                      );
                      if (mounted && ok) {
                        _fetchMembers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.forumRemoveMember)),
                        );
                      }
                    });
                  },
                ),
              ],
            )
          : null,
    );
  }

  void _showRoleEditSheet(
    BuildContext context,
    AppLocalizations l10n,
    ForumMember member,
    UserProfile? account,
  ) async {
    final newRole = await showModalBottomSheet<int>(
      isScrollControlled: true,
      context: context,
      builder: (context) =>
          _ForumMemberRoleSheet(member: member, account: account),
    );
    if (newRole != null && mounted) {
      final uid = AuthState.instance.uid;
      final pwd = AuthState.instance.password;
      final fid = int.tryParse(widget.forumId);
      final targetUid = int.tryParse(member.accountUid);
      if (uid == null || pwd == null || fid == null || targetUid == null)
        return;
      final ok = await TfApiClient.instance.changeMemberRole(
        uid,
        pwd,
        fid,
        targetUid,
        newRole,
      );
      if (mounted && ok) {
        _fetchMembers();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.forumMemberRole)));
      }
    }
  }

  String _getRoleLabel(AppLocalizations l10n, int role) {
    if (role >= 100) return l10n.forumRoleOwner;
    if (role >= 50) return l10n.forumRoleAdmin;
    return l10n.forumRoleMember;
  }
}

class _ForumMemberRoleSheet extends StatefulWidget {
  final ForumMember member;
  final UserProfile? account;

  const _ForumMemberRoleSheet({required this.member, this.account});

  @override
  State<_ForumMemberRoleSheet> createState() => _ForumMemberRoleSheetState();
}

class _ForumMemberRoleSheetState extends State<_ForumMemberRoleSheet> {
  late TextEditingController _roleController;

  @override
  void initState() {
    super.initState();
    _roleController = TextEditingController(
      text: widget.member.role.toString(),
    );
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName =
        widget.account?.username ?? 'UID:${widget.member.accountUid}';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 16,
                left: 20,
                right: 16,
                bottom: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.forumMemberRoleEdit(displayName),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Autocomplete<int>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty)
                        return const [100, 50, 0];
                      final int? value = int.tryParse(textEditingValue.text);
                      if (value == null) return const [100, 50, 0];
                      return [100, 50, 0].where(
                        (option) =>
                            option.toString().contains(textEditingValue.text),
                      );
                    },
                    onSelected: (int selection) {
                      _roleController.text = selection.toString();
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.forumMemberRole,
                              helperText: l10n.forumMemberRoleHint,
                            ),
                            onTapOutside: (event) => focusNode.unfocus(),
                          );
                        },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      final role = int.tryParse(_roleController.text);
                      Navigator.pop(context, role);
                    },
                    icon: const Icon(Icons.save),
                    label: Text(l10n.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
