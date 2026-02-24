import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';

class ForumMemberListSheet extends StatelessWidget {
  final String forumId;
  final ForumMember? currentIdentity;

  const ForumMemberListSheet({
    super.key,
    required this.forumId,
    required this.currentIdentity,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final members = ForumDemoData.getDemoMembers(forumId);
    final isModerator = (currentIdentity?.role ?? 0) >= 50;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          _buildHeader(context, l10n, members.length),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final account = UserProfileDemoData.getDemoProfile(member.accountUid);
                return _buildMemberTile(context, l10n, member, account, isModerator);
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.forumInviteMember)),
              );
            },
            style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    AppLocalizations l10n,
    ForumMember member,
    UserProfile account,
    bool isModerator,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 12),
      leading: ProfilePictureWidget(
        avatarUrl: account.avatar,
        radius: 20,
        fallbackText: account.username,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              account.username,
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
            child: const Text('·', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text('@${account.username}')),
        ],
      ),
      trailing: isModerator
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
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.forumRemoveMember),
                        content: Text(l10n.forumRemoveMemberHint),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l10n.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l10n.forumRemoveMember),
                          ),
                        ],
                      ),
                    );
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
    UserProfile account,
  ) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => _ForumMemberRoleSheet(
        member: member,
        account: account,
      ),
    );
  }

  String _getRoleLabel(AppLocalizations l10n, int role) {
    if (role >= 100) return l10n.forumRoleOwner;
    if (role >= 50) return l10n.forumRoleAdmin;
    return l10n.forumRoleMember;
  }
}

class _ForumMemberRoleSheet extends StatefulWidget {
  final ForumMember member;
  final UserProfile account;

  const _ForumMemberRoleSheet({
    required this.member,
    required this.account,
  });

  @override
  State<_ForumMemberRoleSheet> createState() => _ForumMemberRoleSheetState();
}

class _ForumMemberRoleSheetState extends State<_ForumMemberRoleSheet> {
  late TextEditingController _roleController;

  @override
  void initState() {
    super.initState();
    _roleController = TextEditingController(text: widget.member.role.toString());
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
              padding: const EdgeInsets.only(top: 16, left: 20, right: 16, bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.forumMemberRoleEdit(widget.account.username),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
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
                      if (textEditingValue.text.isEmpty) {
                        return const [100, 50, 0];
                      }
                      final int? value = int.tryParse(textEditingValue.text);
                      if (value == null) return const [100, 50, 0];
                      return [100, 50, 0].where(
                        (option) => option.toString().contains(textEditingValue.text),
                      );
                    },
                    onSelected: (int selection) {
                      _roleController.text = selection.toString();
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
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
                      Navigator.pop(context, true);
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
