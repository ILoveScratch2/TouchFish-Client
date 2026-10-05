import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/forum_pending_service.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';
import '../widgets/admin_ui.dart';

enum _PendingForumAction { approve, reject }

class PendingForumsScreen extends StatefulWidget {
  const PendingForumsScreen({super.key});

  @override
  State<PendingForumsScreen> createState() => _PendingForumsScreenState();
}

class _PendingForumsScreenState extends State<PendingForumsScreen> {
  List<PendingForumApproval> _forums = const [];
  final Map<int, _PendingForumAction> _processingQueueIds =
      <int, _PendingForumAction>{};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPendingForums();
  }

  Future<void> _loadPendingForums() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;

    if (uid == null || password == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'unauthorized';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final forums = await TfApiClient.instance.getApprovingForumList(
        uid,
        password,
      );
      if (!mounted) return;
      setState(() {
        _forums = forums;
        _isLoading = false;
      });
    } catch (e) {
      talker.error('PendingForumsScreen: getApprovingForumList failed', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _approveForum(PendingForumApproval forum) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final confirmed = await showAdminConfirmDialog(
      context,
      title: l10n.adminApproveForumConfirmTitle,
      message: l10n.adminApproveForumConfirmMessage(forum.forumName),
      confirmLabel: l10n.adminApproveForumAction,
      icon: Icons.verified_outlined,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _processingQueueIds[forum.queueId] = _PendingForumAction.approve;
    });
    try {
      final success = await TfApiClient.instance.approveForum(
        uid,
        password,
        forum.queueId,
      );
      if (!mounted) return;

      if (success) {
        TouchFishSnackbarService.instance
            .show(l10n.adminApproveForumSuccess(forum.forumName));
        await _loadPendingForums();
        ForumPendingService.instance.refresh();
      } else {
        TouchFishSnackbarService.instance.show(l10n.adminApproveForumFailed);
      }
    } catch (e) {
      talker.error('PendingForumsScreen: approveForum failed', e);
      if (!mounted) return;
      TouchFishSnackbarService.instance.show(l10n.adminApproveForumFailed);
    } finally {
      if (mounted) {
        setState(() => _processingQueueIds.remove(forum.queueId));
      }
    }
  }

  Future<void> _rejectForum(PendingForumApproval forum) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final confirmed = await showAdminConfirmDialog(
      context,
      title: l10n.adminRejectForumConfirmTitle,
      message: l10n.adminRejectForumConfirmMessage(forum.forumName),
      confirmLabel: l10n.adminRejectForumAction,
      icon: Icons.block_outlined,
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _processingQueueIds[forum.queueId] = _PendingForumAction.reject;
    });
    try {
      final success = await TfApiClient.instance.rejectForum(
        uid,
        password,
        forum.queueId,
      );
      if (!mounted) return;

      if (success) {
        TouchFishSnackbarService.instance
            .show(l10n.adminRejectForumSuccess(forum.forumName));
        await _loadPendingForums();
        ForumPendingService.instance.refresh();
      } else {
        TouchFishSnackbarService.instance.show(l10n.adminRejectForumFailed);
      }
    } catch (e) {
      talker.error('PendingForumsScreen: rejectForum failed', e);
      if (!mounted) return;
      TouchFishSnackbarService.instance.show(l10n.adminRejectForumFailed);
    } finally {
      if (mounted) {
        setState(() => _processingQueueIds.remove(forum.queueId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasAdminAccess =
        AuthState.instance.currentUser?.hasAdminAccess == true;

    return AdminPageScaffold(
      title: l10n.adminPendingForums,
      maxWidth: 720,
      body: !hasAdminAccess
          ? AdminEmptyState(
              message: l10n.adminAccessDenied,
              icon: Icons.lock_outline_rounded,
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPendingForums,
              child: _error != null
                  ? AdminErrorState(
                      message: l10n.adminPendingForumsLoadFailed,
                      onRetry: _loadPendingForums,
                    )
                  : _forums.isEmpty
                  ? AdminEmptyState(message: l10n.adminPendingForumsEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _forums.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildForumCard(context, l10n, _forums[index]),
                    ),
            ),
    );
  }

  Widget _buildForumCard(
    BuildContext context,
    AppLocalizations l10n,
    PendingForumApproval forum,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final processingAction = _processingQueueIds[forum.queueId];
    final isApproving = processingAction == _PendingForumAction.approve;
    final isRejecting = processingAction == _PendingForumAction.reject;
    final isProcessing = processingAction != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    forum.forumName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (forum.type == 'edit')
                  Chip(
                    label: Text(l10n.adminPendingForumEditBadge),
                    labelStyle: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onTertiaryContainer),
                    backgroundColor: colorScheme.tertiaryContainer,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            Text(
              l10n.adminPendingForumQueueId(forum.queueId),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            Text(
              l10n.adminPendingForumCreator(forum.creatorUid),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              forum.introduction.isEmpty
                  ? l10n.adminPendingForumNoIntroduction
                  : forum.introduction,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: isProcessing ? null : () => _rejectForum(forum),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    icon: _buttonIcon(Icons.block_outlined, isRejecting),
                    label: Text(l10n.adminRejectForumAction),
                  ),
                  FilledButton.icon(
                    onPressed: isProcessing ? null : () => _approveForum(forum),
                    icon: _buttonIcon(Icons.verified_outlined, isApproving),
                    label: Text(l10n.adminApproveForumAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buttonIcon(IconData icon, bool loading) {
    if (loading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(icon);
  }
}
