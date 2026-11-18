import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/snackbar_service.dart';
import 'app_alert_dialog.dart';

class ForumActionMenu extends StatelessWidget {
  final Forum forum;
  final ForumMember? identity;
  final bool isMember;
  final VoidCallback onRefresh;
  final VoidCallback onEditForum;
  final VoidCallback onPinPost;

  const ForumActionMenu({
    super.key,
    required this.forum,
    required this.identity,
    required this.isMember,
    required this.onRefresh,
    required this.onEditForum,
    required this.onPinPost,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = (identity?.role ?? 0) >= 100;

    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
        if ((identity?.role ?? 0) >= 50) ...[
          PopupMenuItem(
            onTap: onEditForum,
            child: Row(
              children: [
                Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Text(l10n.forumEdit),
              ],
            ),
          ),
          PopupMenuItem(
            onTap: onPinPost,
            child: Row(
              children: [
                Icon(
                  Icons.push_pin,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(l10n.forumPinPost),
              ],
            ),
          ),
        ],
        if (isAdmin)
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(Icons.delete, color: Colors.red),
                const SizedBox(width: 12),
                Text(
                  l10n.forumDelete,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
            onTap: () => _handleDelete(context, l10n),
          )
        else if (isMember)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_remove,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.forumLeave,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
            onTap: () => _handleLeave(context, l10n),
          ),
      ],
    );
  }

  void _handleDelete(BuildContext context, AppLocalizations l10n) {
    showTouchFishErrorDialog<bool>(
      context,
      title: l10n.forumDelete,
      message: l10n.forumDeleteHint,
      icon: Icons.delete_outline_rounded,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.forumDelete,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    ).then((confirmed) async {
      if (confirmed == true && context.mounted) {
        final uid = AuthState.instance.uid;
        final password = AuthState.instance.password;
        final fid = int.tryParse(forum.id);
        if (uid == null || password == null || fid == null) return;
        final success = await TfApiClient.instance.removeForum(
          uid,
          password,
          fid,
        );
        if (!context.mounted) return;
        if (success) {
          context.pop();
          TouchFishSnackbarService.instance.show(l10n.forumDeleteSuccess);
          onRefresh();
        } else {
          TouchFishSnackbarService.instance.show(l10n.forumDeleteFailed);
        }
      }
    });
  }

  void _handleLeave(BuildContext context, AppLocalizations l10n) {
    showTouchFishErrorDialog<bool>(
      context,
      title: l10n.forumLeave,
      message: l10n.forumLeaveHint,
      icon: Icons.exit_to_app_rounded,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.forumLeave,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    ).then((confirmed) async {
      if (confirmed == true && context.mounted) {
        final uid = AuthState.instance.uid;
        final password = AuthState.instance.password;
        final fid = int.tryParse(forum.id);
        if (uid == null || password == null || fid == null) return;
        await TfApiClient.instance.leaveForumApi(uid, password, fid);
        onRefresh();
      }
    });
  }
}

