import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';
import '../widgets/app_alert_dialog.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  List<UserProfile> _users = const [];
  UserManagePagination? _pagination;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers({int page = 1}) async {
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
      final result = await TfApiClient.instance.manageListUsers(
        uid,
        password,
        page: page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _users = result?.users ?? [];
        _pagination = result?.pagination;
        _currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      talker.error('AccountManagementScreen: manageListUsers failed', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _changeUserStat(UserProfile user, String newStat) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final targetUid = int.tryParse(user.uid);
    if (targetUid == null) return;

    try {
      final success = await TfApiClient.instance.manageChangeAuth(
        uid,
        password,
        targetUid,
        newStat,
      );
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminAccountRoleChangeSuccess(user.username, _statDisplayName(l10n, newStat))),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadUsers(page: _currentPage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_roleChangeFailedMessage(l10n)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      talker.error('AccountManagementScreen: changeUserStat failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_roleChangeFailedMessage(l10n)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _banUser(UserProfile user) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final targetUid = int.tryParse(user.uid);
    if (targetUid == null) return;

    final isBanned = user.normalizedStat == 'banned';

    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: isBanned ? l10n.adminAccountUnbanTitle : l10n.adminAccountBanTitle,
      message: isBanned
          ? l10n.adminAccountUnbanConfirm(user.username)
          : l10n.adminAccountBanConfirm(user.username),
      icon: isBanned ? Icons.lock_open_outlined : Icons.block_outlined,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: isBanned ? l10n.adminAccountUnbanAction : l10n.adminAccountBanAction,
          result: true,
          isPrimary: true,
          isDestructive: !isBanned,
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

    try {
      final success = isBanned
          ? await TfApiClient.instance.manageChangeAuth(uid, password, targetUid, 'user')
          : await TfApiClient.instance.manageBanUser(uid, password, targetUid);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBanned
                  ? l10n.adminAccountUnbanSuccess(user.username)
                  : l10n.adminAccountBanSuccess(user.username),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadUsers(page: _currentPage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBanned ? l10n.adminAccountUnbanFailed : l10n.adminAccountBanFailed,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      talker.error('AccountManagementScreen: banUser failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isBanned ? l10n.adminAccountUnbanFailed : l10n.adminAccountBanFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteUser(UserProfile user) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final targetUid = int.tryParse(user.uid);
    if (targetUid == null) return;

    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.adminAccountDeleteTitle,
      message: l10n.adminAccountDeleteConfirm(user.username),
      icon: Icons.delete_forever_outlined,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.adminAccountDeleteAction,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

    try {
      final success = await TfApiClient.instance.manageDeleteUser(
        uid,
        password,
        targetUid,
      );
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminAccountDeleteSuccess(user.username)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadUsers(page: _currentPage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminAccountDeleteFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      talker.error('AccountManagementScreen: deleteUser failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminAccountDeleteFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRoleChangeDialog(UserProfile user) {
    final l10n = AppLocalizations.of(context)!;
    final currentStat = user.normalizedStat;
    const availableRoles = ['user', 'admin', 'root', 'banned'];

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.adminAccountChangeRoleTitle(user.username),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...availableRoles.map((role) => ListTile(
                  leading: Icon(
                    role == currentStat
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: role == currentStat
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(_statDisplayName(l10n, role)),
                  subtitle: role == currentStat
                      ? Text(l10n.adminAccountCurrentRole)
                      : null,
                  onTap: role == currentStat
                      ? null
                      : () {
                          Navigator.pop(context);
                          _changeUserStat(user, role);
                        },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _statDisplayName(AppLocalizations l10n, String stat) {
    switch (stat) {
      case 'root':
        return l10n.adminAccountRoleRoot;
      case 'admin':
        return l10n.adminAccountRoleAdmin;
      case 'banned':
        return l10n.adminAccountRoleBanned;
      default:
        return l10n.adminAccountRoleUser;
    }
  }

  String _roleChangeFailedMessage(AppLocalizations l10n) {
    return l10n.adminAccountRoleChangeFailed;
  }

  Color _statColor(String stat, ColorScheme cs) {
    switch (stat) {
      case 'root':
        return cs.error;
      case 'admin':
        return cs.primary;
      case 'banned':
        return cs.outline;
      default:
        return cs.secondary;
    }
  }

  String _formatCreateTime(String timestamp) {
    final ms = int.tryParse(timestamp);
    if (ms == null) return timestamp;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasAdminAccess =
        AuthState.instance.currentUser?.hasAdminAccess == true;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminAccountManagement)),
      body: !hasAdminAccess
          ? Center(child: Text(l10n.adminAccessDenied))
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.adminAccountLoadFailed),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _loadUsers(page: _currentPage),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadUsers(page: _currentPage),
                      child: _users.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.2,
                                ),
                                Icon(
                                  Icons.people_outline,
                                  size: 56,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    l10n.adminAccountEmpty,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _users.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final stat = user.normalizedStat;
                                return Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 720),
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          spacing: 8,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    user.username,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _statColor(
                                                      stat,
                                                      Theme.of(context).colorScheme,
                                                    ).withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    _statDisplayName(l10n, stat),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: _statColor(
                                                            stat,
                                                            Theme.of(context).colorScheme,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              'UID: ${user.uid}  ·  ${user.email.isNotEmpty ? user.email : l10n.userProfileUnknownEmail}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                            if (user.personalSign != null &&
                                                user.personalSign!.isNotEmpty)
                                              Text(
                                                user.personalSign!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            Text(
                                              l10n.adminAccountCreated(
                                                _formatCreateTime(user.createTime),
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline,
                                                  ),
                                            ),
                                            const Divider(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              spacing: 8,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showRoleChangeDialog(user),
                                                  icon: const Icon(Icons.manage_accounts_outlined,
                                                      size: 18),
                                                  label: Text(
                                                      l10n.adminAccountChangeRole),
                                                ),
                                                OutlinedButton.icon(
                                                  onPressed: () => _banUser(user),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                  ),
                                                  icon: Icon(
                                                    stat == 'banned'
                                                        ? Icons.lock_open_outlined
                                                        : Icons.block_outlined,
                                                    size: 18,
                                                  ),
                                                  label: Text(
                                                    stat == 'banned'
                                                        ? l10n.adminAccountUnbanAction
                                                        : l10n.adminAccountBanAction,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () => _deleteUser(user),
                                                  tooltip: l10n.adminAccountDeleteAction,
                                                  icon: Icon(
                                                    Icons.delete_outline,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error,
                                                  ),
                                                ),
                                              ],
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
      bottomNavigationBar: _pagination != null && _pagination!.totalPages > 1
          ? _buildPaginationBar(l10n)
          : null,
    );
  }

  Widget _buildPaginationBar(AppLocalizations l10n) {
    final p = _pagination!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed:
                  _currentPage > 1 ? () => _loadUsers(page: _currentPage - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${p.page} / ${p.totalPages}  (${p.total} ${l10n.adminAccountTotalUsers})',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            IconButton(
              onPressed: p.hasMore
                  ? () => _loadUsers(page: _currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}
