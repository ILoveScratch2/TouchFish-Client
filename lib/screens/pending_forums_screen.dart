import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/forum_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';
import '../widgets/app_alert_dialog.dart';

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

    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.adminApproveForumConfirmTitle,
      message: l10n.adminApproveForumConfirmMessage(forum.forumName),
      icon: Icons.verified_outlined,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.adminApproveForumAction,
          result: true,
          isPrimary: true,
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminApproveForumSuccess(forum.forumName)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadPendingForums();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminApproveForumFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      talker.error('PendingForumsScreen: approveForum failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminApproveForumFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.adminRejectForumConfirmTitle,
      message: l10n.adminRejectForumConfirmMessage(forum.forumName),
      icon: Icons.block_outlined,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.adminRejectForumAction,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminRejectForumSuccess(forum.forumName)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadPendingForums();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminRejectForumFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      talker.error('PendingForumsScreen: rejectForum failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminRejectForumFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminPendingForums)),
      body: !hasAdminAccess
          ? Center(child: Text(l10n.adminAccessDenied))
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.adminPendingForumsLoadFailed),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadPendingForums,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPendingForums,
              child: _forums.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2,
                        ),
                        Icon(
                          Icons.inbox_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            l10n.adminPendingForumsEmpty,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _forums.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final forum = _forums[index];
                        final processingAction =
                            _processingQueueIds[forum.queueId];
                        final isApproving =
                            processingAction == _PendingForumAction.approve;
                        final isRejecting =
                            processingAction == _PendingForumAction.reject;
                        final isProcessing = processingAction != null;
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 12,
                                  children: [
                                    Text(
                                      forum.forumName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    Text(
                                      l10n.adminPendingForumQueueId(
                                        forum.queueId,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                    Text(
                                      l10n.adminPendingForumCreator(
                                        forum.creatorUid,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
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
                                            onPressed: isProcessing
                                                ? null
                                                : () => _rejectForum(forum),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                            icon: isRejecting
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.block_outlined,
                                                  ),
                                            label: Text(
                                              l10n.adminRejectForumAction,
                                            ),
                                          ),
                                          FilledButton.icon(
                                            onPressed: isProcessing
                                                ? null
                                                : () => _approveForum(forum),
                                            icon: isApproving
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.verified_outlined,
                                                  ),
                                            label: Text(
                                              l10n.adminApproveForumAction,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
