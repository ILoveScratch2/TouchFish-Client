import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../routes/app_routes.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int? _pendingForumCount;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshPendingForumCount();
  }

  Future<void> _refreshPendingForumCount({bool showError = false}) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;

    if (uid == null || password == null) {
      if (!mounted) return;
      setState(() {
        _pendingForumCount = null;
        _isRefreshing = false;
      });
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      final forums = await TfApiClient.instance.getApprovingForumList(
        uid,
        password,
      );
      if (!mounted) return;
      setState(() {
        _pendingForumCount = forums.length;
      });
    } catch (e) {
      talker.error('AdminScreen: getApprovingForumList failed', e);
      if (!mounted) return;
      setState(() {
        _pendingForumCount = null;
      });
      if (showError) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminPendingForumsLoadFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _openPendingForums() async {
    await context.push(AppRoutes.adminPendingForums);
    if (!mounted) return;
    await _refreshPendingForumCount();
  }

  Future<void> _openServerSettings() async {
    await context.push(AppRoutes.adminServerSettings);
    if (!mounted) return;
    await _refreshPendingForumCount();
  }

  Future<void> _openDefaultAssets() async {
    await context.push(AppRoutes.adminDefaultAssets);
    if (!mounted) return;
    await _refreshPendingForumCount();
  }

  Widget _buildAdminActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final titleRowChildren = <Widget?>[
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      trailing,
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: titleRowChildren.whereType<Widget>().toList()),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = AuthState.instance.currentUser;

    if (currentUser?.hasAdminAccess != true) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navAdmin)),
        body: Center(child: Text(l10n.adminAccessDenied)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navAdmin),
        actions: [
          IconButton(
            onPressed: _isRefreshing
                ? null
                : () => _refreshPendingForumCount(showError: true),
            tooltip: l10n.retry,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Text(
                  l10n.adminTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  l10n.adminDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                _buildAdminActionCard(
                  context,
                  icon: Icons.pending_actions_outlined,
                  title: l10n.adminPendingForums,
                  description: l10n.adminPendingForumsDescription,
                  onTap: _openPendingForums,
                  trailing: _pendingForumCount != null
                      ? _PendingForumCountBadge(count: _pendingForumCount!)
                      : null,
                ),
                _buildAdminActionCard(
                  context,
                  icon: Icons.image_outlined,
                  title: l10n.adminDefaultAssets,
                  description: l10n.adminDefaultAssetsDescription,
                  onTap: _openDefaultAssets,
                ),
                if (currentUser?.isRoot == true)
                  _buildAdminActionCard(
                    context,
                    icon: Icons.tune_rounded,
                    title: l10n.adminServerSettings,
                    description: l10n.adminServerSettingsDescription,
                    onTap: _openServerSettings,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingForumCountBadge extends StatelessWidget {
  final int count;

  const _PendingForumCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0
            ? colorScheme.error
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: count > 0 ? colorScheme.onError : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
